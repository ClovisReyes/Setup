#!/system/bin/sh

STATUS_BAR_HEIGHT=20
EXCLUDED_PREFIXES="android com.android. com.google.android. com.qualcomm. com.mediatek. com.sec.android. com.xiaomi. com.huawei. org.chromium."

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!]${NC} %s\n" "$1"; }

read_input() {
    prompt_msg="$1"
    [ -n "$prompt_msg" ] && printf "%b" "$prompt_msg" >&2
    read -r input_val
    echo "$input_val"
}

# 1 Command Pasti: Injeksi SharedPreferences XML (Khusus Android 10 App Cloner)
clean_and_inject_window_keys() {
    xml_file="$1"
    left="$2"
    top="$3"
    right="$4"
    bottom="$5"
    pkg_dir="$6"

    APP_OWNER=$(stat -c '%u:%g' "$pkg_dir" 2>/dev/null)

    pref_dir=$(dirname "$xml_file")
    mkdir -p "$pref_dir" >/dev/null 2>&1

    existing_content=""
    if [ -f "$xml_file" ]; then
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
    if [ -n "$APP_OWNER" ]; then
        chown -R "$APP_OWNER" "$pref_dir" >/dev/null 2>&1
    fi
}

# 1 Command Pasti per Aksi: Freeform Transition Android 12
do_manual_recents_freeform() {
    pkg_name="$1"
    left="$2"
    top="$3"
    right="$4"
    bottom="$5"

    # 1 Command: Buka Recent Apps
    log_status "1. Menekan Recent Apps..."
    input keyevent 187
    sleep 2

    # 1 Command: Tap Logo Aplikasi (640, 96)
    log_status "2. Menekan Logo Aplikasi (X: 640, Y: 96)..."
    input tap 640 96
    sleep 1.5

    # 1 Command: Tap Tombol Freeform (928, 236)
    log_status "3. Menekan tombol Freeform (X: 928, Y: 236)..."
    input tap 928 236
    sleep 2

    # 1 Command Pasti: Ambil Task ID dari task list OS
    TASK_ID=$(dumpsys activity tasks | grep "$pkg_name" | grep -oE '#[0-9]+' | tr -d '#' | tail -n 1)

    if [ -n "$TASK_ID" ]; then
        log_status "Menerapkan posisi Grid Task #${TASK_ID}: (${left},${top} -> ${right},${bottom})"
        # 1 Command Pasti: Resize Task
        cmd activity task resize "$TASK_ID" "$left" "$top" "$right" "$bottom"
        # 1 Command Pasti: Fokuskan Task
        cmd activity task focus "$TASK_ID"
    else
        log_error "Task ID tidak ditemukan untuk $pkg_name"
    fi
}

ARG_SELECTION="$1"
ARG_ORIENT="$2"
ARG_OS="$3"

log_status "Memindai aplikasi terpasang..."

RAW_PACKAGES=$(pm list packages | cut -d':' -f2 | sort -u)

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

printf "${YELLOW}Ditemukan %s Aplikasi Terpasang:${NC}\n" "$TOTAL_FOUND"
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
        USER_INPUT=$(read_input "${CYAN}Masukkan nomor aplikasi (contoh: 30,31,32,33,34): ${NC}")
    fi
    
    USER_INPUT_CLEAN=$(echo "$USER_INPUT" | tr -d ' \r\t')

    if [ -z "$USER_INPUT_CLEAN" ]; then
        log_error "Input tidak boleh kosong! Masukkan nomor aplikasi."
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
        log_error "Input tidak valid! Masukkan nomor aplikasi yang tersedia."
        ARG_SELECTION=""
    fi
done

set -- $SELECTED_PACKAGES
COUNT=$#

ORIENT_CHOICE=""
while [ -z "$ORIENT_CHOICE" ]; do
    if [ -n "$ARG_ORIENT" ]; then
        ORIENT_INPUT="$ARG_ORIENT"
    else
        ORIENT_INPUT=$(read_input "${CYAN}Pilih Orientasi Layar [H] Horizontal / [V] Vertical: ${NC}")
    fi
    
    INPUT_CLEAN=$(echo "$ORIENT_INPUT" | tr -d ' \r\t' | tr '[:lower:]' '[:upper:]')

    if [ "$INPUT_CLEAN" = "H" ] || [ "$INPUT_CLEAN" = "V" ]; then
        ORIENT_CHOICE=$INPUT_CLEAN
    else
        log_error "Input tidak valid! Pilih H atau V."
        ARG_ORIENT=""
    fi
