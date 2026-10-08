#!/system/bin/sh

STATUS_BAR_HEIGHT=20
HEADER_HEIGHT=36
LAUNCH_DELAY=5

EXCLUDED_PREFIXES="android com.android. com.google.android. com.qualcomm. com.mediatek. com.sec.android. com.xiaomi. com.huawei. org.chromium."

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!]${NC} %s\n" "$1"; }

settings put global enable_freeform_support 1 >/dev/null 2>&1
settings put global force_resizable_activities 1 >/dev/null 2>&1
settings put global freeform_window_management 1 >/dev/null 2>&1
setprop persist.sys.debug.freeform_window 1 >/dev/null 2>&1
setprop persist.sys.debug.force_resizable 1 >/dev/null 2>&1

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
        [ -z "$APP_OWNER" ] && APP_OWNER=$(ls -ld "$pkg_dir" 2>/dev/null | tr -s ' ' | cut -d' ' -f3,4 | tr ' ' ':')
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

launch_app() {
    pkg_name="$1"
    monkey -p "$pkg_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

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

printf "\n${YELLOW}Ditemukan %s Aplikasi Terpasang:${NC}\n" "$TOTAL_FOUND"
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
        printf "${CYAN}Masukkan nomor aplikasi (contoh: 8,9,10,11): ${NC}"
        if [ -e /dev/tty ]; then
            if ! read -r USER_INPUT < /dev/tty; then
                printf "\n"
                log_error "Koneksi input terminal terputus. Keluar."
                exit 1
            fi
        else
            if ! read -r USER_INPUT; then
                printf "\n"
                log_error "Koneksi input terminal terputus. Keluar."
                exit 1
            fi
        fi
    fi
    
    USER_INPUT_CLEAN=$(echo "$USER_INPUT" | tr -d ' \r\t')

    if [ -z "$USER_INPUT_CLEAN" ]; then
        log_error "Input tidak boleh kosong! Masukkan nomor aplikasi (contoh: 8,9,10,11)."
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
                eval "val=\${$num_clean}"
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
        SELECTED_PACKAGES=$(echo "$TMP_SELECTION" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
    else
        log_error "Input tidak valid! Masukkan nomor aplikasi yang tersedia (contoh: 8,9,10,11)."
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
        printf "\n${YELLOW}Pilih Orientasi Layar:${NC}\n"
        printf "  [1] Horizontal (Landscape)\n"
        printf "  [2] Vertical   (Portrait)\n"
        printf "${CYAN}Masukkan pilihan [1 / 2 atau H / V]: ${NC}"
        if [ -e /dev/tty ]; then
            if ! read -r ORIENT_INPUT < /dev/tty; then
                printf "\n"
                log_error "Koneksi input terminal terputus. Keluar."
                exit 1
            fi
        else
            if ! read -r ORIENT_INPUT; then
                printf "\n"
                log_error "Koneksi input terminal terputus. Keluar."
                exit 1
            fi
        fi
    fi
    
    CLEAN_O=$(echo "$ORIENT_INPUT" | tr -d ' \r\n\t' | tr '[:lower:]' '[:upper:]')
    case "$CLEAN_O" in
        1|H|HORIZONTAL)
            ORIENT_CHOICE="H"
            ;;
        2|V|VERTICAL)
            ORIENT_CHOICE="V"
            ;;
        *)
            log_error "Input tidak valid! Pilih 1 (Horizontal) atau 2 (Vertical)."
            ARG_ORIENT=""
            ;;
    esac
done

RAW_SIZE=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -n 1)

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
        1)
            ROWS=1
            R_0=1
            ;;
        2)
            ROWS=2
            R_0=1; R_1=1
            ;;
        3)
            # Portrait 3: baris atas, tengah, dan bawah
            ROWS=3
            R_0=1; R_1=1; R_2=1
            ;;
        *)
            # Portrait >= 4: baris isi 2, jika ganjil baris terakhir isi 1 (full-width)
            ROWS=$(((COUNT + 1) / 2))
            rem=$COUNT
            r_idx=0
            while [ "$r_idx" -lt "$ROWS" ]; do
                if [ "$r_idx" -eq $((ROWS - 1)) ] && [ "$((rem % 2))" -eq 1 ]; then
                    eval "R_${r_idx}=1"
                    rem=$((rem - 1))
                else
                    eval "R_${r_idx}=2"
                    rem=$((rem - 2))
                fi
                r_idx=$((r_idx + 1))
            done
            ;;
    esac
