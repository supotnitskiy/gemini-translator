FROM python:3.12-slim-trixie

ARG APP_DIR=GeminiTranslator

ENV APP_DIR=${APP_DIR}
ENV DISPLAY=:1
# Предотвращает зависание apt-get на диалогах конфигурации
ENV DEBIAN_FRONTEND=noninteractive
# Настройки локали для корректной работы GUI и Qt
ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8

# ===== system deps =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    portaudio19-dev \
    git \
    procps \
    x11vnc \
    supervisor \
    xserver-xorg-core \
    xserver-xorg-video-dummy \
    x11-utils \
    fluxbox \
    dbus-x11 \
    wget \
    fonts-dejavu-core \
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-color-emoji \
    locales \
    libgl1 \
    libglib2.0-0t64 \
    libxkbcommon-x11-0 \
    libxcb-cursor0 \
    libxcb-xinerama0 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxcb-image0 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xkb1 \
    libegl1 \
    mesa-utils \
    && rm -rf /var/lib/apt/lists/* \
    && echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen ru_RU.UTF-8

# ===== Dirs & Entrypoint =====
# Добавлено создание /etc/X11/xorg.conf.d, так как в slim-образе этой папки нет, 
# и COPY 10-dummy.conf может упасть с ошибкой.
RUN mkdir -p /var/run/supervisor /var/log/supervisor /etc/X11/xorg.conf.d

COPY entrypoint.sh /app/${APP_DIR}/entrypoint.sh
RUN chmod +x /app/${APP_DIR}/entrypoint.sh

# ===== app =====
COPY ${APP_DIR}/ /app/${APP_DIR}/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY 10-dummy.conf /etc/X11/xorg.conf.d/
COPY vnc_watchdog.py /app/${APP_DIR}/vnc_watchdog.py
COPY ${APP_DIR}/requirements.txt /tmp/requirements.txt

# Обновляем pip, чтобы избежать предупреждений и проблем с новыми форматами wheel
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /app/${APP_DIR}

# Оставляем ваш ENTRYPOINT (если вы не меняете APP_DIR при сборке, всё будет работать)
ENTRYPOINT ["/app/GeminiTranslator/entrypoint.sh"]
