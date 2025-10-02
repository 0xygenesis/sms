#!/bin/sh
# ================================
# SMS Monitor + Auto UNREG/BUY Paket Edu + Cek Kuota
# Versi: FIXED (Telegram Newline)
# ================================

CONFIG_FILE="/etc/config/sms_monitor.conf"
SERVICE_FILE="/etc/init.d/sms-monitor"
LOG_FILE="/var/log/sms-monitor.log"
INSTALL_PATH="/usr/bin/sms-monitor"

CACHE_FILE="/tmp/last_sms_date"

# --- Default Konfigurasi Modem ---
BASE_URL="http://192.168.1.1:49153/api"
DEVICE_ID="ce051715a010021405"

# --- Trigger Pesan ---
TRIGGER_UNREG_1="Sisa kuota EduConference 30GB Anda kurang dari 3GB"
TRIGGER_UNREG_2="Sisa kuota EduConference 30GB Anda sudah habis"
TRIGGER_BELI="Anda sudah berhenti berlangganan EduConference 30GB"
TRIGGER_ACTIVE="EduConference 30GB Anda sdh aktif"

# --- Fungsi kirim Telegram (fix newline dengan urlencode) ---
send_telegram() {
    MESSAGE="$1"
    if curl -s --max-time 5 https://api.telegram.org > /dev/null; then
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            --data-urlencode "chat_id=$CHAT_ID" \
            --data-urlencode "text=$MESSAGE" > /dev/null
    else
        echo "$MESSAGE" >> /tmp/pending_notif.log
    fi
}

flush_pending_notif() {
    if [ -f /tmp/pending_notif.log ]; then
        while read -r MSG; do
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                --data-urlencode "chat_id=$CHAT_ID" \
                --data-urlencode "text=$MSG" > /dev/null
        done < /tmp/pending_notif.log
        rm -f /tmp/pending_notif.log
    fi
}

# --- Fungsi cek kuota via API ---
cek_kuota() {
    . "$CONFIG_FILE"
    send_telegram "⏳ Mengecek kuota untuk $MSISDN ..."

    RESPONSE=$(curl -s --max-time 30 "https://apigw.kmsp-store.com/sidompul/v4/cek_kuota?msisdn=${MSISDN}&isJSON=true" \
        -H "Authorization: Basic c2lkb21wdWxhcGk6YXBpZ3drbXNw" \
        -H "X-API-Key: 60ef29aa-a648-4668-90ae-20951ef90c55" \
        -H "X-App-Version: 4.0.0")

    STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null)
    HASIL=$(echo "$RESPONSE" | jq -r '.data.hasil' 2>/dev/null)

    if [ "$STATUS" != "true" ]; then
        send_telegram "❌ Gagal cek kuota (server error)"
        return
    fi

    if [ -n "$HASIL" ] && [ "$HASIL" != "null" ]; then
        CLEANED=$(echo "$HASIL" | sed 's/<br>/\n/g' | sed 's/=//g')
        FILTERED=$(echo "$CLEANED" | sed -n '/🎁 Quota:/,/🌲 Sisa Kuota:/p')
        MESSAGE=$(printf "📊 Info Kuota untuk %s:\n\n%s" "$MSISDN" "$FILTERED")
        send_telegram "$MESSAGE"
    else
        send_telegram "❌ Tidak ada info kuota."
    fi
}

