#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Watchdog для x11vnc в контейнере gemini-translator.

Проблема: x11vnc на dummy-X накапливает CLOSE_WAIT-сокеты от оборвавших
соединение VNC-клиентов и уходит в busy-loop. Порт 10000 перестаёт
принимать новые подключения (VNC «мёртв»), хотя процесс ещё жив
и CPU растёт (иногда лишь до 30-50%).

Решение (надёжное): каждые CHECK_INTERVAL сек проверяем:
  1. Доступность VNC-порта 10000 (TCP-connect). Если порт мёртв 2 раза подряд
     — убиваем x11vnc (supervisor autorestart поднимет заново).
  2. CPU x11vnc > HIGH_CPU_PCT (запас 50%) — тоже перезапуск.

Не трогает main.py (переводчик) и Xorg.
Запускается supervisor'ом как [program:vnc-watchdog].
"""
import os
import time
import signal
import socket
import subprocess
import logging

CHECK_INTERVAL = 10       # сек
PORT = 10000              # VNC-порт
PORT_CHECK_HOST = "127.0.0.1"
PORT_DEAD_CONSEC = 2      # сколько проверок порт мёртв подряд перед kill
HIGH_CPU_PCT = 50         # порог CPU (с запасом, порт умирает раньше 80%)
HIGH_CPU_CONSEC = 3       # проверок подряд выше порога (30 сек)
LOG = "/var/log/supervisor/vnc-watchdog.log"

logging.basicConfig(
    filename=LOG, level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("vnc-watchdog")


def get_x11vnc():
    """Вернуть (pid, cpu_float) для x11vnc, иначе (None, None)."""
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "pid,pcpu,comm,args"],
            text=True, timeout=10,
        )
    except Exception:
        return None, None
    for line in out.splitlines():
        if "x11vnc" in line and "grep" not in line and "watchdog" not in line:
            parts = line.split()
            if len(parts) >= 2:
                pid = parts[0]
                try:
                    cpu = float(parts[1].replace(",", "."))
                except ValueError:
                    cpu = 0.0
                return pid, cpu
    return None, None


def port_open():
    """True, если VNC-порт принимает TCP-подключения."""
    try:
        sock = socket.create_connection((PORT_CHECK_HOST, PORT), timeout=2)
        sock.close()
        return True
    except OSError:
        return False


def kill(pid):
    try:
        os.kill(int(pid), signal.SIGKILL)
        log.info(f"SIGKILL x11vnc pid={pid}")
        return True
    except ProcessLookupError:
        return True
    except Exception as e:
        log.error(f"не удалось убить x11vnc pid={pid}: {e}")
        return False


def main():
    log.info("vnc-watchdog запущен (порт=%s, HIGH_CPU=%s%%)", PORT, HIGH_CPU_PCT)
    port_dead = 0
    cpu_high = 0
    while True:
        try:
            pid, cpu = get_x11vnc()
            if cpu is None:
                cpu = 0.0
            now = time.strftime("%H:%M:%S")

            if pid is None:
                log.info(f"{now} x11vnc не найден (supervisor поднимет)")
                port_dead = 0
                cpu_high = 0
            else:
                # Проверка порта (главный признак зависания)
                if not port_open():
                    port_dead += 1
                    log.warning(
                        f"{now} порт {PORT} не отвечает "
                        f"({port_dead}/{PORT_DEAD_CONSEC}), pid={pid} cpu={cpu:.0f}%"
                    )
                    if port_dead >= PORT_DEAD_CONSEC:
                        kill(pid)
                        port_dead = 0
                else:
                    if port_dead:
                        log.info(f"{now} порт снова отвечает, сброс счётчика")
                    port_dead = 0

                # Проверка CPU (запасной признак)
                if cpu >= HIGH_CPU_PCT:
                    cpu_high += 1
                    if cpu_high >= HIGH_CPU_CONSEC:
                        log.warning(
                            f"{now} CPU {cpu:.0f}% >= {HIGH_CPU_PCT}% "
                            f"({cpu_high} раза), перезапуск"
                        )
                        kill(pid)
                        cpu_high = 0
                else:
                    cpu_high = 0
        except Exception as e:
            log.exception("ошибка в цикле watchdog: %s", e)
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
