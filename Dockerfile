FROM python:3.7-slim-buster as base

USER root

# Library versions
ARG WKHTMLTOX_VERSION
ENV WKHTMLTOX_VERSION ${WKHTMLTOX_VERSION:-"0.12.5"}

ARG WKHTMLTOPDF_CHECKSUM
ENV WKHTMLTOPDF_CHECKSUM ${WKHTMLTOPDF_CHECKSUM:-"1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb"}

# Use noninteractive to get rid of apt-utils message
ENV DEBIAN_FRONTEND=noninteractive

# Install odoo deps
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    ca-certificates \
    git-core \
    curl \
    chromium \
    ffmpeg \
    fonts-liberation2 \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl-dev \
    locales \
    lsb-release \
    node-less \
    npm \
    python3-renderpm \
    python3-watchdog \
    nano \
    vim \
    zlibc \
    xz-utils \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM} wkhtmltox.deb" | sha256sum -c - \
    && apt-get -qq update && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && echo "deb http://packages.cloud.google.com/apt gcsfuse-$(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/gcsfuse.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get -qq update && apt-get install -y gcsfuse \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb /tmp/*

# Fix locale  //-- for some tests that depend on locale (babel python-lib)
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install latest postgresql-client
RUN set -x; \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > etc/apt/sources.list.d/pgdg.list \
    && export GNUPGHOME="$(mktemp -d)" \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install -y postgresql-client \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN set -x; \
    npm install -g rtlcss

FROM base as builder

# Install hard & soft build dependencies
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    apt-utils dialog \
    apt-transport-https \
    build-essential \
    libfreetype6-dev \
    libfribidi-dev \
    libghc-zlib-dev \
    libharfbuzz-dev \
    libjpeg-dev \
    libgeoip-dev \
    libmaxminddb-dev \
    liblcms2-dev \
    libldap2-dev \
    libopenjp2-7-dev \
    libpq-dev \
    libsasl2-dev \
    libtiff5-dev \
    libwebp-dev \
    lsb-release \
    tcl-dev \
    tk-dev \
    zlib1g-dev \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Odoo source code and install it as a package inside the container with additional tools
ENV ODOO_VERSION ${ODOO_VERSION:-11.0}