# --- Fungsi monitoring SMS ---
start_monitoring() {
    echo "[$(date '+%F %T')] Memulai monitoring SMS..." >> "$LOG_FILE"
    . "$CONFIG_FILE"

    LAST_QUOTA_CHECK=0

    while true; do
        SMS_JSON=$(curl -s "$BASE_URL/devices/$DEVICE_ID/messages?limit=1")

        SENDER=$(echo "$SMS_JSON" | jq -r '.data.messages[0].address')
        BODY=$(echo "$SMS_JSON"   | jq -r '.data.messages[0].body')
        DATE=$(echo "$SMS_JSON"   | jq -r '.data.messages[0].date')

        LAST_DATE=$(cat "$CACHE_FILE" 2>/dev/null || echo "")

        # --- Cek SMS baru ---
        if [ "$DATE" != "$LAST_DATE" ] && [ -n "$BODY" ]; then
            MARK=""
            if echo "$BODY" | grep -qi "EduConference"; then
                MARK="✨ EduConference ✨"
            fi

            TEXT=$(printf "📩 SMS Baru %s\n\nDari: %s\nTanggal: %s\nIsi: %s" "$MARK" "$SENDER" "$DATE" "$BODY")
            send_telegram "$TEXT"

            echo "$DATE" > "$CACHE_FILE"
            echo "[$(date '+%F %T')] SMS terkirim ke Telegram ($DATE)" >> "$LOG_FILE"

            # --- Trigger UNREG ---
            if echo "$BODY" | grep -q "$TRIGGER_UNREG_1" || echo "$BODY" | grep -q "$TRIGGER_UNREG_2"; then
                send_telegram "ℹ️ Paket EduConference akan segera di-UNREG..."
                adb shell am start -a android.intent.action.CALL -d "tel:*808*5*2*1*1%23"
                sleep 20
                adb shell input keyevent 4
                sleep 10
            fi

            # --- Trigger BELI ---
            if echo "$BODY" | grep -q "$TRIGGER_BELI"; then
                send_telegram "ℹ️ Konfirmasi 'Berhenti Berlangganan' diterima, memulai pembelian paket..."
                adb shell am start -a android.intent.action.CALL -d "tel:*808*4*1*1*1%23"
                sleep 20
                adb shell input keyevent 4
                sleep 1
                adb shell input keyevent 3
                flush_pending_notif
            fi

            # --- Trigger Paket Aktif ---
            if echo "$BODY" | grep -q "$TRIGGER_ACTIVE"; then
                flush_pending_notif
                send_telegram "✅ Paket EduConference berhasil dibeli dan sudah aktif."
                cek_kuota   # langsung cek kuota setelah aktif
            fi
        fi

        # --- Cek kuota tiap 2 jam ---
        NOW=$(date +%s)
        if [ $((NOW - LAST_QUOTA_CHECK)) -ge 7200 ]; then
            cek_kuota
            LAST_QUOTA_CHECK=$NOW
        fi

        sleep 3
    done
}

# --- Installer ---
run_installation() {
    clear
    echo "===== Installer SMS Monitor ====="

    opkg update > /dev/null 2>&1
    opkg install curl jq adb > /dev/null 2>&1

    printf "Masukkan BOT_TOKEN: "
    read BOT_TOKEN
    printf "Masukkan CHAT_ID: "
    read CHAT_ID
    printf "Masukkan Nomor HP (62xxx): "
    read MSISDN

    cat > "$CONFIG_FILE" <<EOF
BOT_TOKEN='${BOT_TOKEN}'
CHAT_ID='${CHAT_ID}'
MSISDN='${MSISDN}'
EOF

    cp "$0" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    cat > "$SERVICE_FILE" <<EOF
#!/bin/sh /etc/rc.common
SERVICE_NAME="sms-monitor"
SERVICE_SCRIPT="$INSTALL_PATH"
LOG_FILE="$LOG_FILE"
START=99
STOP=10

start() {
    echo "Starting \$SERVICE_NAME"
    nohup "\$SERVICE_SCRIPT" --start-monitor >> "\$LOG_FILE" 2>&1 &
}

stop() {
    echo "Stopping \$SERVICE_NAME"
    PID=\$(pgrep -f "\$SERVICE_SCRIPT --start-monitor")
    [ -n "\$PID" ] && kill -9 \$PID
}
EOF
    chmod +x "$SERVICE_FILE"

    "$SERVICE_FILE" enable
    "$SERVICE_FILE" start
    echo "✅ Service aktif. Cek log di: tail -f $LOG_FILE"
}

# --- MAIN ---
case "$1" in
    --start-monitor) start_monitoring ;;
    --cek-kuota) cek_kuota ;;
    *) run_installation ;;
esac