done

# 1 Command Pasti: Ambil Resolusi Layar
RAW_SIZE=$(wm size | grep -oE '[0-9]+x[0-9]+' | tail -n 1)

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
    SW=$MIN_DIM
    SH=$MAX_DIM

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
    SW=$MAX_DIM
    SH=$MIN_DIM

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

# 1 Command Pasti: Deteksi Versi Android OS
OS_VERSION=$(getprop ro.build.version.release | cut -d'.' -f1)
[ -n "$ARG_OS" ] && OS_VERSION="$ARG_OS"

# ##############################################################################
# ==============================================================================
#                      [[ PEMBATAS LOGIKA SISTEM OPERASI ]]
# ==============================================================================
# ##############################################################################

if [ "$OS_VERSION" = "10" ]; then
    # ##########################################################################
    # --------------------------------------------------------------------------
    #                     >>> BLOK EKSEKUSI: ANDROID 10 <<<
    #   - Menggunakan HEADER_HEIGHT=36 (Offset title bar App Cloner)
    #   - Total tinggi header diperhitungkan ke dalam pembagian kuadran
    #   - Menginjeksi koordinat ke SharedPreferences XML (${PKG}_preferences.xml)
    #   - Menjalankan aplikasi langsung dalam mode floating App Cloner
    # --------------------------------------------------------------------------
    # ##########################################################################
    
    HEADER_HEIGHT=36
    LAUNCH_DELAY=5

    TOTAL_HEADERS=$((ROWS * HEADER_HEIGHT))
    USABLE_GAME_H=$((SH - STATUS_BAR_HEIGHT - TOTAL_HEADERS))

    GW=$((SW / COLS))
    GH=$((USABLE_GAME_H / ROWS))

    log_status "Mode Grid Android 10: ${MODE_NAME} ${ROWS}x${COLS} (${COUNT} Aplikasi)"
    log_status "HEADER_HEIGHT: ${HEADER_HEIGHT}px (App Cloner Title Bar)"

    idx=0
    for PKG in $SELECTED_PACKAGES; do
        row=$((idx / COLS))
        col=$((idx % COLS))
        HEADER_OFFSET=$(((row + 1) * HEADER_HEIGHT))
        
        L=$((col * GW))
        T=$((STATUS_BAR_HEIGHT + (row * GH) + HEADER_OFFSET))
        R=$(((col == COLS - 1) ? SW : (L + GW)))
        B=$(((row == ROWS - 1) ? SH : (T + GH)))

        printf "${GREEN}[%d/%d]${NC} Setup Grid Layout (Android 10) -> %s\n" "$((idx+1))" "$COUNT" "$PKG"
        
        # 1 Command Pasti: Tutup aplikasi agar SharedPreferences dibaca ulang
        am force-stop "$PKG" >/dev/null 2>&1
        
        PREF_DIR="/data/data/$PKG/shared_prefs"
        PREF="$PREF_DIR/${PKG}_preferences.xml"
        mkdir -p "$PREF_DIR" >/dev/null 2>&1
        if [ ! -f "$PREF" ]; then
            echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' > "$PREF"
            echo '<map></map>' >> "$PREF"
        fi

        # Injeksi koordinat ke preferences XML App Cloner
        clean_and_inject_window_keys "$PREF" "$L" "$T" "$R" "$B" "/data/data/$PKG"

        # 1 Command Pasti: Buka Aplikasi
        monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

        log_status "Jeda $LAUNCH_DELAY detik..."
        sleep "$LAUNCH_DELAY"

        idx=$((idx+1))
    done

    echo "---------------------------------------------------"
    log_success "SELESAI! Seluruh ${COUNT} aplikasi Android 10 tertata rapi di Grid ${MODE_NAME}."

