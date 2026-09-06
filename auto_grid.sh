#!/system/bin/sh
# ==============================================================================
# SCRIPT : setlayout_a12.sh
# TARGET : Android 12 / 12L (S - API 31/32) Cloud Phone / Emulator
# DESKRIPSI : Otomatisasi Grid Layout & Freeform Window khusus Android 12
#              (Bypass Phantom Processes, Window Blurs OFF, Presisi Koordinat 1280x720)
# ==============================================================================

STATUS_BAR_HEIGHT=20
HEADER_HEIGHT=
LAUNCH_DELAY=10

EXCLUDED_PREFIXES="android com.android. com.google.android. com.qualcomm. com.mediatek. com.sec.android. com.xiaomi. com.huawei. org.chromium."

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!]${NC} %s\n" "$1"; }

# ------------------------------------------------------------------------------
# 1. OPTIMASI SISTEM KHUSUS ANDROID 12 (BYPASS PHANTOM PROCESSES & FREEFORM)
# ------------------------------------------------------------------------------
log_status "Mengonfigurasi flag Multi-Window & Bypass Phantom Processes (Android 12)..."

# Matikan batas 32 child processes bawaan Android 12 agar background bot tidak di-kill
/system/bin/device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
settings put global max_phantom_processes 2147483647 >/dev/null 2>&1
settings put global settings_enable_monitor_phantom_procs 0 >/dev/null 2>&1
setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false >/dev/null 2>&1

# Aktifkan Freeform & Matikan efek blur render yang memberatkan GPU di Android 12
settings put global enable_freeform_support 1 >/dev/null 2>&1
settings put global force_resizable_activities 1 >/dev/null 2>&1
settings put global freeform_window_management 1 >/dev/null 2>&1
settings put global disable_window_blurs 1 >/dev/null 2>&1
setprop persist.sys.debug.freeform_window 1 >/dev/null 2>&1
setprop persist.sys.debug.force_resizable 1 >/dev/null 2>&1

# ------------------------------------------------------------------------------
# 2. INJEKSI PREFERENSI WINDOW APP CLONER (SHARED PREFS XML)
# ------------------------------------------------------------------------------
clean_and_inject_window_keys() {
    xml_file="$1"
    left="$2"
    top="$3"
    right="$4"
    bottom="$5"
    pkg_dir="$6"

    APP_OWNER=""
    if [ -d "$pkg_dir" ]; then
        APP_OWNER=$(stat -c '%u:%g' "$pkg_dir" 2>/dev/null)
        [ -z "$APP_OWNER" ] && APP_OWNER=$(ls -ld "$pkg_dir" 2>/dev/null | awk '{print $3":"$4}')
    fi

    pref_dir=$(dirname "$xml_file")
    mkdir -p "$pref_dir" >/dev/null 2>&1
    chmod 777 "$pref_dir" >/dev/null 2>&1
    chattr -i "$xml_file" >/dev/null 2>&1

    existing_content=""
    if [ -f "$xml_file" ]; then
        chmod 666 "$xml_file" >/dev/null 2>&1
        existing_content=$(grep -v '</map>' "$xml_file" 2>/dev/null | grep -v 'name="app_cloner_' | grep -v '<?xml' | grep -v '<map')
    fi

    {
        echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>'
        echo '<map>'
        [ -n "$existing_content" ] && echo "$existing_content"
        
        echo '  <boolean name="app_cloner_freeform_window" value="true" />'
        echo '  <boolean name="app_cloner_floating_window" value="true" />'
        echo '  <boolean name="app_cloner_enable_freeform_window" value="true" />'
        echo '  <boolean name="app_cloner_enable_floating_window" value="true" />'
        echo '  <boolean name="app_cloner_display_in_floating_window" value="true" />'
        echo '  <boolean name="app_cloner_save_window_position" value="true" />'
        echo '  <boolean name="app_cloner_remember_window_position" value="true" />'
        echo '  <boolean name="app_cloner_restore_window_position" value="true" />'
        
        for prefix in app_cloner_current_window app_cloner_initial_window app_cloner_window app_cloner_default_window app_cloner_last_window app_cloner_saved_window app_cloner_freeform_window; do
            echo "  <int name=\"${prefix}_left\" value=\"${left}\" />"
            echo "  <int name=\"${prefix}_top\" value=\"${top}\" />"
            echo "  <int name=\"${prefix}_right\" value=\"${right}\" />"
            echo "  <int name=\"${prefix}_bottom\" value=\"${bottom}\" />"
        done
        echo '</map>'
    } > "$xml_file"

    chmod 666 "$xml_file" >/dev/null 2>&1
    chmod 777 "$pref_dir" >/dev/null 2>&1
    if [ -n "$APP_OWNER" ]; then
        chown -R "$APP_OWNER" "$pref_dir" >/dev/null 2>&1
    fi
}

