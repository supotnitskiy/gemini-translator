#!/bin/sh

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "ERROR: USERNAME and PASSWORD must be set in .env"
        exit 1
        fi

        apk add --no-cache apache2-utils

        # Пересоздаём файл htpasswd при каждом старте контейнера (bcrypt-хеш)
        htpasswd -cbB /etc/nginx/htpasswd "$USERNAME" "$PASSWORD"

        echo "htpasswd generated for user $USERNAME"
