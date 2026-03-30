#!/bin/bash

INPUT=$1
OUTPUT="spring_targets.txt"

> $OUTPUT

echo "[*] Advanced Spring Boot scan..."

check_target() {
    url=$1

    # нормализация
    if [[ ! "$url" =~ ^http ]]; then
        url="http://$url"
    fi

    UA="Mozilla/5.0"

    # список путей
    paths=(
        ""
        "/"
        "/error"
        "/actuator"
        "/actuator/health"
        "/actuator/info"
    )

    for path in "${paths[@]}"; do
        full="$url$path"

        resp=$(curl -sk --max-time 6 -A "$UA" "$full")

        # 1. Whitelabel
        if echo "$resp" | grep -qi "Whitelabel Error Page"; then
            echo "[+] Spring (whitelabel): $url"
            echo "$url" >> $OUTPUT
            return
        fi

        # 2. actuator JSON
        if echo "$resp" | grep -qiE '"_links"|\"status\"'; then
            echo "[+] Spring (actuator): $url"
            echo "$url" >> $OUTPUT
            return
        fi

        # 3. error JSON Spring style
        if echo "$resp" | grep -qiE '"timestamp"|\"path\"|\"error\"'; then
            echo "[+] Spring (error JSON): $url"
            echo "$url" >> $OUTPUT
            return
        fi
    done

    # 4. headers отдельно
    headers=$(curl -sk -I --max-time 5 -A "$UA" "$url")
    if echo "$headers" | grep -qi "X-Application-Context"; then
        echo "[+] Spring (header): $url"
        echo "$url" >> $OUTPUT
        return
    fi
}

export -f check_target
export OUTPUT

cat "$INPUT" | xargs -P 20 -I{} bash -c 'check_target "$@"' _ {}

sort -u $OUTPUT -o $OUTPUT

echo "[*] Done. Found $(wc -l < $OUTPUT) Spring targets."
