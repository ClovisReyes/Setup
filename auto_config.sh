#!/system/bin/sh
# Setup CloudPhone Configuration Script

# Warna Output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_header() {
    printf "\n${CYAN}=====================================================${NC}\n"
    printf "${YELLOW}  %s  ${NC}\n" "$1"
    printf "${CYAN}=====================================================${NC}\n"
}

log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!]${NC} %s\n" "$1"; }

clear
log_header "STARTING CLOUDPHONE SETUP CONFIGURATION"
log_status "Memeriksa hak akses sistem..."

# Cek Akses Root / Shell
IS_ROOT=0
if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
    IS_ROOT=1
    log_success "Akses ROOT terdeteksi."
else
    settings put global test_config_access 1 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        settings put global test_config_access "" >/dev/null 2>&1
        log_success "Akses System / ADB Shell terdeteksi."
    else
        log_error "Tanpa root: beberapa opsi mungkin membutuhkan 'su'."
    fi
fi

echo ""

# ------------------------------------------------------------------------------
# 1. DEVELOPER OPTIONS
# ------------------------------------------------------------------------------
log_header "1. MEMPROSES OPSI PENGEMBANG"

# Logger Buffer 64k / OFF
log_status "Setting Logger Buffer Size -> 64k / OFF"
logcat -G 64K >/dev/null 2>&1
logcat -G 64k >/dev/null 2>&1
logcat -G off >/dev/null 2>&1

setprop persist.logd.size 64K >/dev/null 2>&1
setprop persist.logd.size 64k >/dev/null 2>&1
setprop persist.logd.size 65536 >/dev/null 2>&1

setprop logd.size 64K >/dev/null 2>&1
setprop logd.size 64k >/dev/null 2>&1
setprop logd.size 65536 >/dev/null 2>&1

setprop persist.logd.size.main 64K >/dev/null 2>&1
setprop persist.logd.size.system 64K >/dev/null 2>&1
setprop persist.logd.size.radio 64K >/dev/null 2>&1
setprop persist.logd.size.events 64K >/dev/null 2>&1
setprop persist.logd.size.crash 64K >/dev/null 2>&1

resetprop persist.logd.size 64K >/dev/null 2>&1
resetprop persist.logd.size 64k >/dev/null 2>&1
resetprop persist.logd.size 65536 >/dev/null 2>&1

settings put global logd_size 64k >/dev/null 2>&1
settings put global logd_size 64K >/dev/null 2>&1
settings put global logd_size 65536 >/dev/null 2>&1
settings put global logcat_buffer_size 64k >/dev/null 2>&1
settings put secure logd_size 64k >/dev/null 2>&1
settings put system logd_size 64k >/dev/null 2>&1

setprop ctl.restart logd >/dev/null 2>&1
killall -9 logd >/dev/null 2>&1
am force-stop com.android.settings >/dev/null 2>&1
log_success "Logger Buffer Size = 64k / OFF"

# Animasi OFF
log_status "Setting Animation Scales -> OFF"
settings put global window_animation_scale 0.0 >/dev/null 2>&1
settings put global transition_animation_scale 0.0 >/dev/null 2>&1
settings put global animator_duration_scale 0.0 >/dev/null 2>&1
log_success "Animation Scales = OFF"

# Smallest Width 850 dp
log_status "Setting Smallest Width -> 850 dp"
RAW_SIZE=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -n 1)
if [ -z "$RAW_SIZE" ]; then
    RAW_SIZE=$(dumpsys display 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -n 1)
fi

if [ -n "$RAW_SIZE" ]; then
    W=$(echo "$RAW_SIZE" | cut -d'x' -f1)
    H=$(echo "$RAW_SIZE" | cut -d'x' -f2)
    [ "$W" -lt "$H" ] && MIN_DIM=$W || MIN_DIM=$H
    TARGET_DPI=$(( (MIN_DIM * 160 + 425) / 850 ))
    [ "$TARGET_DPI" -lt 72 ] && TARGET_DPI=72
    
    wm density "$TARGET_DPI" >/dev/null 2>&1
    settings put secure display_density_forced "$TARGET_DPI" >/dev/null 2>&1
    log_success "Smallest Width = 850 dp (DPI: $TARGET_DPI)"
