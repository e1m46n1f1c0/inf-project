# Imagen de Producción para Infinyti Framework
FROM infinyti/app:8.4-alpine

# Establecer directorio de trabajo
WORKDIR /var/www/html

# Copiar el código de la aplicación al contenedor (Inmutabilidad para Producción)
COPY ./src/website /var/www/html

# Si existe archivo .infinyti de setup se puede sincronizar
# COPY ./setup/.infinyti /var/www/html/.env