RUN pip3 install --no-cache-dir --prefix=/usr/local https://nightly.odoo.com/${ODOO_VERSION}/nightly/src/odoo_${ODOO_VERSION}.latest.zip \
    && pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade --requirement https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
    && pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade \
    astor \
    psycogreen \
    python-magic \
    phonenumbers \
    num2words \
    qrcode \
    vobject \
    xlrd \
    python-stdnum \
    click-odoo-contrib \
    firebase-admin \
    git-aggregator \
    inotify \
    python-json-logger \
    wdb \
    websocket-client \
    Werkzeug==0.15.6 \
    && (python3 -m compileall -q /usr/local || true) \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* /tmp/*

FROM base

COPY --from=builder /usr/local /usr/local

# PIP auto-install requirements.txt (change value to "1" to auto-install)
ENV PIP_AUTO_INSTALL=${PIP_AUTO_INSTALL:-"0"}

# Run tests for all the modules in the custom addons
ENV RUN_TESTS=${RUN_TESTS:-"0"}

# Odoo Configuration file defaults
ENV \
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-my-weak-password} \
    ODOO_DATA_DIR=${ODOO_DATA_DIR:-/var/lib/odoo/data} \
    DB_PORT_5432_TCP_ADDR=${DB_PORT_5432_TCP_ADDR:-db} \
    DB_MAXCONN=${DB_MAXCONN:-64} \
    DB_ENV_POSTGRES_PASSWORD=${DB_ENV_POSTGRES_PASSWORD:-odoo} \
    DB_PORT_5432_TCP_PORT=${DB_PORT_5432_TCP_PORT:-5432} \
    DB_SSLMODE=${DB_SSLMODE:-prefer} \
    DB_TEMPLATE=${DB_TEMPLATE:-template1} \
    DB_ENV_POSTGRES_USER=${DB_ENV_POSTGRES_USER:-odoo} \
    DBFILTER=${DBFILTER:-.*} \
    HTTP_INTERFACE=${HTTP_INTERFACE:-0.0.0.0} \
    HTTP_PORT=${HTTP_PORT:-8069} \
    LIMIT_MEMORY_HARD=${LIMIT_MEMORY_HARD:-2684354560} \
    LIMIT_MEMORY_SOFT=${LIMIT_MEMORY_SOFT:-2147483648} \
    LIMIT_TIME_CPU=${LIMIT_TIME_CPU:-60} \
    LIMIT_TIME_REAL=${LIMIT_TIME_REAL:-120} \
    LIMIT_TIME_REAL_CRON=${LIMIT_TIME_REAL_CRON:-0} \
    LIST_DB=${LIST_DB:-True} \
    LOG_DB=${LOG_DB:-False} \
    LOG_DB_LEVEL=${LOG_DB_LEVEL:-warning} \
    LOGFILE=${LOGFILE:-None} \
    LOG_HANDLER=${LOG_HANDLER:-:INFO} \
    LOG_LEVEL=${LOG_LEVEL:-info} \
    MAX_CRON_THREADS=${MAX_CRON_THREADS:-2} \
    PROXY_MODE=${PROXY_MODE:-False} \
    SERVER_WIDE_MODULES=${SERVER_WIDE_MODULES:-base,web} \
    SMTP_PASSWORD=${SMTP_PASSWORD:-False} \
    SMTP_PORT=${SMTP_PORT:-25} \
    SMTP_SERVER=${SMTP_SERVER:-localhost} \
    SMTP_SSL=${SMTP_SSL:-False} \
    SMTP_USER=${SMTP_USER:-False} \
    TEST_ENABLE=${TEST_ENABLE:-False} \
    UNACCENT=${UNACCENT:-False} \
    WITHOUT_DEMO=${WITHOUT_DEMO:-False} \
    WORKERS=${WORKERS:-0}

# Create app user
ENV ODOO_USER odoo
ENV ODOO_BASEPATH ${ODOO_BASEPATH:-/opt/odoo}
ARG APP_UID
ENV APP_UID ${APP_UID:-1000}

ARG APP_GID
ENV APP_GID ${APP_UID:-1000}

RUN apt-get update \
    && ln -fs /usr/local/lib/python3.7/site-packages/odoo ${ODOO_BASEPATH} \
    && addgroup --system --gid ${APP_GID} ${ODOO_USER} \
    && adduser --system --uid ${APP_UID} --ingroup ${ODOO_USER} --home ${ODOO_BASEPATH} --disabled-login --shell /sbin/nologin ${ODOO_USER} \
    # [Optional] Add sudo support for the non-root user & unzip for CI
    && apt-get install -y sudo zip unzip \
    && echo ${ODOO_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${ODOO_USER}\
    && chmod 0440 /etc/sudoers.d/${ODOO_USER} \
    #
    # Clean up
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/*

# Copy from build env
COPY ./resources/entrypoint.sh /
COPY ./resources/getaddons.py /

# Define all needed directories
ENV ODOO_RC ${ODOO_RC:-/etc/odoo/odoo.conf}
ENV ODOO_DATA_DIR ${ODOO_DATA_DIR:-/var/lib/odoo/data}
ENV ODOO_LOGS_DIR ${ODOO_LOGS_DIR:-/var/lib/odoo/logs}
ENV ODOO_EXTRA_ADDONS ${ODOO_EXTRA_ADDONS:-/mnt/extra-addons}
ENV ODOO_ADDONS_BASEPATH ${ODOO_BASEPATH}/addons
ENV ODOO_CMD ${ODOO_BASEPATH}/odoo-bin

# This is needed to fully build with modules and python requirements
ENV HOST_CUSTOM_ADDONS ${HOST_CUSTOM_ADDONS:-/custom}

RUN mkdir -p ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} ${ODOO_EXTRA_ADDONS} /etc/odoo/

# Copy custom modules from the custom folder, if any.
COPY ${HOST_CUSTOM_ADDONS} ${ODOO_EXTRA_ADDONS}

# Own folders    //-- docker-compose creates named volumes owned by root:root. Issue: https://github.com/docker/compose/issues/3270
RUN chown -R ${ODOO_USER}:${ODOO_USER} ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} ${ODOO_BASEPATH} ${ODOO_EXTRA_ADDONS} /etc/odoo/ /entrypoint.sh /getaddons.py /usr/local/lib/python3.7/site-packages/odoo
RUN chmod u+x /entrypoint.sh /getaddons.py

VOLUME ["${ODOO_DATA_DIR}", "${ODOO_LOGS_DIR}", "${ODOO_EXTRA_ADDONS}"]

# Docker healthcheck command
HEALTHCHECK CMD curl --fail http://127.0.0.1:8069/web_editor/static/src/xml/ace.xml || exit 1

ARG EXTRA_ADDONS_PATHS
ENV EXTRA_ADDONS_PATHS ${EXTRA_ADDONS_PATHS}

ARG EXTRA_MODULES
ENV EXTRA_MODULES ${EXTRA_MODULES}

ENTRYPOINT ["/entrypoint.sh"]

ENV PGHOST ${DB_PORT_5432_TCP_ADDR}
ENV PGPORT ${DB_PORT_5432_TCP_PORT}
ENV PGUSER ${DB_ENV_POSTGRES_USER}
ENV PGPASSWORD ${DB_ENV_POSTGRES_PASSWORD}

RUN find ${ODOO_EXTRA_ADDONS} -name 'requirements.txt' -exec pip3 install --no-cache-dir -r {} \;

USER ${ODOO_USER}

CMD ["odoo"]
