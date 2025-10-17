FROM php:8.2-fpm

# Устанавливаем nginx и supervisor
RUN apt-get update && apt-get install -y nginx supervisor && rm -rf /var/lib/apt/lists/*

# Полностью очищаем стандартные nginx-конфиги
RUN rm -f /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* /usr/share/nginx/html/index.html || true

# Копируем свои конфиги
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Копируем сайт
COPY src/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80 9000

CMD ["supervisord", "-n"]
