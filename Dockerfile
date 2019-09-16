FROM python:2.7-buster

USER root

# Library versions
ARG WKHTMLTOX_VERSION
ENV WKHTMLTOX_VERSION ${WKHTMLTOX_VERSION:-0.12.5}

ARG WKHTMLTOPDF_CHECKSUM
ENV WKHTMLTOPDF_CHECKSUM ${WKHTMLTOPDF_CHECKSUM:-1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb}

ARG NODE_VERSION
ENV NODE_VERSION ${NODE_VERSION:-8}

# Odoo Configuration file defaults
ENV \
    DATA_DIR=${DATA_DIR:-/var/lib/odoo/data} \
    DB_PORT_5432_TCP_ADDR=${DB_PORT_5432_TCP_ADDR:-db} \
    DB_MAXCONN=${DB_MAXCONN:-64} \
    DB_ENV_POSTGRES_PASSWORD=${DB_ENV_POSTGRES_PASSWORD:-odoo} \
    DB_PORT_5432_TCP_PORT=${DB_PORT_5432_TCP_PORT:-5432} \
    DB_SSLMODE=${DB_SSLMODE:-prefer} \
    DB_TEMPLATE=${DB_TEMPLATE:-template1} \
    DB_ENV_POSTGRES_USER=${DB_ENV_POSTGRES_USER:-odoo} \
    DBFILTER=${DBFILTER:-.*} \
    HTTP_INTERFACE=${HTTP_INTERFACE:-0.0.0.0} \
    HTTP_PORT=${PORT:-8069} \
    LIMIT_MEMORY_HARD=${LIMIT_MEMORY_HARD:-2684354560} \
    LIMIT_MEMORY_SOFT=${LIMIT_MEMORY_SOFT:-2147483648} \
    LIMIT_TIME_CPU=${LIMIT_TIME_CPU:-600} \
    LIMIT_TIME_REAL=${LIMIT_TIME_REAL:-1200} \
    LIMIT_TIME_REAL_CRON=${LIMIT_TIME_REAL_CRON:-300} \
    LIST_DB=${LIST_DB:-True} \
    LOG_DB=${LOG_DB:-False} \
    LOG_DB_LEVEL=${LOG_DB_LEVEL:-warning} \
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

# Use noninteractive to get rid of apt-utils message
ENV DEBIAN_FRONTEND=noninteractive

# Fix locale  //-- for some tests that depend on locale (babel python-lib)
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Grab build deps
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    build-essential \
    nano \
    bzip2 \
    curl \
    fonts-noto-cjk \
    gnupg \
    libgeoip-dev \
    libmaxminddb-dev \
    node-less \
    python-renderpm \
    python-watchdog \
    wget \
    xz-utils \
    libevent-dev \
    libssl-dev \
    # lxml
    libxml2-dev \
    libxslt1-dev\
    # Pillow
    libjpeg-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libtiff5-dev \
    tk-dev \
    tcl-dev \
    # psutil
    linux-headers-amd64 \
    libldap2-dev \
    libsasl2-dev \
    # postgres
    libpq-dev \
    lsb-release \
    > /dev/null

# Grab run deps
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    locales \
    fontconfig \
    libfreetype6 \
    libjpeg62-turbo \
    liblcms2-2 \
    libldap-2.4-2 \
    libsasl2-2 \
    libtiff5 \
    libx11-6 \
    libxext6 \
    libxml2 \
    libxrender1 \
    libxslt1.1 \
    tcl \
    tk \
    zlib1g \
    zlibc \
    > /dev/null

# Grab latest pip
RUN curl --silent --show-error --location https://bootstrap.pypa.io/get-pip.py | python /dev/stdin --no-cache-dir

# Grab latest git            //-- to `pip install` customized python packages & apply patches
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends git-core > /dev/null

# Grab postgres
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN curl --silent --show-error --location https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends postgresql-client > /dev/null

# Grab pip dependencies
ENV ODOO_VERSION 10.0
RUN pip --quiet --quiet install --no-cache-dir --requirement https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt
RUN pip --quiet --quiet install --no-cache-dir phonenumbers wdb watchdog psycogreen

