#!/bin/sh
# ================================
# Uninstaller SMS Monitor
# ================================

# --- Definisi Warna ---
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

# --- Lokasi File yang Akan Dihapus ---
CONFIG_FILE="/etc/config/sms_monitor.conf"
SERVICE_FILE="/etc/init.d/sms-monitor"
LOG_FILE="/var/log/sms-monitor.log"
SCRIPT_FILE="/usr/bin/sms-monitor"
CACHE_FILE="/tmp/last_sms_date"

# --- Banner ---
clear
echo -e "${YELLOW}###########################################${NC}"
echo -e "${YELLOW}#####${RED}   Uninstaller SMS Monitor By Rofiq${YELLOW}#####${NC}"
echo -e "${YELLOW}###########################################${NC}"
echo ""

# --- 1. Menghentikan dan Menonaktifkan Service ---
echo -e "${YELLOW}[1/3] Menghentikan dan menonaktifkan service...${NC}"
if [ -f "$SERVICE_FILE" ]; then
    "$SERVICE_FILE" stop
    "$SERVICE_FILE" disable
    echo -e "${GREEN} -> Service berhasil dihentikan dan dinonaktifkan.${NC}"
else
    echo " -> Service tidak ditemukan, dilewati."
fi

# --- 2. Menghapus File-file ---
echo -e "${YELLOW}[2/3] Menghapus file-file terkait...${NC}"

# Hapus file service
if [ -f "$SERVICE_FILE" ]; then
    rm "$SERVICE_FILE"
    echo " -> File service dihapus: $SERVICE_FILE"
fi

# Hapus file skrip utama
if [ -f "$SCRIPT_FILE" ]; then
    rm "$SCRIPT_FILE"
    echo " -> File skrip utama dihapus: $SCRIPT_FILE"
fi

# Hapus file konfigurasi
if [ -f "$CONFIG_FILE" ]; then
    rm "$CONFIG_FILE"
    echo " -> File konfigurasi dihapus: $CONFIG_FILE"
fi

# Hapus file log
if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    echo " -> File log dihapus: $LOG_FILE"
fi

# Hapus cache
if [ -f "$CACHE_FILE" ]; then
    rm "$CACHE_FILE"
    echo " -> File cache dihapus: $CACHE_FILE"
fi

echo -e "${GREEN} -> Semua file berhasil dihapus.${NC}"

# --- 3. Menghapus Diri Sendiri ---
echo -e "${YELLOW}[3/3] Membersihkan file uninstaller...${NC}"
rm -- "$0"

echo ""
echo -e "${YELLOW}=================================================${NC}"
echo -e "${GREEN}🎉     UNINSTALASI SMS MONITOR SELESAI!    🎉${NC}"
echo -e "${YELLOW}=================================================${NC}"