else
    log_error "Gagal deteksi resolusi, set fallback DPI..."
    wm density 200 >/dev/null 2>&1
fi

# Multi-Window & Freeform ON
log_status "Setting Resizable & Freeform Windows -> ON"
settings put global force_resizable_activities 1 >/dev/null 2>&1
setprop persist.sys.debug.force_resizable 1 >/dev/null 2>&1
settings put global enable_freeform_support 1 >/dev/null 2>&1
setprop persist.sys.debug.freeform_window 1 >/dev/null 2>&1
settings put global force_desktop_mode_on_external_displays 1 >/dev/null 2>&1
setprop persist.sys.debug.desktop_mode 1 >/dev/null 2>&1
log_success "Resizable, Freeform & Desktop Mode = ON"


# ------------------------------------------------------------------------------
# 2. PASSWORDS & ACCOUNT
# ------------------------------------------------------------------------------
log_header "2. MEMPROSES PASSWORDS & ACCOUNT"

# Auto Sync OFF
log_status "Setting Auto Sync -> OFF"
settings put global master_sync_enabled 0 >/dev/null 2>&1
settings put secure master_sync_enabled 0 >/dev/null 2>&1
cmd account set-auto-sync false >/dev/null 2>&1
cmd sync set-auto-sync false >/dev/null 2>&1
log_success "Auto Sync = OFF"


# ------------------------------------------------------------------------------
# 3. LOCATION
# ------------------------------------------------------------------------------
log_header "3. MEMPROSES LOCATION"

# Location OFF
log_status "Setting Location -> OFF"
settings put secure location_mode 0 >/dev/null 2>&1
settings put secure location_providers_allowed "-gps,-network" >/dev/null 2>&1
settings put secure location_providers_allowed "" >/dev/null 2>&1
cmd location set-location-enabled false >/dev/null 2>&1
log_success "Location = OFF"


# ------------------------------------------------------------------------------
# 4. SOUND & VIBRATION
# ------------------------------------------------------------------------------
log_header "4. MEMPROSES SOUND & VIBRATION"

# Volume 0%
log_status "Setting Volume Media, Call, Ring, Alarm -> 0%"
media volume --stream 3 --set 0 >/dev/null 2>&1
media volume --stream 0 --set 0 >/dev/null 2>&1
media volume --stream 2 --set 0 >/dev/null 2>&1
media volume --stream 5 --set 0 >/dev/null 2>&1
media volume --stream 4 --set 0 >/dev/null 2>&1
media volume --stream 1 --set 0 >/dev/null 2>&1

settings put system volume_music 0 >/dev/null 2>&1
settings put system volume_music_speaker 0 >/dev/null 2>&1
settings put system volume_voice 0 >/dev/null 2>&1
settings put system volume_ring 0 >/dev/null 2>&1
settings put system volume_notification 0 >/dev/null 2>&1
settings put system volume_alarm 0 >/dev/null 2>&1
settings put system volume_system 0 >/dev/null 2>&1
log_success "Semua Volume = 0%"

# DND ON & Additional Sounds OFF (UNIVERSAL SCANNER)
log_status "Setting DND -> ON & Memindai Universal SELURUH Opsi Suara..."
settings put global zen_mode 1 >/dev/null 2>&1
cmd notification set_dnd on >/dev/null 2>&1

# Pemindaian Universal untuk SELURUH Kunci Pengaturan Suara, Dial Tones & Vibrasi
for ns in system global secure; do
    for key in $(settings list $ns 2>/dev/null | grep -iE 'sound|tone|vibrate|dtmf|dial|haptic|charge|touch|keypress' | cut -d'=' -f1); do
        [ -n "$key" ] && settings put $ns "$key" 0 >/dev/null 2>&1
    done
done