# ------------------------------------------------------------------------------
# 3. FUNGSI EKSEKUSI RECENT APPS -> FREEFORM (PRESISI KOORDINAT CLOUDPHONE)
# ------------------------------------------------------------------------------
do_manual_recents_freeform_a12() {
    pkg_name="$1"
    left="$2"
    top="$3"
    right="$4"
    bottom="$5"

    # 1. Buka Recent Apps (KEYCODE_APP_SWITCH = 187)
    log_status "1. Menekan Recent Apps..."
    input keyevent 187 >/dev/null 2>&1
    sleep 2

    # 2. Tap Logo Aplikasi pada koordinat PRESISI X:640 Y:96
    log_status "2. Menekan Logo Aplikasi (X: 640, Y: 96)..."
    input tap 640 96 >/dev/null 2>&1
    sleep 1.5

    # 3. Tap Tombol Freeform pada koordinat PRESISI X:928 Y:236
    log_status "3. Menekan tombol Freeform (X: 928, Y: 236)..."
    input tap 928 236 >/dev/null 2>&1
    sleep 2

    # 4. Ambil Task ID khusus Android 12 (Mendukung taskId= dan t123)
    TASK_ID=$(dumpsys activity activities 2>/dev/null | grep -E "topResumedActivity|mResumedActivity|ResumedActivity" | grep -oE '(taskId=[0-9]+|t[0-9]+)' | grep -oE '[0-9]+' | head -n 1)
    if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "0" ]; then
        TASK_ID=$(dumpsys activity tasks 2>/dev/null | grep -E "A=[0-9]+:${pkg_name}|${pkg_name}" | grep -oE '#[0-9]+' | tr -d '#' | tail -n 1)
    fi
    if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "0" ]; then
        TASK_ID=$(dumpsys activity recents 2>/dev/null | grep -B 2 "$pkg_name" | grep -oE 'Task\{[^}]*#[0-9]+' | grep -oE '#[0-9]+' | tr -d '#' | head -n 1)
    fi

    if [ -n "$TASK_ID" ] && [ "$TASK_ID" != "0" ]; then
        log_status "Menerapkan posisi Grid Task #${TASK_ID}: (${left},${top} -> ${right},${bottom})"
        cmd activity task resize "$TASK_ID" "$left" "$top" "$right" "$bottom" >/dev/null 2>&1
        am task resize "$TASK_ID" "$left" "$top" "$right" "$bottom" >/dev/null 2>&1
        cmd activity task focus "$TASK_ID" >/dev/null 2>&1
    else
        log_error "Task ID tidak terdeteksi untuk $pkg_name"
    fi
}

read_input_safe() {
    prompt_msg="$1"
    [ -n "$prompt_msg" ] && printf "%b" "$prompt_msg" >&2
    
    input_val=""
    if [ -c /dev/tty ]; then
        read input_val </dev/tty 2>/dev/null
    fi
    if [ -z "$input_val" ]; then
        if ! read input_val 2>/dev/null; then
            echo "EOF_DETECTED"
            return 1
        fi
    fi
    echo "$input_val"
    return 0
}

ARG_SELECTION="$1"
ARG_ORIENT="$2"

log_status "Memindai aplikasi terpasang (Android 12)..."
RAW_PACKAGES=$(pm list packages 2>/dev/null | cut -d':' -f2 | sort -u)

FILTERED_PACKAGES=""
for pkg in $RAW_PACKAGES; do
    [ -z "$pkg" ] && continue
    IS_SYS=0
    for sys_pref in $EXCLUDED_PREFIXES; do
        case "$pkg" in
            ${sys_pref}*) IS_SYS=1; break ;;
        esac
    done
    [ "$IS_SYS" -eq 0 ] && FILTERED_PACKAGES="$FILTERED_PACKAGES $pkg"
done

