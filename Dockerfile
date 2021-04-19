FROM python:3.8-slim-buster as base

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

USER root

# Library versions
ARG WKHTMLTOX_VERSION
ENV WKHTMLTOX_VERSION ${WKHTMLTOX_VERSION:-"0.12.5"}

ARG WKHTMLTOPDF_CHECKSUM
ENV WKHTMLTOPDF_CHECKSUM ${WKHTMLTOPDF_CHECKSUM:-"1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb"}

# Use noninteractive to get rid of apt-utils message
ENV DEBIAN_FRONTEND=noninteractive

# Install odoo deps
RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
    curl \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM} wkhtmltox.deb" | sha256sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && apt-get -qq install -y --no-install-recommends \
    ca-certificates \
    chromium \
    git-core \
    gnupg \
    htop \
    ffmpeg \
    fonts-liberation2 \
    fonts-noto-cjk \
    locales \
    lsb-release \
    node-less \
    npm \
    python3-num2words \
    python3-pip \
    python3-phonenumbers \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-xlrd \
    python3-xlwt \
    nano \
    ssh \
    # Add sudo support for the non-root user & unzip for CI
    sudo \
    unzip \
    vim \
    zip \
    zlibc \
    xz-utils \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    # && rm -f /etc/apt/sources.list.d/pgdg.list \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* wkhtmltox.deb /tmp/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss \
    && rm -Rf ~/.npm /tmp/*

FROM base as builder

# Install hard & soft build dependencies
RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
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
    libssl-dev \
    libsasl2-dev \
    libtiff5-dev \
    libxml2-dev \
    libxslt1-dev \
    libpq-dev \
    libwebp-dev \
    lsb-release \
    tcl-dev \
    tk-dev \
    zlib1g-dev \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Install Odoo source code and install it as a package inside the container with additional tools
ENV ODOO_VERSION ${ODOO_VERSION:-14.0}

RUN pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade --requirement https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
    && pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade \
    'websocket-client~=0.56' \
    astor \
    black \
    pylint-odoo \
    flake8 \
    pydevd-odoo \
    psycogreen \
    python-magic \
    python-stdnum \
    pdfminer.six \
    click-odoo-contrib \
    git-aggregator \
    inotify \
    python-json-logger \
    wdb \
    redis \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

RUN git clone --depth 100 -b ${ODOO_VERSION} https://github.com/odoo/odoo.git /opt/odoo \
    && pip3 install --editable /opt/odoo \
    && pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade \
    gevent==20.12.1 \
    greenlet==0.4.17 \
    Werkzeug==0.15.6 \
    # debugpy has python2 libraries which can't be compiled with python3
    debugpy \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

FROM base as production

# PIP auto-install requirements.txt (change value to "1" to auto-install)
ENV PIP_AUTO_INSTALL=${PIP_AUTO_INSTALL:-"0"}

# Run tests for all the modules in the custom addons
ENV RUN_TESTS=${RUN_TESTS:-"0"}

# Upgrade all databases visible to this Odoo instance
ENV UPGRADE_ODOO=${UPGRADE_ODOO:-"0"}

    # Create app user
ENV ODOO_USER odoo
ENV ODOO_BASEPATH ${ODOO_BASEPATH:-/opt/odoo}
ARG APP_UID
ENV APP_UID ${APP_UID:-1000}

ARG APP_GID
ENV APP_GID ${APP_UID:-1000}

RUN addgroup --system --gid ${APP_GID} ${ODOO_USER} \
    && adduser --system --uid ${APP_UID} --ingroup ${ODOO_USER} --home ${ODOO_BASEPATH} --disabled-login --shell /sbin/nologin ${ODOO_USER} \
    && echo ${ODOO_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${ODOO_USER}\
    && chmod 0440 /etc/sudoers.d/${ODOO_USER}

ARG ADMIN_PASSWORD
ARG DB_PORT_5432_TCP_ADDR
ARG DB_ENV_POSTGRES_USER
ARG DB_PORT_5432_TCP_PORT
ARG DB_ENV_POSTGRES_PASSWORD
ARG DB_TEMPLATE
ARG HTTP_INTERFACE
ARG HTTP_PORT
ARG DBFILTER
ARG DBNAME

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
    DBNAME=${DBNAME:-False} \
    HTTP_INTERFACE=${HTTP_INTERFACE:-0.0.0.0} \
    HTTP_PORT=${HTTP_PORT:-8069} \
    LIMIT_REQUEST=${LIMIT_REQUEST:-8196} \
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

# Define all needed directories
ENV ODOO_RC ${ODOO_RC:-/etc/odoo/odoo.conf}
ENV ODOO_DATA_DIR ${ODOO_DATA_DIR:-/var/lib/odoo/data}
ENV ODOO_LOGS_DIR ${ODOO_LOGS_DIR:-/var/lib/odoo/logs}
ENV ODOO_EXTRA_ADDONS ${ODOO_EXTRA_ADDONS:-/mnt/extra-addons}
ENV ODOO_ADDONS_BASEPATH ${ODOO_BASEPATH}/addons
ENV ODOO_CMD ${ODOO_BASEPATH}/odoo-bin

RUN mkdir -p ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} ${ODOO_EXTRA_ADDONS} /etc/odoo/

VOLUME ["${ODOO_DATA_DIR}", "${ODOO_LOGS_DIR}", "${ODOO_EXTRA_ADDONS}"]

ARG EXTRA_ADDONS_PATHS
ENV EXTRA_ADDONS_PATHS ${EXTRA_ADDONS_PATHS}

ARG EXTRA_MODULES
ENV EXTRA_MODULES ${EXTRA_MODULES}

COPY --chown=${ODOO_USER}:${ODOO_USER} --from=builder /usr/local /usr/local
COPY --chown=${ODOO_USER}:${ODOO_USER} --from=builder /opt/odoo ${ODOO_BASEPATH}

# Copy from build env
COPY --chown=${ODOO_USER}:${ODOO_USER} ./resources/entrypoint.sh /
COPY --chown=${ODOO_USER}:${ODOO_USER} ./resources/getaddons.py /

# This is needed to fully build with modules and python requirements
# Copy custom modules from the custom folder, if any.
ARG HOST_CUSTOM_ADDONS
ENV HOST_CUSTOM_ADDONS ${HOST_CUSTOM_ADDONS:-./custom}
COPY --chown=${ODOO_USER}:${ODOO_USER} ${HOST_CUSTOM_ADDONS} ${ODOO_EXTRA_ADDONS}

# Own folders    //-- docker-compose creates named volumes owned by root:root. Issue: https://github.com/docker/compose/issues/3270
RUN chown -R ${ODOO_USER}:${ODOO_USER} ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} /etc/odoo
RUN chmod u+x /entrypoint.sh

EXPOSE 8069 8071 8072

# Docker healthcheck command
HEALTHCHECK CMD curl --fail http://127.0.0.1:8069/web_editor/static/src/xml/ace.xml || exit 1

ENTRYPOINT ["/entrypoint.sh"]

USER ${ODOO_USER}

CMD ["/opt/odoo/odoo-bin"]