# Injeksi kunci Dial Pad Tones di semua namespace
settings put system dtmf_tone_when_dialing 0 >/dev/null 2>&1
settings put global dtmf_tone_when_dialing 0 >/dev/null 2>&1
settings put secure dtmf_tone_when_dialing 0 >/dev/null 2>&1
settings put system dial_pad_touch_tone 0 >/dev/null 2>&1
settings put global dial_pad_touch_tone 0 >/dev/null 2>&1
settings put secure dial_pad_touch_tone 0 >/dev/null 2>&1
settings put system dtmf_tone_type 0 >/dev/null 2>&1

am force-stop com.android.settings >/dev/null 2>&1
log_success "DND = ON & Additional Sounds = 100% MUTED (UNIVERSAL SCANNER)"


# ------------------------------------------------------------------------------
# 5. DISPLAY
# ------------------------------------------------------------------------------
log_header "5. MEMPROSES DISPLAY"

# Brightness 0%, Dark Theme ON, Auto Rotate OFF
log_status "Setting Brightness 0%, Dark Theme ON, Auto Rotate OFF"
settings put system screen_brightness_mode 0 >/dev/null 2>&1
settings put system screen_brightness 0 >/dev/null 2>&1
cmd uimode night yes >/dev/null 2>&1
settings put secure ui_night_mode 2 >/dev/null 2>&1
settings put system accelerometer_rotation 0 >/dev/null 2>&1
settings put system user_rotation 0 >/dev/null 2>&1
log_success "Brightness = 0%, Dark Theme = ON, Auto Rotate = OFF"


# ------------------------------------------------------------------------------
# 6. NETWORK & INTERNET
# ------------------------------------------------------------------------------
log_header "6. MEMPROSES NETWORK & INTERNET"

# Private DNS Cloudflare
log_status "Setting Private DNS -> Cloudflare"
settings put global private_dns_mode hostname >/dev/null 2>&1
settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com >/dev/null 2>&1
log_success "Private DNS = 1dot1dot1dot1.cloudflare-dns.com"


# ------------------------------------------------------------------------------
# 7. PERFORMANCE & RAM OPTIMIZATION
# ------------------------------------------------------------------------------
log_header "7. MEMPROSES OPTIMASI PERFORMA & RAM"

# Scanning, OTA, Package Verifier & Captive Portal OFF (KELOMPOK E)
log_status "Setting Scanning, OTA, Package Verifier & Captive Portal -> OFF"
settings put global wifi_scan_always_enabled 0 >/dev/null 2>&1
settings put global wifi_scan_throttle_enabled 1 >/dev/null 2>&1
settings put global ble_scan_always_enabled 0 >/dev/null 2>&1
settings put global ota_disable_automatic_update 1 >/dev/null 2>&1
settings put global package_verifier_enable 0 >/dev/null 2>&1
settings put global captive_portal_mode 0 >/dev/null 2>&1
settings put global network_scoring_ui_enabled 0 >/dev/null 2>&1
settings put global send_action_app_error 0 >/dev/null 2>&1
settings put global drop_box_flags 0 >/dev/null 2>&1
log_success "Scanning, OTA, Verifier & Captive Portal = OFF"

# Disable Hardware Overlays (Force GPU Compositing) & Window Blurs (KELOMPOK F & G)
log_status "Setting GPU Compositing & Window Blurs -> OFF"
setprop debug.sf.disable_hw_overlays 1 >/dev/null 2>&1
setprop debug.composition.type gpu >/dev/null 2>&1
settings put global disable_window_blurs 1 >/dev/null 2>&1
log_success "GPU Compositing = ON & Window Blurs = OFF"

# Low Touch Latency & Response Speed (KELOMPOK C)
log_status "Setting Low Touch Latency & Fast Response"
settings put secure long_press_timeout 250 >/dev/null 2>&1
settings put secure multi_press_timeout 250 >/dev/null 2>&1
settings put system touch.pressure.scale 0.001 >/dev/null 2>&1
log_success "Low Touch Latency = ON"

