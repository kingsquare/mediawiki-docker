FROM php:7.1.1-apache

# Waiting in anticipation for build-time arguments
# https://github.com/docker/docker/issues/14634
ENV MEDIAWIKI_VERSION 1.28
ENV MEDIAWIKI_VERSION_FULL 1.28.0

RUN set -x; \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        imagemagick \
        libpng-dev \
        libicu52 libicu-dev \
        netcat \
        git \
        wget zip unzip \
        locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure locales && locale-gen --purge en_US en_US.UTF-8 && update-locale LANG=en_US.UTF-8 \
    && export LC_ALL=en_US.UTF-8 \
    && docker-php-ext-install mysqli opcache gd intl mbstring \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    \
    && a2enmod rewrite \
    && a2enmod proxy \
    && a2enmod proxy_http \
    \
    && mkdir -p /var/www/html \
	\
	# https://www.mediawiki.org/keys/keys.txt \
	&& gpg --keyserver pool.sks-keyservers.net --recv-keys \
	    441276E9CCD15F44F6D97D18C119E1A64D70938E \
	    41B2ABE817ADD3E52BDA946F72BC1C5D23107F8A \
	    162432D9E81C1C618B301EECEE1F663462D84F01 \
	    1D98867E82982C8FE0ABC25F9B69B3109D3BB7B0 \
	    3CEF8262806D3F0B6BA1DBDD7956EE477F901A30 \
	    280DB7845A1DCAC92BB5A00A946B02565DC00AA7 \
    && export MEDIAWIKI_DOWNLOAD_URL="https://releases.wikimedia.org/mediawiki/$MEDIAWIKI_VERSION/mediawiki-$MEDIAWIKI_VERSION_FULL.tar.gz" \
    && set -x \
    && curl -fSL "$MEDIAWIKI_DOWNLOAD_URL" -o mediawiki.tar.gz \
    && curl -fSL "${MEDIAWIKI_DOWNLOAD_URL}.sig" -o mediawiki.tar.gz.sig \
    && gpg --verify mediawiki.tar.gz.sig \
    && tar -xf mediawiki.tar.gz -C /var/www/html --strip-components=1 \
     \
    # Install composer \
	&& EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig) \
	&& php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');") \
	&& if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then \
	    >&2 echo 'ERROR: Invalid installer signature'; \
	    rm composer-setup.php; \
	    exit 1; \
	fi \
	&& php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php \
    # Clean up \
    && export DEBIAN_FRONTEND="" \
    && apt-get remove -yq --purge libpng-dev libicu-dev g++ wget \
    && apt-get clean \
    && du -sh /var/www/html \
    && apt-get -qq clean \
	&& rm -rf /tmp/* /var/tmp/* /var/cache/apt/* /var/lib/apt/lists/* \
	&& apt-get -yq autoremove --purge

COPY php.ini /usr/local/etc/php/conf.d/mediawiki.ini

COPY apache/mediawiki.conf /etc/apache2/
RUN echo "Include /etc/apache2/mediawiki.conf" >> /etc/apache2/apache2.conf

COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]