# Grab wkhtmltopdf
RUN curl --silent --show-error --location --output wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}-1.stretch_amd64.deb
RUN echo "${WKHTMLTOPDF_CHECKSUM} wkhtmltox.deb" | sha256sum -c -
RUN apt-get -qq update && apt-get -qq install -yqq --no-install-recommends libpng16-16 libssl1.1 xfonts-75dpi xfonts-base > /dev/null
RUN dpkg -i ./wkhtmltox.deb && rm wkhtmltox.deb && wkhtmltopdf --version

# Grab web stack
RUN set -x;\
    echo "deb http://deb.nodesource.com/node_${NODE_VERSION}.x $(lsb_release -cs) main" > /etc/apt/sources.list.d/nodesource.list \
    && export GNUPGHOME="$(mktemp -d)" \
    && repokey='9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --armor --export "${repokey}" | apt-key add - \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get -qq update \
    && apt-get -qq install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Grab latest json logger    //-- for easier parsing (Patch 0001)
RUN pip --quiet --quiet install python-json-logger

# Create app user
ENV ODOO_USER odoo
ENV ODOO_BASEPATH /opt/odoo

ARG APP_UID
ENV APP_UID ${APP_UID:-9001}

ARG APP_GID
ENV APP_GID ${APP_GID:-9001}

RUN addgroup --system --gid ${APP_UID} ${ODOO_USER}
RUN adduser --system --uid ${APP_GID} --ingroup ${ODOO_USER} --home ${ODOO_BASEPATH} --disabled-login --shell /sbin/nologin ${ODOO_USER}

# Grab latest geoip DB       //-- to enable IP based geo-referencing

RUN wget --quiet http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz -O /tmp/GeoLite2-City.tar.gz \
    && mkdir -p /usr/share/GeoIP \
    && chown -R ${ODOO_USER} /usr/share/GeoIP \
    && tar -xf /tmp/GeoLite2-City.tar.gz -C /tmp/ \
    && find /tmp/GeoLite2-City_* | grep "GeoLite2-City.mmdb" | xargs -I{} mv {} /usr/share/GeoIP/GeoLite2-City.mmdb \
    && pip install geoip2

# Grab newer werkzeug        //-- for right IP in logs https://git.io/fNu6v
RUN pip --quiet --quiet install --user Werkzeug==0.14.1

# Copy from build env
COPY ./resources/entrypoint.sh /
COPY ./resources/getaddons.py /

ENV ODOO_RC /etc/odoo/odoo.conf
COPY ./config/odoo.conf ${ODOO_RC}
RUN chown ${ODOO_USER} ${ODOO_RC}

# Own folders                //-- docker-compose creates named volumes owned by root:root. Issue: https://github.com/docker/compose/issues/3270
ENV ODOO_DATA_DIR /var/lib/odoo/data
ENV ODOO_LOGS_DIR /var/lib/odoo/logs

RUN mkdir -p "${ODOO_DATA_DIR}" "${ODOO_LOGS_DIR}"
RUN chown -R ${ODOO_USER}:${ODOO_USER} "${ODOO_DATA_DIR}" "${ODOO_LOGS_DIR}" /entrypoint.sh /getaddons.py
RUN chmod u+x /entrypoint.sh /getaddons.py

VOLUME ["${ODOO_DATA_DIR}", "${ODOO_LOGS_DIR}"]

ENV ODOO_ADDONS_BASEPATH ${ODOO_BASEPATH}/addons
ENV ODOO_CMD ${ODOO_BASEPATH}/odoo-bin

ENV ODOO_EXTRA_ADDONS /mnt/extra-addons

RUN git clone --depth=1 -b ${ODOO_VERSION} https://github.com/odoo/odoo.git ${ODOO_BASEPATH}
RUN pip install -e ./${ODOO_BASEPATH}

# Docker healthcheck command
HEALTHCHECK CMD curl --fail http://127.0.0.1:8069/web_editor/static/src/xml/ace.xml || exit 1

USER ${ODOO_USER}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