else
    # ##########################################################################
    # --------------------------------------------------------------------------
    #                     >>> BLOK EKSEKUSI: ANDROID 12 <<<
    #   - HEADER_HEIGHT DIHAPUS (Tanpa offset header bar / Native Freeform)
    #   - Usable height layar penuh dikurangi status bar saja
    #   - Membuka app, menekan Recent Apps, tap Logo & Freeform button
    #   - Mengunci dan menyelaraskan posisi window dengan cmd activity task resize
    # --------------------------------------------------------------------------
    # ##########################################################################

    LAUNCH_DELAY=10

    # 1 Command Pasti: Pengaturan Freeform AOSP Android 12
    settings put global enable_freeform_support 1 >/dev/null 2>&1
    settings put global force_resizable_activities 1 >/dev/null 2>&1
    settings put global freeform_window_management 1 >/dev/null 2>&1

    # HEADER_HEIGHT dihapus / ditiadakan untuk Android 12
    USABLE_GAME_H=$((SH - STATUS_BAR_HEIGHT))

    GW=$((SW / COLS))
    GH=$((USABLE_GAME_H / ROWS))

    log_status "Mode Grid Android 12: ${MODE_NAME} ${ROWS}x${COLS} (${COUNT} Aplikasi)"
    log_status "HEADER_HEIGHT: Dihapus / Tidak digunakan (Native AOSP Freeform)"

    # --------------------------------------------------------------------------
    # FASE 1 (Android 12): BUKA APLIKASI ➔ RECENT ➔ FREEFORM ➔ RESIZE TASK
    # --------------------------------------------------------------------------
    idx=0
    for PKG in $SELECTED_PACKAGES; do
        row=$((idx / COLS))
        col=$((idx % COLS))
        
        # Di Android 12 koordinat murni tanpa HEADER_OFFSET
        L=$((col * GW))
        T=$((STATUS_BAR_HEIGHT + (row * GH)))
        R=$(((col == COLS - 1) ? SW : (L + GW)))
        B=$(((row == ROWS - 1) ? SH : (T + GH)))

        printf "${GREEN}[%d/%d]${NC} Memproses Freeform -> %s (Grid #%d: %d,%d -> %d,%d)\n" "$((idx+1))" "$COUNT" "$PKG" "$((idx+1))" "$L" "$T" "$R" "$B"

        # 1 Command Pasti: Buka Aplikasi
        monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

        log_status "Menunggu $LAUNCH_DELAY detik agar aplikasi terbuka..."
        sleep "$LAUNCH_DELAY"

        # Sentuh Recent ➔ Sentuh Logo (640, 96) ➔ Sentuh Freeform (928, 236) ➔ Kunci Grid Resize
        do_manual_recents_freeform "$PKG" "$L" "$T" "$R" "$B"

        idx=$((idx+1))
    done

    # --------------------------------------------------------------------------
    # FASE 2 (Android 12): PENYELARASAN & FOKUS SELURUH JENDELA DI LAYAR
    # --------------------------------------------------------------------------
    log_status "Menyelaraskan seluruh jendela Grid di layar..."
    sleep 1
    idx=0
    for PKG in $SELECTED_PACKAGES; do
        row=$((idx / COLS))
        col=$((idx % COLS))
        L=$((col * GW))
        T=$((STATUS_BAR_HEIGHT + (row * GH)))
        R=$(((col == COLS - 1) ? SW : (L + GW)))
        B=$(((row == ROWS - 1) ? SH : (T + GH)))

        # 1 Command Pasti: Ambil Task ID
        TASK_ID=$(dumpsys activity tasks | grep "$PKG" | grep -oE '#[0-9]+' | tr -d '#' | tail -n 1)

        if [ -n "$TASK_ID" ]; then
            # 1 Command Pasti: Resize Task
            cmd activity task resize "$TASK_ID" "$L" "$T" "$R" "$B" >/dev/null 2>&1
            # 1 Command Pasti: Fokuskan Task
            cmd activity task focus "$TASK_ID" >/dev/null 2>&1
        fi
        idx=$((idx+1))
    done

    echo "---------------------------------------------------"
    log_success "SELESAI! Seluruh ${COUNT} aplikasi Android 12 tertata rapi di Grid ${MODE_NAME}."
fi
