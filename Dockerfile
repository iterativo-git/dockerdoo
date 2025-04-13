# syntax=docker/dockerfile:1
# check=skip=UndefinedVar # We set the variables as a reference

ARG PYTHON_VERSION=3.12
ARG PYTHON_VARIANT=slim-bookworm
ARG ODOO_VERSION=16.0
ARG WKHTMLTOX_VERSION=0.12.6-3
ARG ODOO_USER=odoo
ARG ODOO_BASEPATH=/opt/odoo
ARG APP_UID=1000
ARG APP_GID=1000

FROM python:${PYTHON_VERSION}-${PYTHON_VARIANT} AS base

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

USER root

# Library versions
ARG WKHTMLTOX_VERSION
ENV WKHTMLTOX_VERSION ${WKHTMLTOX_VERSION}

# Use noninteractive to get rid of apt-utils message
ENV DEBIAN_FRONTEND=noninteractive

# Install odoo deps
# hadolint ignore=DL3008
RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
    # Odoo dependencies
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl-dev \
    node-less \
    npm \
    python3-magic \
    python3-num2words \
    python3-odf \
    python3-pdfminer \
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
    # Other dependencies
    git-core \
    gnupg \
    htop \
    ffmpeg \
    fonts-liberation2 \
    lsb-release \
    nano \
    ssh \
    sudo \
    unzip \
    vim \
    zip \
    xz-utils \
    && \
    if [ "$(uname -m)" = "aarch64" ]; then \
        curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}.$(lsb_release -cs)_arm64.deb \
    ; else \
        curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}.$(lsb_release -cs)_amd64.deb \
    ; fi \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && apt-get autopurge -yqq \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb /tmp/*

# install latest postgresql-client
RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
    lsb-release \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get -qq install -y --no-install-recommends postgresql-client libpq-dev \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss \
    && rm -Rf ~/.npm /tmp/*

FROM base AS builder

# Install hard & soft build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
    libwebp-dev \
    tcl-dev \
    tk-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Odoo source code and install it as a package inside the container with additional tools
ARG ODOO_VERSION

RUN pip3 install --prefix=/usr/local --no-cache-dir --upgrade --requirement https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
    && pip3 -qq install --prefix=/usr/local --no-cache-dir --upgrade \
    'websocket-client~=0.56' \
    astor \
    black \
    pylint-odoo \
    flake8 \
    pydevd-odoo \
    psycogreen \
    click-odoo-contrib \
    git-aggregator \
    inotify \
    python-json-logger \
    wdb \
    redis \
    && apt-get autopurge -yqq \
    && rm -rf /var/lib/apt/lists/* /tmp/*

RUN git clone --depth 100 -b ${ODOO_VERSION} https://github.com/odoo/odoo.git /opt/odoo \
    && pip3 install --editable /opt/odoo \
    && rm -rf /var/lib/apt/lists/* /tmp/*

FROM base AS production

# PIP auto-install requirements.txt (change value to "1" to auto-install)
ENV PIP_AUTO_INSTALL=${PIP_AUTO_INSTALL:-"0"}

# Run tests for all the modules in the custom addons
ENV RUN_TESTS=${RUN_TESTS:-"0"}

# Run tests for all installed modules
ENV WITHOUT_TEST_TAGS=${WITHOUT_TEST_TAGS:-"0"}

# Upgrade all databases visible to this Odoo instance
ENV UPGRADE_ODOO=${UPGRADE_ODOO:-"0"}

ARG ODOO_BASEPATH
ENV ODOO_BASEPATH ${ODOO_BASEPATH}

# Create app user
ARG ODOO_USER
ENV ODOO_USER ${ODOO_USER}

ARG APP_UID
ENV APP_UID ${APP_UID}

ARG APP_GID
ENV APP_GID ${APP_GID}

RUN addgroup --system --gid ${APP_GID} ${ODOO_USER} \
    && adduser --system --uid ${APP_UID} --ingroup ${ODOO_USER} --home ${ODOO_BASEPATH} --disabled-login --shell /sbin/nologin ${ODOO_USER} \
    && echo ${ODOO_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${ODOO_USER}\
    && chmod 0440 /etc/sudoers.d/${ODOO_USER}

# Odoo Configuration file variables and defaults
ARG ADMIN_PASSWORD
ARG PGHOST
ARG PGUSER
ARG PGPORT
ARG PGPASSWORD
ARG DB_TEMPLATE
ARG HTTP_INTERFACE
ARG HTTP_PORT
ARG DBFILTER
ARG DBNAME
ARG SERVER_WIDE_MODULES

ENV \
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-my-weak-password} \
    ODOO_DATA_DIR=${ODOO_DATA_DIR:-/var/lib/odoo/data} \
    DB_PORT_5432_TCP_ADDR=${PGHOST:-db} \
    DB_MAXCONN=${DB_MAXCONN:-64} \
    DB_ENV_POSTGRES_PASSWORD=${PGPASSWORD:-odoo} \
    DB_PORT_5432_TCP_PORT=${PGPORT:-5432} \
    DB_SSLMODE=${DB_SSLMODE:-prefer} \
    DB_TEMPLATE=${DB_TEMPLATE:-template1} \
    DB_ENV_POSTGRES_USER=${PGUSER:-odoo} \
    DBFILTER=${DBFILTER:-.*} \
    DBNAME=${DBNAME} \
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

# camptocamp variables (to be used on cloud deployments)
# Sessions in Redis
ARG ODOO_SESSION_REDIS
ARG ODOO_SESSION_REDIS_HOST
ARG ODOO_SESSION_REDIS_PASSWORD
ARG ODOO_SESSION_REDIS_PREFIX
# JSON logging
ARG ODOO_LOGGING_JSON
# Attachments in the Object Storage S3
ARG AWS_HOST
ARG AWS_REGION
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_BUCKETNAME
# Metrics (Statsd/Prometheus for Grafana)
ARG ODOO_STATSD
ARG STATSD_CUSTOMER
ARG STATSD_ENVIRONMENT
ARG STATSD_HOST
ARG STATSD_PORT
# Automatic Configuration Startup checks
ARG ODOO_CLOUD_PLATFORM_UNSAFE
ARG RUNNING_ENV

ENV \
    ODOO_SESSION_REDIS=${ODOO_SESSION_REDIS:-0} \
    ODOO_SESSION_REDIS_HOST=${ODOO_SESSION_REDIS_HOST} \
    ODOO_SESSION_REDIS_PASSWORD=${ODOO_SESSION_REDIS_PASSWORD} \
    ODOO_SESSION_REDIS_PREFIX=${ODOO_SESSION_REDIS_PREFIX} \
    ODOO_LOGGING_JSON=${ODOO_LOGGING_JSON:-0} \
    AWS_HOST=${AWS_HOST} \
    AWS_REGION=${AWS_REGION} \
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    AWS_BUCKETNAME=${AWS_BUCKETNAME} \
    ODOO_STATSD=${ODOO_STATSD} \
    STATSD_CUSTOMER=${STATSD_CUSTOMER} \
    STATSD_ENVIRONMENT=${STATSD_ENVIRONMENT} \
    STATSD_HOST=${STATSD_HOST} \
    STATSD_PORT=${STATSD_PORT} \
    RUNNING_ENV=${RUNNING_ENV}

# Define all needed directories
ENV ODOO_RC ${ODOO_RC:-/etc/odoo/odoo.conf}
ENV ODOO_DATA_DIR ${ODOO_DATA_DIR:-/var/lib/odoo/data}
ENV ODOO_LOGS_DIR ${ODOO_LOGS_DIR:-/var/lib/odoo/logs}
ENV ODOO_EXTRA_ADDONS ${ODOO_EXTRA_ADDONS:-/mnt/extra-addons}
ENV ODOO_ADDONS_BASEPATH ${ODOO_BASEPATH}/addons
ENV ODOO_CMD ${ODOO_BASEPATH}/odoo-bin

RUN mkdir -p ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} ${ODOO_EXTRA_ADDONS} /etc/odoo/

# Own folders    //-- docker-compose creates named volumes owned by root:root. Issue: https://github.com/docker/compose/issues/3270
RUN chown -R ${APP_UID}:${APP_GID} ${ODOO_DATA_DIR} ${ODOO_LOGS_DIR} ${ODOO_EXTRA_ADDONS} ${ODOO_BASEPATH} /etc/odoo

VOLUME ["${ODOO_DATA_DIR}", "${ODOO_LOGS_DIR}", "${ODOO_EXTRA_ADDONS}"]

ARG EXTRA_ADDONS_PATHS
ENV EXTRA_ADDONS_PATHS ${EXTRA_ADDONS_PATHS}

ARG EXTRA_MODULES
ENV EXTRA_MODULES ${EXTRA_MODULES}

COPY --link --chown=${APP_UID}:${APP_GID} --from=builder /usr/local /usr/local
COPY --link --chown=${APP_UID}:${APP_GID} --from=builder /opt/odoo ${ODOO_BASEPATH}

# Copy from build env
COPY --link --chown=${APP_UID}:${APP_GID} ./resources/entrypoint.sh /
COPY --link --chown=${APP_UID}:${APP_GID} ./resources/getaddons.py /

# This is needed to fully build with modules and python requirements
# Copy custom modules from the custom folder, if any.
ARG HOST_CUSTOM_ADDONS
ENV HOST_CUSTOM_ADDONS ${HOST_CUSTOM_ADDONS:-./custom}
COPY --link --chown=${APP_UID}:${APP_GID} ${HOST_CUSTOM_ADDONS} ${ODOO_EXTRA_ADDONS}

RUN chmod u+x /entrypoint.sh

EXPOSE 8069 8071 8072

# Docker healthcheck command
HEALTHCHECK CMD curl --fail http://127.0.0.1:8069/web_editor/static/src/xml/ace.xml || exit 1

ENTRYPOINT ["/entrypoint.sh"]

USER ${ODOO_USER}

CMD ["/opt/odoo/odoo-bin"]
