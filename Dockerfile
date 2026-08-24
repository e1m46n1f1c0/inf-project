# Imagen de Producción para Infinyti Framework / Website
FROM php:8.3-apache

# Habilitar mod_rewrite de Apache para URLs amigables
RUN a2enmod rewrite

# Instalar dependencias y extensiones comunes de PHP si son requeridas
RUN apt-get update && apt-get install -y \
    libicu-dev \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install intl opcache \
    && rm -rf /var/lib/apt/lists/*

# Establecer directorio de trabajo
WORKDIR /var/www/html

# Copiar el código de la aplicación al contenedor (para Producción inmutable)
COPY ./src /var/www/html
