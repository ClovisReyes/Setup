#!/system/bin/sh

STATUS_BAR_HEIGHT=20
HEADER_HEIGHT=36
LAUNCH_DELAY=5

EXCLUDED_PREFIXES="android com.android. com.google.android. com.qualcomm. com.mediatek. com.sec.android. com.xiaomi. com.huawei. org.chromium."

clean_and_inject_window_keys() {
    xml_file="$1"
    left="$2"
    top="$3"
    right="$4"
    bottom="$5"

    chattr -i "$xml_file" >/dev/null 2>&1
    chmod 666 "$xml_file" >/dev/null 2>&1

    sed -i '/name="app_cloner_.*window_/d' "$xml_file" >/dev/null 2>&1

    prefixes="app_cloner_current_window app_cloner_initial_window app_cloner_window app_cloner_default_window app_cloner_last_window app_cloner_saved_window app_cloner_freeform_window"
    
    xml_block=""
    for prefix in $prefixes; do
        xml_block="${xml_block}  <int name=\"${prefix}_left\" value=\"${left}\" \/>\n"
        xml_block="${xml_block}  <int name=\"${prefix}_top\" value=\"${top}\" \/>\n"
        xml_block="${xml_block}  <int name=\"${prefix}_right\" value=\"${right}\" \/>\n"
        xml_block="${xml_block}  <int name=\"${prefix}_bottom\" value=\"${bottom}\" \/>\n"
    done

    sed -i "s|<\/map>|${xml_block}<\/map>|g" "$xml_file" >/dev/null 2>&1

    chmod 444 "$xml_file" >/dev/null 2>&1
}

launch_app() {
    pkg_name="$1"
    monkey -p "$pkg_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
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

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!]${NC} %s\n" "$1"; }

ARG_SELECTION="$1"
ARG_ORIENT="$2"

log_status "Memindai aplikasi terpasang..."

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
        USER_INPUT=$(read_input_safe "${CYAN}Masukkan nomor aplikasi (contoh: 30,31,32,33,34): ${NC}")
        if [ "$USER_INPUT" = "EOF_DETECTED" ]; then
            log_error "Saluran masukan tertutup. Silakan jalankan perintah dengan nomor: sh setlayout.sh 30,31,32,33,34 H"
            exit 1
        fi
    fi
    
    USER_INPUT_CLEAN=$(echo "$USER_INPUT" | tr -d ' \r\t')

    if [ -z "$USER_INPUT_CLEAN" ]; then
        log_error "Input tidak boleh kosong! Masukkan nomor aplikasi (contoh: 30,31,32,33,34)."
        ARG_SELECTION=""
        continue
    fi

    USER_CHOICE=$(echo "$USER_INPUT_CLEAN" | tr ',' ' ')
    VALID=1
    TMP_SELECTION=""
    
    for num in $USER_CHOICE; do
        num_clean=$(echo "$num" | tr -cd '0-9')
        if [ -n "$num_clean" ]; then
            if [ "$num_clean" -ge 1 ] && [ "$num_clean" -le "$TOTAL_FOUND" ]; then
                val=$(echo "$ARRAY_CLONES" | awk -v n="$num_clean" '{print $n}')
                [ -n "$val" ] && TMP_SELECTION="$TMP_SELECTION $val"
            else
                VALID=0
                break
            fi
        else
            VALID=0
            break
        fi
    done
    
    if [ "$VALID" -eq 1 ] && [ -n "$TMP_SELECTION" ]; then
        SELECTED_PACKAGES=$TMP_SELECTION
    else
        log_error "Input tidak valid! Masukkan nomor aplikasi yang tersedia (contoh: 30,31,32,33,34)."
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
        if [ "$ORIENT_INPUT" = "EOF_DETECTED" ]; then
            ORIENT_INPUT="H"
        fi
    fi
    
    INPUT_CLEAN=$(echo "$ORIENT_INPUT" | tr -d ' \r\t' | tr '[:lower:]' '[:upper:]')

    if [ "$INPUT_CLEAN" = "H" ] || [ "$INPUT_CLEAN" = "V" ]; then
        ORIENT_CHOICE=$INPUT_CLEAN
    else
        log_error "Input tidak valid! Pilih H atau V."
        ARG_ORIENT=""
    fi
done

RAW_SIZE=$(wm size | awk '{print $3}')
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
        *)
            COLS=2
            ROWS=$(((COUNT + COLS - 1) / COLS))
            ;;
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
        *)
            COLS=4
            ROWS=$(((COUNT + COLS - 1) / COLS))
            ;;
    esac
fi

SW=$W; SH=$H

TOTAL_HEADERS=$((ROWS * HEADER_HEIGHT))
USABLE_GAME_H=$((SH - STATUS_BAR_HEIGHT - TOTAL_HEADERS))

GW=$((SW / COLS))
GH=$((USABLE_GAME_H / ROWS))

log_status "Mode Grid: ${MODE_NAME} ${ROWS}x${COLS} (${COUNT} Aplikasi)"

idx=0
for PKG in $SELECTED_PACKAGES; do
    PREF_DIR="/data/data/$PKG/shared_prefs"
    PREF="$PREF_DIR/${PKG}_preferences.xml"
    
    row=$((idx / COLS))
    col=$((idx % COLS))
    
    HEADER_OFFSET=$(((row + 1) * HEADER_HEIGHT))
    
    L=$((col * GW))
    T=$((STATUS_BAR_HEIGHT + (row * GH) + HEADER_OFFSET))
    R=$(((col == COLS - 1) ? SW : (L + GW)))
    B=$(((row == ROWS - 1) ? SH : (T + GH)))

    printf "${GREEN}[%d/%d]${NC} Setup Grid Layout -> %s\n" "$((idx+1))" "$COUNT" "$PKG"
    
    am force-stop "$PKG" >/dev/null 2>&1
    
    mkdir -p "$PREF_DIR" >/dev/null 2>&1
    if [ ! -f "$PREF" ]; then
        echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' > "$PREF"
        echo '<map>' >> "$PREF"
        echo '</map>' >> "$PREF"
    fi

    clean_and_inject_window_keys "$PREF" "$L" "$T" "$R" "$B"

    launch_app "$PKG"

    log_status "Jeda 5 detik..."
    sleep "$LAUNCH_DELAY"

    idx=$((idx+1))
done

echo "---------------------------------------------------"
log_success "SELESAI! ${COUNT} aplikasi terbuka di Grid ${MODE_NAME}."
