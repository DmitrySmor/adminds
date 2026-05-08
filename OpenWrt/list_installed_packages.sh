#! /bin/bash

# Этот метод наиболее популярен в сообществе.
# Он основан на простой идее: все пакеты, которые были установлены после самой прошивки, с большой вероятностью добавлены вами.

FLASH_TIME=$(opkg info busybox | grep '^Installed-Time:'); for pkg in $(opkg list-installed | cut -d' ' -f1); do if [ "$(opkg info $pkg | grep '^Installed-Time: ')" != "$FLASH_TIME" ]; then echo $pkg; fi; done