ALL_CLONES=$(echo "$FILTERED_PACKAGES" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
if [ -z "$ALL_CLONES" ]; then
    log_error "Tidak ada aplikasi ditemukan!"
    exit 1
fi

set -- $ALL_CLONES
ARRAY_CLONES="$@"
TOTAL_FOUND=$#

printf "${YELLOW}Ditemukan %s Aplikasi Terpasang (Android 12):${NC}\n" "$TOTAL_FOUND"
printf "---------------------------------------------------\n"
i=1
for pkg in $ARRAY_CLONES; do
    printf "  [%3d] %s\n" "$i" "$pkg"
    i=$((i+1))
done
printf "---------------------------------------------------\n"

SELECTED_PACKAGES=""
while [ -z "$SELECTED_PACKAGES" ]; do
    if [ -n "$ARG_SELECTION" ]; then
        USER_INPUT="$ARG_SELECTION"
    else
        USER_INPUT=$(read_input_safe "${CYAN}Masukkan nomor aplikasi (contoh: 30,31,32,33,34): ${NC}")
        if [ "$USER_INPUT" = "EOF_DETECTED" ]; then
            log_error "Input tertutup. Gunakan: sh setlayout_a12.sh <nomor> <H/V>"
            exit 1
        fi
    fi
    
    USER_INPUT_CLEAN=$(echo "$USER_INPUT" | tr -d ' \r\t')
    if [ -z "$USER_INPUT_CLEAN" ]; then
        log_error "Input tidak boleh kosong!"
        ARG_SELECTION=""
        continue
    fi

    USER_CHOICE=$(echo "$USER_INPUT_CLEAN" | tr ',' ' ')
    VALID=1
    TMP_SELECTION=""
    
    for num in $USER_CHOICE; do
        num_clean=$(echo "$num" | tr -cd '0-9')
        if [ -n "$num_clean" ] && [ "$num_clean" -ge 1 ] && [ "$num_clean" -le "$TOTAL_FOUND" ]; then
            val=$(echo "$ARRAY_CLONES" | awk -v n="$num_clean" '{print $n}')
            [ -n "$val" ] && TMP_SELECTION="$TMP_SELECTION $val"
        else
            VALID=0
            break
        fi
    done
    
    if [ "$VALID" -eq 1 ] && [ -n "$TMP_SELECTION" ]; then
        SELECTED_PACKAGES=$TMP_SELECTION
    else
        log_error "Nomor aplikasi tidak valid!"
        ARG_SELECTION=""
    fi
done

COUNT=0
for p in $SELECTED_PACKAGES; do COUNT=$((COUNT+1)); done

ORIENT_CHOICE=""
while [ -z "$ORIENT_CHOICE" ]; do
    if [ -n "$ARG_ORIENT" ]; then
        ORIENT_INPUT="$ARG_ORIENT"
    else
        ORIENT_INPUT=$(read_input_safe "${CYAN}Pilih Orientasi Layar [H] Horizontal / [V] Vertical: ${NC}")
        [ "$ORIENT_INPUT" = "EOF_DETECTED" ] && ORIENT_INPUT="H"
    fi
    
    INPUT_CLEAN=$(echo "$ORIENT_INPUT" | tr -d ' \r\t' | tr '[:lower:]' '[:upper:]')
    if [ "$INPUT_CLEAN" = "H" ] || [ "$INPUT_CLEAN" = "V" ]; then
        ORIENT_CHOICE=$INPUT_CLEAN
    else
        log_error "Pilihan tidak valid! Masukkan H atau V."
        ARG_ORIENT=""
    fi
done

# Tutup keyboard jika masih terbuka
input keyevent 111 >/dev/null 2>&1

# Deteksi Resolusi Layar
RAW_SIZE=""
command -v wm >/dev/null 2>&1 && RAW_SIZE=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -n 1)
[ -z "$RAW_SIZE" ] && RAW_SIZE=$(dumpsys display 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -n 1)
[ -z "$RAW_SIZE" ] && RAW_SIZE="1280x720"

DIM1=$(echo "$RAW_SIZE" | cut -d'x' -f1)
DIM2=$(echo "$RAW_SIZE" | cut -d'x' -f2)

if [ "$DIM1" -gt "$DIM2" ]; then
    MAX_DIM=$DIM1
    MIN_DIM=$DIM2
else
    MAX_DIM=$DIM2
    MIN_DIM=$DIM1
fi

if [ "$ORIENT_CHOICE" = "V" ]; then
    MODE_NAME="VERTICAL (Portrait)"
    W=$MIN_DIM
    H=$MAX_DIM
    case $COUNT in
        2) COLS=1; ROWS=2 ;;
        3) COLS=1; ROWS=3 ;;
        4) COLS=2; ROWS=2 ;;
        5|6) COLS=2; ROWS=3 ;;
        7|8) COLS=2; ROWS=4 ;;
        9|10) COLS=2; ROWS=5 ;;
        *) COLS=2; ROWS=$(((COUNT + COLS - 1) / COLS)) ;;
    esac
else
    MODE_NAME="HORIZONTAL (Landscape)"
    W=$MAX_DIM
    H=$MIN_DIM
    case $COUNT in
        2) COLS=2; ROWS=1 ;;
        3) COLS=3; ROWS=1 ;;
        4) COLS=2; ROWS=2 ;;
        5|6) COLS=3; ROWS=2 ;;
        7|8|9) COLS=3; ROWS=3 ;;
        10|11|12) COLS=4; ROWS=3 ;;
        *) COLS=4; ROWS=$(((COUNT + COLS - 1) / COLS)) ;;
    esac
