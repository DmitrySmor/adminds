#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../src/lib/colors.sh"

printf '%bКрасный%b\n' "$COLOR_RED" "$COLOR_RESET"
printf '%bЗелёный%b\n' "$COLOR_GREEN" "$COLOR_RESET"
printf '%bЖёлтый%b\n' "$COLOR_YELLOW" "$COLOR_RESET"
printf '%bСиний%b\n' "$COLOR_BLUE" "$COLOR_RESET"
printf '%bГолубой%b\n' "$COLOR_CYAN" "$COLOR_RESET"
printf '%bЖирный белый%b\n' "$COLOR_BOLD_WHITE" "$COLOR_RESET"