else
    MODE_NAME="HORIZONTAL (Landscape)"
    W=$MAX_DIM
    H=$MIN_DIM

    case $COUNT in
        1)
            ROWS=1
            R_0=1
            ;;
        2)
            ROWS=1
            R_0=2
            ;;
        3)
            # Landscape 3: kiri, tengah, kanan
            ROWS=1
            R_0=3
            ;;
        4)
            # Landscape 4: atas 2, bawah 2
            ROWS=2
            R_0=2; R_1=2
            ;;
        5)
            # Landscape 5: atas 3, bawah 2
            ROWS=2
            R_0=3; R_1=2
            ;;
        6)
            ROWS=2
            R_0=3; R_1=3
            ;;
        7)
            # Landscape 7: atas 4, bawah 3
            ROWS=2
            R_0=4; R_1=3
            ;;
        8)
            ROWS=2
            R_0=4; R_1=4
            ;;
        9)
            # Landscape 9: atas 3, tengah 3, bawah 3
            ROWS=3
            R_0=3; R_1=3; R_2=3
            ;;
        10)
            ROWS=3
            R_0=4; R_1=3; R_2=3
            ;;
        11)
            ROWS=3
            R_0=4; R_1=4; R_2=3
            ;;
        12)
            ROWS=3
            R_0=4; R_1=4; R_2=4
            ;;
        *)
            ROWS=$(((COUNT + 3) / 4))
            rem=$COUNT
            r_idx=0
            while [ "$r_idx" -lt "$ROWS" ]; do
                rows_left=$((ROWS - r_idx))
                c_in_row=$(((rem + rows_left - 1) / rows_left))
                eval "R_${r_idx}=$c_in_row"
                rem=$((rem - c_in_row))
                r_idx=$((r_idx + 1))
            done
            ;;
    esac
fi

[ "$ROWS" -lt 1 ] && ROWS=1

SW=$W; SH=$H

TOTAL_HEADERS=$((ROWS * HEADER_HEIGHT))
USABLE_GAME_H=$((SH - STATUS_BAR_HEIGHT - TOTAL_HEADERS))

printf "\n"
log_status "Mode Grid: ${MODE_NAME} ${ROWS} Baris (${COUNT} Aplikasi | Resolusi: ${SW}x${SH}px | Offset Header: ${HEADER_HEIGHT}px)"
printf "---------------------------------------------------\n"

cur_row=0
cur_col=0
app_idx=1

for PKG in $SELECTED_PACKAGES; do
    eval "COLS_IN_ROW=\$R_${cur_row}"
    [ -z "$COLS_IN_ROW" ] || [ "$COLS_IN_ROW" -lt 1 ] && COLS_IN_ROW=1

    # Perhitungan X: Presisi simetris tanpa sisa atau lebar sebelah
    L=$(( cur_col * SW / COLS_IN_ROW ))
    if [ "$cur_col" -eq $((COLS_IN_ROW - 1)) ]; then
        R=$SW
    else
        R=$(( (cur_col + 1) * SW / COLS_IN_ROW ))
    fi

    # Perhitungan Y: Memperhitungkan Status Bar dan Header Offset
    HEADER_OFFSET=$(((cur_row + 1) * HEADER_HEIGHT))
    T=$(( STATUS_BAR_HEIGHT + (cur_row * USABLE_GAME_H / ROWS) + HEADER_OFFSET ))
    if [ "$cur_row" -eq $((ROWS - 1)) ]; then
        B=$SH
    else
        B=$(( STATUS_BAR_HEIGHT + ((cur_row + 1) * USABLE_GAME_H / ROWS) + HEADER_OFFSET ))
    fi

    GW=$((R - L))
    GH=$((B - T))

    printf "${GREEN}[%d/%d]${NC} Setup Grid Layout -> %s (Baris %d Kolom %d: %dx%d px -> %d,%d sampai %d,%d)\n" \
        "$app_idx" "$COUNT" "$PKG" "$((cur_row + 1))" "$((cur_col + 1))" "$GW" "$GH" "$L" "$T" "$R" "$B"

    PREF_DIR="/data/data/$PKG/shared_prefs"
    PREF="$PREF_DIR/${PKG}_preferences.xml"
    
    am force-stop "$PKG" >/dev/null 2>&1
    sleep 1
    
    clean_and_inject_window_keys "$PREF" "$L" "$T" "$R" "$B" "/data/data/$PKG"

    launch_app "$PKG"

    log_status "Menunggu $LAUNCH_DELAY detik agar aplikasi terbuka..."
    sleep "$LAUNCH_DELAY"

    TASK_ID=$(dumpsys activity activities 2>/dev/null | grep -E "TaskRecord\{.*${PKG}|${PKG}" | grep -oE '(taskId=[0-9]+|#[0-9]+|t[0-9]+)' | grep -oE '[0-9]+' | head -n 1)
    [ -z "$TASK_ID" ] && TASK_ID=$(dumpsys activity tasks 2>/dev/null | grep -E "A=[0-9]+:${PKG}|${PKG}" | grep -oE '#[0-9]+' | tr -d '#' | tail -n 1)

    if [ -n "$TASK_ID" ] && [ "$TASK_ID" != "0" ]; then
        cmd activity task resize "$TASK_ID" "$L" "$T" "$R" "$B" >/dev/null 2>&1
        am task resize "$TASK_ID" "$L" "$T" "$R" "$B" >/dev/null 2>&1
        cmd activity task focus "$TASK_ID" >/dev/null 2>&1
    fi

    cur_col=$((cur_col + 1))
    if [ "$cur_col" -ge "$COLS_IN_ROW" ]; then
        cur_col=0
        cur_row=$((cur_row + 1))
    fi
    app_idx=$((app_idx + 1))
done

echo "---------------------------------------------------"
log_success "SELESAI! ${COUNT} aplikasi terbuka di Grid ${MODE_NAME} (Android 8-10)."
