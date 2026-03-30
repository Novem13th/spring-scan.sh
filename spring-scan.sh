#!/bin/bash

# Usage: ./spring_finder.sh targets.txt

INPUT=$1
OUTPUT="spring_targets.txt"
TMP="tmp_spring_scan.txt"

> $OUTPUT
> $TMP

echo "[*] Starting Spring Boot detection..."

while read -r url; do
    echo "[*] Checking $url"

    # нормализуем
    if [[ $url != http* ]]; then
        url="http://$url"
    fi

    # 1. Проверка /actuator
    actuator=$(curl -sk -o /dev/null -w "%{http_code}" "$url/actuator")

    # 2. Получаем headers + body
    response=$(curl -sk -D - "$url" -o -)

    # --- DETECTION FLAGS ---
    is_spring=0

    # actuator exists
    if [[ "$actuator" == "200" || "$actuator" == "401" || "$actuator" == "403" ]]; then
        echo "[+] $url -> actuator detected ($actuator)"
        is_spring=1
    fi

    # X-Application-Context header
    if echo "$response" | grep -qi "X-Application-Context"; then
        echo "[+] $url -> X-Application-Context header"
        is_spring=1
    fi

    # Whitelabel Error Page
    if echo "$response" | grep -qi "Whitelabel Error Page"; then
        echo "[+] $url -> Whitelabel page"
        is_spring=1
    fi

    # JSON Spring error format
    if echo "$response" | grep -q "\"timestamp\"" && echo "$response" | grep -q "\"status\""; then
        echo "[+] $url -> Spring JSON error pattern"
        is_spring=1
    fi

    # save result
    if [[ $is_spring -eq 1 ]]; then
        echo "$url" >> $OUTPUT
    fi

done < "$INPUT"

sort -u $OUTPUT -o $OUTPUT

echo "[*] Done. Results saved to $OUTPUT"
