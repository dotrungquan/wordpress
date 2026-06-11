#!/bin/bash

# ============================================================
#  WP-CLI Script: Đổi WordPress Table Prefix
#  Tác giả: Claude
# ============================================================

set -e

# ─── Màu sắc terminal ───────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Hàm tiện ích ───────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

# ─── Tạo prefix ngẫu nhiên (6 ký tự chữ thường + số + _) ───
generate_prefix() {
    echo "$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c6)_"
}

# ─── Kiểm tra prefix hợp lệ ─────────────────────────────────
validate_prefix() {
    local p="$1"
    if [[ ! "$p" =~ ^[a-zA-Z0-9_]+_$ ]]; then
        return 1
    fi
    return 0
}

# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     WP-CLI — Đổi WordPress Table Prefix      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ─── Kiểm tra wp-cli ────────────────────────────────────────
command -v wp >/dev/null 2>&1 || error "Không tìm thấy lệnh 'wp'. Vui lòng cài WP-CLI trước."

# ─── Xác định thư mục WordPress ─────────────────────────────
WP_PATH="${1:-.}"
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    error "Không tìm thấy wp-config.php tại '$WP_PATH'. Chạy script trong thư mục WordPress hoặc truyền đường dẫn làm tham số."
fi
info "Thư mục WordPress: $(realpath $WP_PATH)"

WP="wp --path=$WP_PATH --allow-root"

# ─── Đọc prefix hiện tại từ wp-config.php ───────────────────
OLD_PREFIX=$($WP config get table_prefix 2>/dev/null) || error "Không đọc được table_prefix từ wp-config.php."
info "Prefix hiện tại: ${BOLD}${OLD_PREFIX}${NC}"

# ─── Nhập prefix mới ────────────────────────────────────────
echo ""
echo -e "Nhập prefix mới (kết thúc bằng dấu ${BOLD}_${NC}, ví dụ: ${BOLD}mywp_${NC})"
echo -e "Để trống rồi bấm ${BOLD}Enter${NC} → tạo prefix ngẫu nhiên"
echo -n "Prefix mới: "
read NEW_PREFIX

if [ -z "$NEW_PREFIX" ]; then
    NEW_PREFIX=$(generate_prefix)
    warn "Prefix ngẫu nhiên được tạo: ${BOLD}${NEW_PREFIX}${NC}"
else
    # Tự thêm _ nếu người dùng quên
    [[ "$NEW_PREFIX" != *_ ]] && NEW_PREFIX="${NEW_PREFIX}_"

    if ! validate_prefix "$NEW_PREFIX"; then
        error "Prefix không hợp lệ. Chỉ dùng chữ cái, số và dấu gạch dưới, kết thúc bằng '_'."
    fi
fi

if [ "$OLD_PREFIX" = "$NEW_PREFIX" ]; then
    error "Prefix mới trùng với prefix cũ. Không có gì để đổi."
fi

echo ""
echo -e "  Prefix cũ : ${BOLD}${RED}${OLD_PREFIX}${NC}"
echo -e "  Prefix mới: ${BOLD}${GREEN}${NEW_PREFIX}${NC}"
echo ""
echo -n "Xác nhận tiến hành? [y/N]: "
read CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { info "Đã huỷ."; exit 0; }

# ════════════════════════════════════════════════════════════
# BƯỚC 1: Backup database
# ════════════════════════════════════════════════════════════
echo ""
info "Bước 1/4 — Backup database..."

BACKUP_FILE="db-backup-before-prefix-change-$(date +%Y%m%d_%H%M%S).sql"
$WP db export "$BACKUP_FILE" --add-drop-table || error "Backup thất bại."
success "Backup xong: ${BOLD}${BACKUP_FILE}${NC}"

# ════════════════════════════════════════════════════════════
# BƯỚC 2: Lấy danh sách bảng có prefix cũ
# ════════════════════════════════════════════════════════════
echo ""
info "Bước 2/4 — Lấy danh sách bảng..."

# Dùng SHOW TABLES trực tiếp từ MySQL để lấy TẤT CẢ bảng,
# kể cả bảng của plugin không được đăng ký trong $wpdb
DB_NAME=$($WP config get DB_NAME)
OLD_PREFIX_ESCAPED=$(echo "$OLD_PREFIX" | sed 's/_/\\_/g; s/%/\\%/g')