fi

SW=$W; SH=$H
TOTAL_HEADERS=$((ROWS * HEADER_HEIGHT))
USABLE_GAME_H=$((SH - STATUS_BAR_HEIGHT - TOTAL_HEADERS))

GW=$((SW / COLS))
GH=$((USABLE_GAME_H / ROWS))

log_status "Mode Grid Android 12: ${MODE_NAME} ${ROWS}x${COLS} (${COUNT} Aplikasi)"

# ==============================================================================
# FASE 1: BUKA SETIAP APLIKASI ➔ UBAH KE FREEFORM ➔ RESIZE KE KUADRAN MASING-MASING
# ==============================================================================
idx=0
for PKG in $SELECTED_PACKAGES; do
    row=$((idx / COLS))
    col=$((idx % COLS))
    HEADER_OFFSET=$(((row + 1) * HEADER_HEIGHT))
    
    L=$((col * GW))
    T=$((STATUS_BAR_HEIGHT + (row * GH) + HEADER_OFFSET))
    R=$(((col == COLS - 1) ? SW : (L + GW)))
    B=$(((row == ROWS - 1) ? SH : (T + GH)))

    printf "${GREEN}[%d/%d]${NC} Memproses Freeform A12 -> %s (Grid #%d: %d,%d -> %d,%d)\n" "$((idx+1))" "$COUNT" "$PKG" "$((idx+1))" "$L" "$T" "$R" "$B"
    
    PREF_DIR="/data/data/$PKG/shared_prefs"
    PREF="$PREF_DIR/${PKG}_preferences.xml"
    mkdir -p "$PREF_DIR" >/dev/null 2>&1
    if [ ! -f "$PREF" ]; then
        echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' > "$PREF"
        echo '<map></map>' >> "$PREF"
    fi
    clean_and_inject_window_keys "$PREF" "$L" "$T" "$R" "$B" "/data/data/$PKG"

    # Buka Aplikasi dengan am start & monkey
    am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$PKG" >/dev/null 2>&1
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

    log_status "Menunggu $LAUNCH_DELAY detik agar aplikasi terbuka..."
    sleep "$LAUNCH_DELAY"

    # Sentuh Recent ➔ Sentuh Logo (640, 96) ➔ Sentuh Freeform (928, 236) ➔ Langsung Kunci Grid
    do_manual_recents_freeform_a12 "$PKG" "$L" "$T" "$R" "$B"

    idx=$((idx+1))
done

# ==============================================================================
# FASE AKHIR: MEMASTIKAN SELURUH JENDELA FOKUS DI DEPAN
# ==============================================================================
# Kembali ke Layar Utama (Home) 1x sebelum menyelaraskan seluruh jendela ke depan
log_status "Menekan tombol Home (kembali ke layar utama)..."
input keyevent 3 >/dev/null 2>&1
sleep 1.5

log_status "A12: Menyelaraskan seluruh jendela Grid di layar..."
sleep 1
idx=0
for PKG in $SELECTED_PACKAGES; do
    row=$((idx / COLS))
    col=$((idx % COLS))
    HEADER_OFFSET=$(((row + 1) * HEADER_HEIGHT))
    L=$((col * GW))
    T=$((STATUS_BAR_HEIGHT + (row * GH) + HEADER_OFFSET))
    R=$(((col == COLS - 1) ? SW : (L + GW)))
    B=$(((row == ROWS - 1) ? SH : (T + GH)))

    TASK_ID=$(dumpsys activity activities 2>/dev/null | grep "$PKG" | grep -oE '(taskId=[0-9]+|t[0-9]+)' | grep -oE '[0-9]+' | head -n 1)
    [ -z "$TASK_ID" ] && TASK_ID=$(dumpsys activity tasks 2>/dev/null | grep -E "A=[0-9]+:${PKG}|${PKG}" | grep -oE '#[0-9]+' | tr -d '#' | tail -n 1)

    if [ -n "$TASK_ID" ] && [ "$TASK_ID" != "0" ]; then
        cmd activity task resize "$TASK_ID" "$L" "$T" "$R" "$B" >/dev/null 2>&1
        cmd activity task focus "$TASK_ID" >/dev/null 2>&1
    fi
    idx=$((idx+1))
done

echo "---------------------------------------------------"
log_success "SELESAI! Seluruh ${COUNT} aplikasi tertata rapi di Grid ${MODE_NAME} (Android 12)."
