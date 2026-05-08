#!/bin/sh

# Настроки ОС OpenWrt
uci set network.lan.ipv6='0'                    # Отключаем IPv6 на LAN
uci set network.wan.ipv6='0'                    # Отключаем IPv6 на WAN
uci set network.lan.delegate='0'                # Отключаем делегирование префикса
uci set dhcp.lan.dhcpv6='disabled'              # Отключаем DHCPv6 сервер
uci -q delete dhcp.lan.dhcpv6                   # Удаляем секцию DHCPv6
uci -q delete dhcp.lan.ra                       # Удаляем RA (Router Advertisement)
uci -q delete network.globals.ula_prefix        # Удаляем ULA префикс
uci set dhcp.@dnsmasq[0].filter_aaaa='1'        # Блокируем AAAA-записи в DNS
uci commit                                      # Сохраняем изменения
service odhcpd disable                          # Отключаем службу odhcpd
service odhcpd stop                             # Останавливаем odhcpd
service network restart                         # Перезапускаем сеть
service dnsmasq restart                         # Перезапускаем DNS

# Дополнительно: sysctl (для ядра)
sysctl -w net.ipv6.conf.all.disable_ipv6=1      # Все интерфейсы (временно)
sysctl -w net.ipv6.conf.default.disable_ipv6=1  # Новые интерфейсы
sysctl -w net.ipv6.conf.lo.disable_ipv6=1       # Loopback
echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf  # Постоянно