TABLES=$($WP db query "SHOW TABLES FROM \`${DB_NAME}\` LIKE '${OLD_PREFIX_ESCAPED}%';" --skip-column-names 2>/dev/null | grep -E "^${OLD_PREFIX}" || true)

if [ -z "$TABLES" ]; then
    error "Không tìm thấy bảng nào có prefix '${OLD_PREFIX}'. Kiểm tra lại database."
fi

TABLE_COUNT=$(echo "$TABLES" | wc -l | tr -d ' ')
info "Tìm thấy ${BOLD}${TABLE_COUNT}${NC} bảng:"
echo "$TABLES" | while read tbl; do echo "    - $tbl"; done

# ════════════════════════════════════════════════════════════
# BƯỚC 3: Đổi tên bảng + cập nhật dữ liệu nội bộ
# ════════════════════════════════════════════════════════════
echo ""
info "Bước 3/4 — Đổi tên bảng và cập nhật dữ liệu..."

RENAMED=0
FAILED=0

while IFS= read -r TABLE; do
    SUFFIX="${TABLE#$OLD_PREFIX}"
    NEW_TABLE="${NEW_PREFIX}${SUFFIX}"

    # Đổi tên bảng
    if $WP db query "RENAME TABLE \`${TABLE}\` TO \`${NEW_TABLE}\`;" 2>/dev/null; then
        success "  ${TABLE}  →  ${NEW_TABLE}"
        RENAMED=$((RENAMED + 1))
    else
        warn "  Không đổi được: ${TABLE}"
        FAILED=$((FAILED + 1))
    fi
done <<< "$TABLES"

# ─── Cập nhật cột meta_key trong usermeta ───────────────────
USERMETA_TABLE="${NEW_PREFIX}usermeta"
if $WP db query "SHOW TABLES LIKE '${USERMETA_TABLE}';" 2>/dev/null | grep -q "${USERMETA_TABLE}"; then
    info "Cập nhật meta_key trong ${USERMETA_TABLE}..."
    $WP db query "UPDATE \`${USERMETA_TABLE}\` SET meta_key = REPLACE(meta_key, '${OLD_PREFIX}', '${NEW_PREFIX}') WHERE meta_key LIKE '${OLD_PREFIX}%';" 2>/dev/null
    success "Đã cập nhật meta_key trong ${USERMETA_TABLE}"
fi

# ─── Cập nhật option_name trong options ─────────────────────
OPTIONS_TABLE="${NEW_PREFIX}options"
if $WP db query "SHOW TABLES LIKE '${OPTIONS_TABLE}';" 2>/dev/null | grep -q "${OPTIONS_TABLE}"; then
    info "Cập nhật option_name trong ${OPTIONS_TABLE}..."
    $WP db query "UPDATE \`${OPTIONS_TABLE}\` SET option_name = REPLACE(option_name, '${OLD_PREFIX}', '${NEW_PREFIX}') WHERE option_name LIKE '${OLD_PREFIX}%';" 2>/dev/null
    success "Đã cập nhật option_name trong ${OPTIONS_TABLE}"
fi

# ════════════════════════════════════════════════════════════
# BƯỚC 4: Cập nhật wp-config.php
# ════════════════════════════════════════════════════════════
echo ""
info "Bước 4/4 — Cập nhật wp-config.php..."
$WP config set table_prefix "$NEW_PREFIX" || error "Không cập nhật được wp-config.php."
success "Đã set table_prefix = '${NEW_PREFIX}' trong wp-config.php"

# ════════════════════════════════════════════════════════════
# KẾT QUẢ
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║               KẾT QUẢ THỰC HIỆN              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo -e "  Prefix cũ     : ${RED}${OLD_PREFIX}${NC}"
echo -e "  Prefix mới    : ${GREEN}${NEW_PREFIX}${NC}"
echo -e "  Bảng đã đổi   : ${GREEN}${RENAMED}${NC}"
[ "$FAILED" -gt 0 ] && echo -e "  Bảng lỗi      : ${RED}${FAILED}${NC}"
echo -e "  File backup    : ${YELLOW}${BACKUP_FILE}${NC}"
echo ""
success "Hoàn tất! Hãy kiểm tra lại website của bạn."
echo ""
