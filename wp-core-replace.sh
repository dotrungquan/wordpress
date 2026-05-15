#!/bin/bash

# Script thay thế WordPress Core
# Tác giả: DOTRUNGQUAN.INFO
# Mô tả: Tải và thay thế WordPress core (no-content) với tính năng backup

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Hàm hiển thị thông báo
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Hàm vẽ box
print_box() {
    local text="$1"
    local color="${2:-$CYAN}"
    local width=60
    
    echo -e "${color}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${NC}"
    printf "${color}║${NC}${BOLD}%-$((width-2))s${NC}${color}║${NC}\n" " $text"
    echo -e "${color}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${NC}"
}

# Hàm vẽ header đẹp
print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${BOLD}${MAGENTA}🚀 WORDPRESS CORE REPLACEMENT TOOL 🚀${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${YELLOW}Thay thế core WordPress an toàn & nhanh chóng${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Hàm vẽ separator
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
}

# Hàm thanh tiến trình
progress_bar() {
    local duration=$1
    local width=50
    local progress=0
    local step=$((100 / duration))
    
    while [ $progress -le 100 ]; do
        local filled=$((progress * width / 100))
        local empty=$((width - filled))
        
        printf "\r${CYAN}[${NC}"
        printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
        printf "%${empty}s" | tr ' ' '░'
        printf "${CYAN}]${NC} ${BOLD}${progress}%%${NC}"
        
        progress=$((progress + step))
        sleep 0.1
    done
    
    printf "\r${CYAN}[${NC}"
    printf "${GREEN}%${width}s${NC}" | tr ' ' '█'
    printf "${CYAN}]${NC} ${BOLD}${GREEN}100%%${NC}\n"
}

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " ${CYAN}%c${NC} " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Hiển thị header
print_header

# Kiểm tra WP-CLI
echo -e "${BOLD}[1/6]${NC} Kiểm tra môi trường..."
if ! command -v wp &> /dev/null; then
    print_error "WP-CLI chưa được cài đặt"
    echo ""
    print_info "Vui lòng cài đặt WP-CLI: https://wp-cli.org/"
    exit 1
fi
print_success "WP-CLI đã cài đặt"

# Kiểm tra trong thư mục WordPress
if [ ! -f "wp-config.php" ]; then
    print_error "Không tìm thấy wp-config.php"
    echo ""
    print_warning "Vui lòng chạy script trong thư mục gốc WordPress"
    exit 1
fi
print_success "Đang ở thư mục WordPress hợp lệ"
echo ""

print_separator

# Lấy phiên bản WordPress hiện tại
echo -e "${BOLD}[2/6]${NC} Thu thập thông tin WordPress..."
echo ""

CURRENT_VERSION=$(wp core version --allow-root 2>/dev/null || echo "Unknown")

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Thông tin WordPress hiện tại${NC}                               ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Phiên bản: ${GREEN}${BOLD}${CURRENT_VERSION}${NC}                                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Thư mục: $(basename $(pwd))                                        ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Checksum core hiện tại
print_info "Đang kiểm tra checksum WordPress..."
if wp core verify-checksums --allow-root 2>/dev/null; then
    print_success "Checksum hợp lệ - Core nguyên vẹn"
else
    print_warning "Checksum không hợp lệ - Core có thể đã bị sửa đổi"
fi
echo ""

print_separator

# Lấy danh sách phiên bản WordPress từ API
echo -e "${BOLD}[3/6]${NC} Lấy danh sách phiên bản từ WordPress.org..."
echo ""

VERSIONS=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | \
    grep -oP '"version":"[0-9]+\.[0-9]+(\.[0-9]+)?"' | \
    grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' | \
    head -n 10)

if [ -z "$VERSIONS" ]; then
    print_error "Không thể lấy danh sách phiên bản từ WordPress.org"
    exit 1
fi

print_success "Đã lấy danh sách phiên bản thành công"
echo ""

print_separator

# Hiển thị danh sách phiên bản
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}Danh sách phiên bản WordPress khả dụng${NC}                   ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"

counter=1
declare -a version_array
while IFS= read -r version; do
    version_array+=("$version")
    if [ "$version" == "$CURRENT_VERSION" ]; then
        echo -e "${CYAN}║${NC}  ${CYAN}${counter}.${NC} ${BOLD}${version}${NC} ${GREEN}● (Hiện tại)${NC}                                ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC}  ${CYAN}${counter}.${NC} ${BOLD}${version}${NC}                                                ${CYAN}║${NC}"
    fi
    ((counter++))
