#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Watchdog для x11vnc в контейнере gemini-translator.

Проблема: x11vnc на dummy-X постепенно растёт по CPU (~0.1%/мин) и уходит
в busy-loop (100% CPU), после чего перестаёт принимать VNC-подключения.

Решение: каждые CHECK_INTERVAL сек проверяем CPU процесса x11vnc. Если он
долго держится выше HIGH_CPU_PCT — убиваем процесс (supervisor autorestart
немедленно поднимет его заново). Не трогает main.py и Xorg.

Запускается supervisor'ом как программа [program:vnc-watchdog].
"""
import os
import re
import time
import signal
import subprocess
import logging

CHECK_INTERVAL = 15      # сек
HIGH_CPU_PCT = 80        # порог CPU
LONG_ABOVE = 3           # сколько проверок подряд выше порога (45 сек)
LOG = "/var/log/supervisor/vnc-watchdog.log"

logging.basicConfig(
    filename=LOG, level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("vnc-watchdog")


def get_x11vnc():
    """Вернуть (pid, cpu_float) для процесса x11vnc, иначе (None, None)."""
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


def kill(pid):
    try:
        os.kill(int(pid), signal.SIGKILL)
        log.info(f"SIGKILL x11vnc pid={pid} (CPU busy-loop)")
        return True
    except ProcessLookupError:
        return True
    except Exception as e:
        log.error(f"не удалось убить x11vnc pid={pid}: {e}")
        return False


def main():
    log.info("vnc-watchdog запущен")
    high_count = 0
    while True:
        try:
            pid, cpu = get_x11vnc()
            if cpu is None:
                cpu = 0.0
            now = time.strftime("%H:%M:%S")
            if pid is None:
                # x11vnc нет — supervisor его сам поднимет; ничего не делаем
                log.info(f"{now} x11vnc не найден (pid=None), пропускаю")
                high_count = 0
            elif cpu >= HIGH_CPU_PCT:
                high_count += 1
                log.warning(
                    f"{now} x11vnc pid={pid} cpu={cpu:.0f}% "
                    f"(высокий {high_count}/{LONG_ABOVE})"
                )
                if high_count >= LONG_ABOVE:
                    kill(pid)
                    high_count = 0
            else:
                if high_count:
                    log.info(f"{now} cpu упал до {cpu:.0f}%, сброс счётчика")
                high_count = 0
        except Exception as e:
            log.exception("ошибка в цикле watchdog: %s", e)
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
