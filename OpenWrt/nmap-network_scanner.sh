#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Функция для отрисовки таблицы
draw_table() {
    local data=("$@")
    local count=${#data[@]}

    if [ $count -eq 0 ]; then
        return
    fi

    # Определяем ширину столбцов
    local col1_width=20
    local col2_width=20
    local col3_width=30

    for entry in "${data[@]}"; do
        IFS='|' read -r ip mac host <<< "$entry"
        [ ${#ip} -gt $col1_width ] && col1_width=${#ip}
        [ ${#mac} -gt $col2_width ] && col2_width=${#mac}
        [ ${#host} -gt $col3_width ] && col3_width=${#host}
    done

    # Верхняя граница
    printf "┌%s┬%s┬%s┐\n" \
        "$(printf '─%.0s' $(seq 1 $((col1_width+2))))" \
        "$(printf '─%.0s' $(seq 1 $((col2_width+2))))" \
        "$(printf '─%.0s' $(seq 1 $((col3_width+2))))"

    # Данные
    for entry in "${data[@]}"; do
        IFS='|' read -r ip mac host <<< "$entry"
        printf "│ %-${col1_width}s │ %-${col2_width}s │ %-${col3_width}s │\n" "$ip" "$mac" "$host"
    done

    # Нижняя граница
    printf "└%s┴%s┴%s┘\n" \
        "$(printf '─%.0s' $(seq 1 $((col1_width+2))))" \
        "$(printf '─%.0s' $(seq 1 $((col2_width+2))))" \
        "$(printf '─%.0s' $(seq 1 $((col3_width+2))))"
}

# Универсальное сканирование
scan_network() {
    local network=$1

    echo -e "${GREEN}Сканирую: ${network}${NC}\n"

    # Запускаем nmap и парсим вывод напрямую
    local scan_output=$(sudo nmap -sn "$network" 2>/dev/null)

    # Проверяем, есть ли MAC адреса в выводе
    local has_mac=$(echo "$scan_output" | grep -c "MAC Address:")

    declare -a table_data=()
    local current_ip=""
    local current_host=""
    local current_mac=""

    while IFS= read -r line; do
        # Ищем строки с информацией об узле
        if echo "$line" | grep -q "Nmap scan report for"; then
            # Сохраняем предыдущий узел
            if [ -n "$current_ip" ]; then
                if [ "$has_mac" -gt 0 ] && [ -n "$current_mac" ]; then
                    # Есть MAC адрес
                    [ -z "$current_host" ] && current_host="-"
                    table_data+=("$current_ip|$current_mac|$current_host")
                elif [ "$has_mac" -eq 0 ]; then
                    # Нет MAC адресов (VPN)
                    [ -z "$current_host" ] && current_host="-"
                    table_data+=("$current_ip|-|$current_host")
                fi
            fi

            # Парсим новый узел
            current_ip=""
            current_host=""
            current_mac=""

            if echo "$line" | grep -q "("; then
                # Есть hostname
                current_host=$(echo "$line" | sed -E 's/.*Nmap scan report for ([^(]+)\(.*/\1/' | sed 's/\.lan$//' | xargs)
                current_ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            else
                # Только IP
                current_ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
                current_host="-"
            fi
        fi

        # Ищем MAC адрес если он есть
        if [ "$has_mac" -gt 0 ] && echo "$line" | grep -q "MAC Address:"; then
            current_mac=$(echo "$line" | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}')
        fi
    done <<< "$scan_output"

    # Добавляем последний узел
    if [ -n "$current_ip" ]; then
        if [ "$has_mac" -gt 0 ] && [ -n "$current_mac" ]; then
            [ -z "$current_host" ] && current_host="-"
            table_data+=("$current_ip|$current_mac|$current_host")
        elif [ "$has_mac" -eq 0 ]; then
            [ -z "$current_host" ] && current_host="-"
            table_data+=("$current_ip|-|$current_host")
        fi
    fi

    # Проверяем результат
    if [ ${#table_data[@]} -eq 0 ]; then
        echo -e "${RED}Активных узлов не найдено${NC}"
        echo -e "${YELLOW}Проверьте:${NC}"
        echo "  1. Правильно ли указана сеть?"
        echo "  2. Есть ли доступ к этой сети?"
        echo "  3. Попробуйте: sudo nmap -sn $network"
    else
        # Сортируем по IP
        mapfile -t sorted_data < <(printf '%s\n' "${table_data[@]}" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n)

        # Удаляем дубликаты по IP
        declare -A seen
        declare -a unique_data=()
        for entry in "${sorted_data[@]}"; do
            ip=$(echo "$entry" | cut -d'|' -f1)
            if [ -z "${seen[$ip]}" ]; then
                seen[$ip]=1
                unique_data+=("$entry")
            fi
        done

        draw_table "${unique_data[@]}"

        if [ "$has_mac" -eq 0 ]; then
            echo -e "\n${YELLOW}Примечание: MAC-адреса недоступны (VPN сеть)${NC}"
        fi

        echo -e "\n${GREEN}Узлов в сети: ${#unique_data[@]}${NC}"
    fi

    echo -e "${GREEN}Сканирование завершено!${NC}"
}

# Проверка доступности сети через ping
check_network_reachable() {
    local network=$1
    local test_ip=$(echo "$network" | cut -d. -f1-3).1

    if ping -c 1 -W 1 "$test_ip" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Главная функция
main() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Для работы требуются права root. Используйте: sudo $0${NC}"
        exit 1
    fi

    if [ $# -eq 0 ]; then
        # Автоопределение сети
        default_network=$(ip route | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' | head -1 | awk '{print $1}')
        if [ -n "$default_network" ]; then
            network=$default_network
            echo -e "${YELLOW}Использую сеть: ${network}${NC}\n"
        else
            echo -e "${RED}Не удалось определить сеть. Укажите вручную: sudo $0 192.168.31.0/24${NC}"
            exit 1
        fi
    else
        network=$1
    fi

    # Проверяем установку nmap
    if ! command -v nmap &> /dev/null; then
        echo -e "${YELLOW}nmap не установлен. Устанавливаю...${NC}"
        sudo apt update && sudo apt install nmap -y
    fi

    # Проверяем доступность сети
    if ! check_network_reachable "$network"; then
        echo -e "${RED}Сеть $network недоступна!${NC}"
        echo -e "${YELLOW}Проверьте подключение к VPN или укажите правильную сеть.${NC}"
        exit 1
    fi

    scan_network "$network"
}

main "$@"
