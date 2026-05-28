#!/bin/bash

# WP Domain Replace Tool
# Chạy trong thư mục cài WordPress

BACKUP_DIR="db_backup"

check_wp() {
    if ! command -v wp >/dev/null 2>&1; then
        echo "❌ Không tìm thấy wp-cli"
        exit 1
    fi

    if ! wp core is-installed --allow-root >/dev/null 2>&1; then
        echo "❌ Thư mục hiện tại không phải WordPress hoặc WP chưa cài đặt"
        exit 1
    fi
}

backup_db() {
    read -p "Bạn có muốn backup database trước không? (yes/no): " backup_choice

    if [[ "$backup_choice" == "yes" || "$backup_choice" == "y" ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"

        TIME=$(date +"%Y-%m-%d_%H-%M-%S")
        BACKUP_FILE="$BACKUP_DIR/db_backup_$TIME.sql"

        echo "⏳ Đang backup database..."
        wp db export "$BACKUP_FILE" --allow-root

        if [[ $? -eq 0 ]]; then
            chmod 600 "$BACKUP_FILE"
            echo "✅ Backup thành công: $BACKUP_FILE"
        else
            echo "❌ Backup thất bại. Dừng thao tác."
            exit 1
        fi
    else
        echo "⚠️ Bỏ qua backup database."
    fi
}

get_current_url() {
    CURRENT_URL=$(wp option get home --allow-root)

    if [[ -z "$CURRENT_URL" ]]; then
        CURRENT_URL=$(wp option get siteurl --allow-root)
    fi

    echo "$CURRENT_URL"
}

http_to_https() {
    backup_db

    CURRENT_URL=$(get_current_url)

    if [[ "$CURRENT_URL" == https://* ]]; then
        echo "⚠️ Website hiện đang dùng HTTPS rồi: $CURRENT_URL"
        exit 0
    fi

    OLD_URL="$CURRENT_URL"
    NEW_URL="${CURRENT_URL/http:\/\//https://}"

    echo "URL hiện tại : $OLD_URL"
    echo "URL mới      : $NEW_URL"

    read -p "Xác nhận chuyển HTTP sang HTTPS? (yes/no): " confirm

    if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
        wp search-replace "$OLD_URL" "$NEW_URL" --skip-columns=guid --allow-root
        wp option update home "$NEW_URL" --allow-root
        wp option update siteurl "$NEW_URL" --allow-root
        echo "✅ Đã chuyển HTTP sang HTTPS"
    else
        echo "❌ Đã hủy thao tác."
    fi
}

change_domain() {
    backup_db

    OLD_URL=$(get_current_url)

    echo "URL hiện tại trong WordPress: $OLD_URL"
    read -p "Nhập tên miền mới, ví dụ: new-domain.com hoặc https://new-domain.com: " NEW_INPUT

    if [[ -z "$NEW_INPUT" ]]; then
        echo "❌ Tên miền mới không được để trống"
        exit 1
    fi

    if [[ "$NEW_INPUT" == http://* || "$NEW_INPUT" == https://* ]]; then
        NEW_URL="$NEW_INPUT"
    else
        NEW_URL="https://$NEW_INPUT"
    fi

    echo "URL cũ : $OLD_URL"
    echo "URL mới: $NEW_URL"

    read -p "Xác nhận đổi tên miền? (yes/no): " confirm

    if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
        wp search-replace "$OLD_URL" "$NEW_URL" --skip-columns=guid --allow-root
        wp option update home "$NEW_URL" --allow-root
        wp option update siteurl "$NEW_URL" --allow-root
        echo "✅ Đã đổi tên miền thành công"
    else
        echo "❌ Đã hủy thao tác."
    fi
}

menu() {
    clear
    echo "===================================="
    echo "      WP DOMAIN REPLACE TOOL"
    echo "===================================="
    echo "1. Chuyển HTTP => HTTPS"
    echo "2. Đổi tên miền cũ sang mới"
    echo "0. Thoát"
    echo "===================================="

    read -p "Chọn chức năng: " choice

    case "$choice" in
        1)
            http_to_https
            ;;
        2)
            change_domain
            ;;
        0)
            exit 0
            ;;
        *)
            echo "❌ Lựa chọn không hợp lệ"
            ;;
    esac
}

check_wp
menu
