#!/bin/bash

# change-wp-prefix.sh
# Usage: bash change-wp-prefix.sh

set -e

ALLOW_ROOT="--allow-root"

echo "=== CHANGE WORDPRESS DATABASE PREFIX ==="

# Kiểm tra WP-CLI
if ! command -v wp >/dev/null 2>&1; then
    echo "❌ Không tìm thấy wp-cli."
    exit 1
fi

# Kiểm tra wp-config.php
if ! wp core is-installed $ALLOW_ROOT >/dev/null 2>&1; then
    echo "❌ Thư mục hiện tại không phải WordPress hoặc chưa cài đặt."
    exit 1
fi

OLD_PREFIX=$(wp config get table_prefix --type=variable $ALLOW_ROOT)

if [ -z "$OLD_PREFIX" ]; then
    echo "❌ Không lấy được prefix hiện tại."
    exit 1
fi

echo "Prefix hiện tại: $OLD_PREFIX"
echo ""

read -p "Nhập prefix mới, bỏ trống để tạo ngẫu nhiên: " NEW_PREFIX

if [ -z "$NEW_PREFIX" ]; then
    RANDOM_STR=$(tr -dc 'a-z0-9' </dev/urandom | head -c 8)
    NEW_PREFIX="${RANDOM_STR}_"
fi

# Bảo đảm có dấu _
if [[ "$NEW_PREFIX" != *_ ]]; then
    NEW_PREFIX="${NEW_PREFIX}_"
fi

# Chỉ cho phép chữ, số, _
if [[ ! "$NEW_PREFIX" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "❌ Prefix chỉ được chứa chữ, số và dấu gạch dưới."
    exit 1
fi

if [ "$OLD_PREFIX" = "$NEW_PREFIX" ]; then
    echo "❌ Prefix mới giống prefix cũ."
    exit 1
fi

echo ""
echo "Prefix mới sẽ là: $NEW_PREFIX"
read -p "Bạn chắc chắn muốn đổi? Nhập YES để tiếp tục: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Đã huỷ."
    exit 0
fi

DATE=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="backup-before-change-prefix-${DATE}.sql"

echo ""
echo "=== Backup database ==="
wp db export "$BACKUP_FILE" $ALLOW_ROOT

echo "✅ Backup xong: $BACKUP_FILE"

echo ""
echo "=== Lấy danh sách table ==="

TABLES=$(wp db tables "${OLD_PREFIX}*" $ALLOW_ROOT)

if [ -z "$TABLES" ]; then
    echo "❌ Không tìm thấy table với prefix $OLD_PREFIX"
    exit 1
fi

echo "$TABLES"

echo ""
echo "=== Đổi tên table ==="

for TABLE in $TABLES; do
    NEW_TABLE="${TABLE/#$OLD_PREFIX/$NEW_PREFIX}"

    echo "Đổi: $TABLE -> $NEW_TABLE"

    wp db query "RENAME TABLE \`$TABLE\` TO \`$NEW_TABLE\`;" $ALLOW_ROOT
done

echo ""
echo "=== Update usermeta ==="

wp db query "
UPDATE \`${NEW_PREFIX}usermeta\`
SET meta_key = REPLACE(meta_key, '${OLD_PREFIX}', '${NEW_PREFIX}')
WHERE meta_key LIKE '${OLD_PREFIX}%';
" $ALLOW_ROOT

echo ""
echo "=== Update options user_roles ==="

wp db query "
UPDATE \`${NEW_PREFIX}options\`
SET option_name = '${NEW_PREFIX}user_roles'
WHERE option_name = '${OLD_PREFIX}user_roles';
" $ALLOW_ROOT

echo ""
echo "=== Update wp-config.php ==="

wp config set table_prefix "$NEW_PREFIX" --type=variable $ALLOW_ROOT

echo ""
echo "=== Kiểm tra nhanh ==="

wp db tables "${NEW_PREFIX}*" $ALLOW_ROOT
wp user list $ALLOW_ROOT

echo ""
echo "✅ Hoàn tất đổi prefix."
echo "Prefix cũ: $OLD_PREFIX"
echo "Prefix mới: $NEW_PREFIX"
echo "File backup: $BACKUP_FILE"