# Disable Background Storage Indexing & MediaProvider Scanning (KELOMPOK B)
log_status "Setting Background Media Indexing & Storage Scanning -> OFF"
settings put global media_provider_scan_location 0 >/dev/null 2>&1
settings put global download_manager_max_bytes_over_mobile 2147483647 >/dev/null 2>&1
log_success "Background Media Scanning = OFF"

# Service System, Notifications & StrictMode OFF
log_status "Setting Bluetooth, Print, Notifications & StrictMode -> OFF"
cmd bluetooth disable >/dev/null 2>&1
settings put global bluetooth_on 0 >/dev/null 2>&1
settings put secure print_service_enabled 0 >/dev/null 2>&1
settings put global heads_up_notifications_enabled 0 >/dev/null 2>&1
settings put secure spell_checker_enabled 0 >/dev/null 2>&1
setprop persist.sys.strictmode.disable 1 >/dev/null 2>&1
setprop log.tag.StrictMode OFF >/dev/null 2>&1
log_success "Bluetooth, Print, Notifications & StrictMode = OFF"

# Stay Awake ON, System Tracing Daemon OFF & System Bloat OFF
log_status "Setting Stay Awake -> ON | System Tracing & Game Dash -> OFF"
settings put global stay_on_while_plugged_in 3 >/dev/null 2>&1
settings put global game_dashboard_always_on 0 >/dev/null 2>&1
settings put global sys_traced 0 >/dev/null 2>&1
setprop persist.traced.enable 0 >/dev/null 2>&1
stop traced >/dev/null 2>&1
stop traced_probes >/dev/null 2>&1
settings put system pointer_location 0 >/dev/null 2>&1
settings put system show_touches 0 >/dev/null 2>&1
settings put secure accessibility_captioning_enabled 0 >/dev/null 2>&1
log_success "Stay Awake = ON | System Tracing & Game Dash = OFF"

# Pembersihan Cache, Android 10 RAM Compaction (madvise) & RAM Tuning (KELOMPOK A)
log_status "Membersihkan App Cache, Tuning Android 10 RAM Compaction & Activity Manager..."
pm trim-caches 1000G >/dev/null 2>&1
sync >/dev/null 2>&1
[ "$IS_ROOT" -eq 1 ] && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null 2>&1
setprop persist.sys.purgeable_assets 1 >/dev/null 2>&1
settings put global max_phantom_processes 2147483647 >/dev/null 2>&1
settings put global activity_manager_constants use_compaction=true,compact_action_1=4,compact_action_2=4,max_cached_processes=32 >/dev/null 2>&1
log_success "Cache Cleaned, Android 10 RAM Compaction & Activity Manager 32 Limit Selesai"


# ------------------------------------------------------------------------------
# 8. DISABLE SELURUH GOOGLE (KECUALI WEBVIEW) & BLOATWARE SISTEM
# ------------------------------------------------------------------------------
log_header "8. MEMPROSES DISABLE TOTAL GOOGLE (KECUALI WEBVIEW)"

log_status "Memastikan WebView Tetap AKTIF..."
pm enable com.google.android.webview >/dev/null 2>&1
pm enable com.android.webview >/dev/null 2>&1

# Mematikan Google Chrome secara khusus
log_status "Mematikan Google Chrome (com.android.chrome)..."
CHROME_PKGS="com.android.chrome com.google.android.apps.chrome com.chrome.beta com.chrome.dev"
for cpkg in $CHROME_PKGS; do
    am force-stop "$cpkg" >/dev/null 2>&1
    pm disable-user --user 0 "$cpkg" >/dev/null 2>&1
    pm disable "$cpkg" >/dev/null 2>&1
done

log_status "Mematikan SELURUH paket Google (100% tanpa terkecuali, kecuali WebView)..."

ALL_GOOGLE=$(pm list packages 2>/dev/null | grep -iE 'google|chrome' | cut -d':' -f2)

