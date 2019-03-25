FROM debian:stretch

USER root

# Build-time arguments
ARG ODOO_USER
ARG ODOO_BASEPATH
ARG ODOO_CONF
ARG ODOO_CMD
ARG APP_UID
ARG APP_GID

# Library versions
ARG ODOO_VERSION
ARG PSQL_VERSION
ARG WKHTMLTOX_VERSION
ARG WKHTMLTOPDF_CHECKSUM
ARG NODE_VERSION
ARG BOOTSTRAP_VERSION

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
    python3-dev \
    python3-renderpm \
    python3-watchdog \
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
    # python-ldap
    libldap2-dev \
    libsasl2-dev \
    > /dev/null

# Grab run deps
RUN set -x; \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    python3 \
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
RUN curl --silent --show-error --location https://bootstrap.pypa.io/get-pip.py | python3 /dev/stdin --no-cache-dir

# Grab latest git            //-- to `pip install` customized python packages & apply patches
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends git-core > /dev/null

# Grab postgres
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' >> /etc/apt/sources.list.d/postgresql.list
RUN curl --silent --show-error --location https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends postgresql-client-${PSQL_VERSION} > /dev/null

# Grab pip dependencies
RUN pip --quiet --quiet install --no-cache-dir --requirement https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt
RUN pip --quiet --quiet install --no-cache-dir phonenumbers wdb watchdog ptvsd

# Grab wkhtmltopdf
RUN curl --silent --show-error --location --output wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}-1.stretch_amd64.deb
# Temporarily disable checksum, as variable expansion is not working 
# RUN echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c -
RUN apt-get -qq update && apt-get -qq install -yqq --no-install-recommends libpng16-16 libssl1.1 xfonts-75dpi xfonts-base > /dev/null
RUN dpkg -i ./wkhtmltox.deb && rm wkhtmltox.deb && wkhtmltopdf --version

# Grab web stack
RUN echo "deb https://deb.nodesource.com/node_${NODE_VERSION}.x stretch main" > /etc/apt/sources.list.d/nodesource.list
RUN echo "deb-src https://deb.nodesource.com/node_${NODE_VERSION}.x stretch main" >> /etc/apt/sources.list.d/nodesource.list
RUN curl --silent --show-error --location https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    gem \
    nodejs \
    ruby-compass \
    > /dev/null \
    && ln -s /usr/bin/nodejs /usr/local/bin/node \
    && npm install --quiet --global less \
    && gem install --no-rdoc --no-ri --no-update-sources bootstrap-sass --version "${BOOTSTRAP_VERSION}" \
    && rm -Rf ~/.gem /var/lib/gems/*/cache/ \
    && rm -Rf ~/.npm /tmp/*

# Grab latest json logger    //-- for easier parsing (Patch 0001)
RUN pip --quiet --quiet install python-json-logger

# Create app user
ENV APP_GID ${APP_GID}
ENV APP_UID ${APP_UID}
RUN addgroup --system --gid ${APP_UID} ${ODOO_USER}
RUN adduser --system --uid ${APP_GID} --ingroup ${ODOO_USER} --home ${ODOO_BASEPATH} --disabled-login --shell /sbin/nologin ${ODOO_USER}

# Grab latest geoip DB       //-- to enable IP based geo-referencing

RUN wget --quiet http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz -O /tmp/GeoLite2-City.tar.gz \
    && mkdir -p /usr/share/GeoIP \
    && chown -R ${ODOO_USER} /usr/share/GeoIP \
    && tar -xf /tmp/GeoLite2-City.tar.gz -C /tmp/ \
    && find /tmp/GeoLite2-City_* | grep "GeoLite2-City.mmdb" | xargs -I{} mv {} /usr/share/GeoIP/GeoLite2-City.mmdb \
    && pip install geoip2

# Copy from build env
COPY ./entrypoint.sh /
COPY ./config/odoo.conf ${ODOO_CONF}
RUN chown ${ODOO_USER} ${ODOO_CONF}

ENTRYPOINT ["/entrypoint.sh"]

USER odoo

# Grab newer werkzeug        //-- for right IP in logs https://git.io/fNu6v
RUN pip --quiet --quiet install --user Werkzeug==0.14.1