done <<< "$VERSIONS"

echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  ${CYAN}${counter}.${NC} ${YELLOW}Nhập phiên bản tùy chỉnh${NC}                             ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Nhập phiên bản muốn cài
echo -e "${YELLOW}❯${NC} Chọn phiên bản (nhập số thứ tự 1-${counter}):"
echo -ne "${YELLOW}❯${NC} Mặc định [${GREEN}${version_array[0]}${NC}]: "
read -r user_input

# Xử lý input
CUSTOM_OPTION=$counter

if [ -z "$user_input" ]; then
    SELECTED_VERSION="${version_array[0]}"
elif [[ "$user_input" =~ ^[0-9]+$ ]]; then
    # Nếu chọn số thứ tự
    if [ "$user_input" -eq "$CUSTOM_OPTION" ]; then
        # Chọn tùy chọn nhập tùy chỉnh
        echo ""
        echo -e "${YELLOW}❯${NC} Nhập phiên bản WordPress (VD: 6.9.4, 6.8.5):"
        echo -ne "${YELLOW}❯${NC} Phiên bản: "
        read -r custom_version
        
        if [[ -z "$custom_version" ]]; then
            print_error "Bạn chưa nhập phiên bản"
            exit 1
        elif [[ ! "$custom_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            print_error "Định dạng phiên bản không hợp lệ. VD: 6.9.4"
            exit 1
        fi
        
        SELECTED_VERSION="$custom_version"
    elif [ "$user_input" -ge 1 ] && [ "$user_input" -lt "$CUSTOM_OPTION" ]; then
        SELECTED_VERSION="${version_array[$((user_input-1))]}"
    else
        print_error "Lựa chọn không hợp lệ"
        exit 1
    fi
elif [[ "$user_input" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    # Nhập trực tiếp phiên bản
    SELECTED_VERSION="$user_input"
else
    print_error "Lựa chọn không hợp lệ"
    exit 1
fi

echo ""
print_success "Đã chọn phiên bản: ${BOLD}${GREEN}${SELECTED_VERSION}${NC}"
echo ""

# Kiểm tra nếu đã là phiên bản hiện tại
if [ "$SELECTED_VERSION" == "$CURRENT_VERSION" ]; then
    print_warning "Phiên bản đã chọn giống với phiên bản hiện tại"
    echo -ne "${YELLOW}❯${NC} Bạn có chắc muốn tiếp tục? (yes/no): "
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Đã hủy thao tác"
        exit 0
    fi
fi

print_separator

# Hỏi về backup
echo ""
echo -e "${BOLD}[4/6]${NC} Backup WordPress Core..."
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}⚠  Backup WordPress Core${NC}                                  ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Bạn có muốn backup core hiện tại trước khi thay thế?      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  (Backup sẽ loại trừ wp-content)                           ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -ne "${YELLOW}❯${NC} Backup? (yes/no) [${GREEN}yes${NC}]: "
read -r backup_choice

if [ -z "$backup_choice" ] || [ "$backup_choice" == "yes" ]; then
    BACKUP_FILE="wordpress-core-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo ""
    print_info "Đang tạo backup..."
    
    # Tạo danh sách file cần backup (loại trừ wp-content)
    tar -czf "$BACKUP_FILE" \
        --exclude='wp-content' \
        --exclude='*.log' \
        --exclude='.git' \
        --exclude='node_modules' \
        *.php \
        wp-admin \
        wp-includes \
        2>/dev/null || true &
    
    tar_pid=$!
    
    # Hiển thị spinner trong khi backup
    while ps -p $tar_pid > /dev/null 2>&1; do
        for s in / - \\ \|; do
            printf "\r${CYAN}[${s}]${NC} Đang nén file..."
            sleep 0.2
        done
    done
    
    wait $tar_pid
    
    if [ -f "$BACKUP_FILE" ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        printf "\r"
        print_success "Backup thành công: ${BOLD}${BACKUP_FILE}${NC} (${BACKUP_SIZE})"
    else
        print_error "Không thể tạo backup"
        exit 1
    fi
else
    print_warning "Đã bỏ qua backup"
fi
echo ""

print_separator

# Tải WordPress no-content
echo ""
echo -e "${BOLD}[5/6]${NC} Tải và cài đặt WordPress ${SELECTED_VERSION}..."
echo ""

DOWNLOAD_URL="https://downloads.wordpress.org/release/wordpress-${SELECTED_VERSION}-no-content.zip"
ZIP_FILE="wordpress-${SELECTED_VERSION}-no-content.zip"

print_info "Đang tải từ: ${DOWNLOAD_URL}"
echo ""

# Download với thanh tiến trình
if curl -L -f -# -o "$ZIP_FILE" "$DOWNLOAD_URL" 2>&1 | while IFS= read -r line; do
    if [[ $line =~ ([0-9]+\.[0-9]+)% ]]; then
        percent="${BASH_REMATCH[1]%.*}"
        filled=$((percent * 50 / 100))
        empty=$((50 - filled))
        printf "\r${CYAN}[${NC}${GREEN}%${filled}s${NC}%${empty}s${CYAN}]${NC} ${BOLD}${percent}%%${NC}" | sed 's/ /█/g; s/ /░/g'
    fi
done; then
    printf "\r${CYAN}[${NC}${GREEN}%50s${NC}${CYAN}]${NC} ${BOLD}${GREEN}100%%${NC}\n" | sed 's/ /█/g'
    ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
    print_success "Tải thành công: ${BOLD}${ZIP_FILE}${NC} (${ZIP_SIZE})"
else
    echo ""
    print_error "Không thể tải WordPress phiên bản ${SELECTED_VERSION}"
    print_warning "URL có thể không tồn tại. Vui lòng kiểm tra phiên bản."
    exit 1
fi
echo ""

# Giải nén và thay thế
print_info "Đang giải nén và cài đặt..."
echo ""

if unzip -o -q "$ZIP_FILE"; then
    print_success "Giải nén thành công"
    
    # Di chuyển file từ thư mục wordpress/
    print_info "Đang sao chép file..."
    
    # Đếm số lượng file để hiển thị tiến trình
    total_files=$(find wordpress -type f | wc -l)
    current=0
    
    cp -rf wordpress/* . 2>/dev/null &
    cp_pid=$!
    
    # Hiển thị spinner trong khi copy
    while ps -p $cp_pid > /dev/null 2>&1; do
        for s in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do
            printf "\r${CYAN}${s}${NC} Đang sao chép core files..."
            sleep 0.1
        done
    done
    
    wait $cp_pid
    printf "\r"
    print_success "Đã sao chép tất cả file"
    
    rm -rf wordpress
    print_success "Đã dọn dẹp thư mục tạm"
else
    print_error "Không thể giải nén file"
    exit 1
fi
echo ""

# Xóa file zip
print_info "Đang xóa file tạm..."
rm -f "$ZIP_FILE"
print_success "Đã xóa ${ZIP_FILE}"
echo ""

print_separator

# Verify checksums sau khi cập nhật
echo ""
echo -e "${BOLD}[6/6]${NC} Kiểm tra tính toàn vẹn..."
echo ""
print_info "Đang verify checksums..."

if wp core verify-checksums --allow-root 2>/dev/null; then
    print_success "Checksum hợp lệ - Core đã được cài đặt chính xác"
else
    print_warning "Checksum không hợp lệ - Có thể cần kiểm tra lại"
fi
echo ""

print_separator

# Hiển thị phiên bản mới
NEW_VERSION=$(wp core version --allow-root)

# Summary Box
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}✓ CẬP NHẬT WORDPRESS CORE THÀNH CÔNG!${NC}                    ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Phiên bản cũ: ${RED}${CURRENT_VERSION}${NC}                                        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Phiên bản mới: ${BOLD}${GREEN}${NEW_VERSION}${NC}                                      ${GREEN}║${NC}"

if [ -f "$BACKUP_FILE" ]; then
    echo -e "${GREEN}║${NC}  File backup: ${CYAN}${BACKUP_FILE}${NC}     ${GREEN}║${NC}"
fi

echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Lời nhắc cuối
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}📝 Lưu ý quan trọng${NC}                                        ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  1. Kiểm tra website hoạt động bình thường                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  2. Cập nhật database nếu cần:                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}     ${BLUE}wp core update-db --allow-root${NC}                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  3. Xóa cache nếu có                                       ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