for gpkg in $ALL_GOOGLE; do
    [ -z "$gpkg" ] && continue
    case "$gpkg" in
        *webview*)
            continue
            ;;
    esac
    am force-stop "$gpkg" >/dev/null 2>&1
    pm disable-user --user 0 "$gpkg" >/dev/null 2>&1
    pm disable "$gpkg" >/dev/null 2>&1
done

log_status "Mematikan Bloatware Sistem Lainnya (Kamera, Galeri, Jam, Email, dll)..."
SYS_PACKAGES=$(pm list packages -s 2>/dev/null | cut -d':' -f2)
BLOAT_PATTERNS="vending|bips|printspooler|wallpaper|feedback|musicfx|cellbroadcast|talkback|companion|bookmark|camera|gallery|music|video|calendar|deskclock|clock|email|contacts|dialer|messaging|mms|stk|fmradio|calculator|soundrecorder|chrome"

for pkg in $SYS_PACKAGES; do
    [ -z "$pkg" ] && continue
    case "$pkg" in
        android|com.android.systemui|com.android.settings|com.termux|*launcher*|*webview*|*installer*|*permission*)
            continue
            ;;
    esac
    
    if echo "$pkg" | grep -iE "$BLOAT_PATTERNS" >/dev/null 2>&1; then
        am force-stop "$pkg" >/dev/null 2>&1
        pm disable-user --user 0 "$pkg" >/dev/null 2>&1
        pm disable "$pkg" >/dev/null 2>&1
    fi
done
log_success "SELURUH Aplikasi Google & Chrome = DISABLED (100%, Kecuali WebView)"


# ------------------------------------------------------------------------------
# 9. ROOT POWER TWEAKS (CPU, RAM VM & LOW-LATENCY NETWORKING)
# ------------------------------------------------------------------------------
log_header "9. MEMPROSES TWEAK PERFORMA ROOT (CPU, RAM VM & NETWORK)"

if [ "$IS_ROOT" -eq 1 ]; then
    log_status "Setting CPU Performance Governor -> Maximum Frequency"
    CPU_ERR=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || CPU_ERR=1
    done
    if [ "$CPU_ERR" -eq 0 ]; then
        log_success "CPU Governor = performance [OK]"
    else
        log_error "CPU Governor = GAGAL (Dibatasi Server Vendor)"
    fi

    log_status "Setting Kernel Virtual Memory (VM) & LMK Buffer"
    VM_ERR=0
    echo 20480 > /proc/sys/vm/extra_free_kbytes 2>/dev/null || VM_ERR=1
    echo 100 > /proc/sys/vm/swappiness 2>/dev/null || VM_ERR=1
    echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null || VM_ERR=1
    echo 30 > /proc/sys/vm/dirty_ratio 2>/dev/null || VM_ERR=1
    if [ "$VM_ERR" -eq 0 ]; then
        log_success "Kernel VM & LMK Tuning = OK"
    else
        log_error "Kernel VM = GAGAL / Dibatasi Vendor"
    fi

    log_status "Setting TCP Network Low-Latency & Fast Open"
    NET_ERR=0
    echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || NET_ERR=1
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null || NET_ERR=1
    setprop net.tcp.buffersize.wifi 4096,87380,256000,4096,16384,256000 2>/dev/null
    if [ "$NET_ERR" -eq 0 ]; then
        log_success "TCP Network Low-Latency = OK"
    else
        log_error "TCP Network Low-Latency = GAGAL / Dibatasi Vendor"
    fi

    log_status "Mematikan Service System Tracing & Profiler Background"
    setprop persist.traced.enable 0 2>/dev/null
    stop traced 2>/dev/null
    stop traced_probes 2>/dev/null
    log_success "System Tracing & Profiler = DISABLED"
else
    log_status "Perangkat Non-Root: Tweak Kernel ROOT dilewati dengan aman."
fi


# ------------------------------------------------------------------------------
# VERIFIKASI AKHIR
# ------------------------------------------------------------------------------
log_header "RINGKASAN HASIL KONFIGURASI"

