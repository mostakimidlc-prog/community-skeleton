FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and add PHP PPA first
RUN apt-get update && apt-get install -y \
    software-properties-common wget gnupg unzip sudo \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update && apt-get install -y \
    apache2 libapache2-mod-php8.1 php8.1 php8.1-cli php8.1-mysql \
    php8.1-mbstring php8.1-curl php8.1-xml php8.1-zip php8.1-gd \
    php8.1-intl php8.1-bcmath git mysql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache mods
RUN a2enmod rewrite headers

# Copy UVDesk app
COPY . /var/www/uvdesk
WORKDIR /var/www/uvdesk

# Set permissions
RUN chown -R www-data:www-data /var/www/uvdesk

# Expose port
EXPOSE 80

# Start Apache in foreground
CMD ["apache2ctl", "-D", "FOREGROUND"]