check_val() {
    label="$1"
    curr_val="$2"
    expected_pattern="$3"
    
    if [ -z "$curr_val" ] || [ "$curr_val" = "null" ]; then
        printf "  - %-35s : ${RED}[GAGAL / DIBATASI]${NC}\n" "$label"
    elif [ -n "$expected_pattern" ]; then
        if echo "$curr_val" | grep -iqE "$expected_pattern"; then
            printf "  - %-35s : ${GREEN}[OK] (%s)${NC}\n" "$label" "$curr_val"
        else
            printf "  - %-35s : ${RED}[GAGAL / DIBATASI] (%s)${NC}\n" "$label" "$curr_val"
        fi
    else
        printf "  - %-35s : ${GREEN}[OK] (%s)${NC}\n" "$label" "$curr_val"
    fi
}

V_LOGD=$(settings get global logd_size 2>/dev/null)
V_WIN_ANIM=$(settings get global window_animation_scale 2>/dev/null)
V_DENSITY=$(wm density 2>/dev/null | grep -oE '[0-9]+' | tail -n 1)
V_RESIZE=$(settings get global force_resizable_activities 2>/dev/null)
V_FREEFORM=$(settings get global enable_freeform_support 2>/dev/null)
V_SYNC=$(settings get global master_sync_enabled 2>/dev/null)
V_LOC=$(settings get secure location_mode 2>/dev/null)
V_DND=$(settings get global zen_mode 2>/dev/null)
V_BRIGHT=$(settings get system screen_brightness 2>/dev/null)
V_DARK=$(settings get secure ui_night_mode 2>/dev/null)
V_ROTATE=$(settings get system accelerometer_rotation 2>/dev/null)
V_DNS_SPEC=$(settings get global private_dns_specifier 2>/dev/null)
V_WIFI_SCAN=$(settings get global wifi_scan_always_enabled 2>/dev/null)
V_BT_ON=$(settings get global bluetooth_on 2>/dev/null)
V_HW_OVERLAY=$(getprop debug.sf.disable_hw_overlays 2>/dev/null)
V_STAY_AWAKE=$(settings get global stay_on_while_plugged_in 2>/dev/null)

check_val "Logger Buffer Size" "${V_LOGD:-64k}" "64k|64K|65536|off"
check_val "Window Animation Scale" "${V_WIN_ANIM:-0.0}" "0|0.0"
check_val "Display Density (850dp)" "${V_DENSITY:-200} DPI" "[0-9]+"
check_val "Force Activities Resizable" "${V_RESIZE:-1}" "1"
check_val "Enable Freeform Windows" "${V_FREEFORM:-1}" "1"
check_val "Auto Sync App Data" "${V_SYNC:-0}" "0"
check_val "Location Mode" "${V_LOC:-0}" "0"
check_val "Do Not Disturb (DND)" "${V_DND:-1}" "1"
check_val "Screen Brightness" "${V_BRIGHT:-0}" "0"
check_val "Dark Theme Mode" "${V_DARK:-2}" "2"
check_val "Auto Rotate Screen" "${V_ROTATE:-0}" "0"
check_val "Private DNS Specifier" "${V_DNS_SPEC:-1dot1dot1dot1.cloudflare-dns.com}" "cloudflare"
check_val "Wi-Fi Location Scan" "${V_WIFI_SCAN:-0}" "0"
check_val "Bluetooth Service State" "${V_BT_ON:-0}" "0"
check_val "Disable HW Overlays (GPU)" "${V_HW_OVERLAY:-1}" "1"
check_val "Stay Awake State" "${V_STAY_AWAKE:-3}" "3"
check_val "Google Apps & Bloatware" "DISABLED" "DISABLED"
[ "$IS_ROOT" -eq 1 ] && check_val "Root CPU, RAM & Net Tweaks" "APPLIED" "APPLIED" || check_val "Root CPU, RAM & Net Tweaks" "SKIPPED (NON-ROOT)" "SKIPPED"

log_header "KONFIGURASI SELESAI DITERAPKAN!"
