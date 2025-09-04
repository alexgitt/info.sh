#!/bin/bash

# Скрипт для сбора информации о железе 


# Создание директории для отчетов
REPORT_DIR="/root/logs/hardware_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

echo "=== Сбор информации о железе ==="
echo "Результаты будут сохранены в: $REPORT_DIR"
echo ""

# Функция для вывода заголовка
print_header() {
    echo "================================="
    echo "$1"
    echo "================================="
    echo ""
}

# 1. Сбор информации о процессорах
print_header "СБОР ИНФОРМАЦИИ О ПРОЦЕССОРАХ"
{
    echo "=== ИНФОРМАЦИЯ О ПРОЦЕССОРАХ ==="
    echo "Дата сбора: $(date)"
    echo ""

    echo "--- Краткая информация о CPU ---"
    lscpu
    echo ""

    echo "--- Детальная информация о процессорах ---"
    cat /proc/cpuinfo
    echo ""

    echo "--- Информация о температуре CPU (если доступно) ---"
    if command -v sensors &> /dev/null; then
        sensors | grep -i core
    else
        echo "Утилита sensors не установлена"
    fi
    echo ""

    echo "--- Информация о загрузке CPU ---"
    top -bn1 | grep "Cpu(s)"
    echo ""

} > "$REPORT_DIR/cpu_info.txt"

echo "✓ Информация о процессорах сохранена в cpu_info.txt"

# 2. Сбор информации об ОЗУ
print_header "СБОР ИНФОРМАЦИИ ОБ ОПЕРАТИВНОЙ ПАМЯТИ"
{
    echo "=== ИНФОРМАЦИЯ ОБ ОПЕРАТИВНОЙ ПАМЯТИ ==="
    echo "Дата сбора: $(date)"
    echo ""

    echo "--- Общая информация о памяти ---"
    free -h
    echo ""

    echo "--- Детальная информация о памяти ---"
    cat /proc/meminfo
    echo ""

    echo "--- Информация о модулях памяти ---"
    if command -v dmidecode &> /dev/null; then
        dmidecode --type 17 | grep -E "Size|Speed|Manufacturer|Part Number|Serial Number|Locator"
    else
        echo "Утилита dmidecode не установлена или требует root права"
    fi
    echo ""

    echo "--- Информация об использовании swap ---"
    swapon --show
    echo ""

} > "$REPORT_DIR/ram_info.txt"

echo "✓ Информация об ОЗУ сохранена в ram_info.txt"

# 3. Сбор информации о видеокартах
print_header "СБОР ИНФОРМАЦИИ О ВИДЕОКАРТАХ"
{
    echo "=== ИНФОРМАЦИЯ О ВИДЕОКАРТАХ ==="
    echo "Дата сбора: $(date)"
    echo ""

    echo "--- VGA контроллеры ---"
    lspci | grep -i vga
    echo ""

    echo "--- Все графические устройства ---"
    lspci | grep -i "vga\|display\|3d"
    echo ""

    echo "--- Детальная информация о графических устройствах ---"
    lspci -v | grep -A 20 -i "vga\|display\|3d"
    echo ""

    echo "--- Информация о NVIDIA GPU (если есть) ---"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
    else
        echo "NVIDIA GPU не обнаружены или nvidia-smi не установлена"
    fi
    echo ""

} > "$REPORT_DIR/gpu_info.txt"

echo "✓ Информация о видеокартах сохранена в gpu_info.txt"

# 4. Сбор информации о жестких дисках
print_header "СБОР ИНФОРМАЦИИ О ЖЕСТКИХ ДИСКАХ"
{
    echo "=== ИНФОРМАЦИЯ О ЖЕСТКИХ ДИСКАХ ==="
    echo "Дата сбора: $(date)"
    echo ""

    echo "--- Список всех блочных устройств ---"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID
    echo ""

    echo "--- Информация о разделах ---"
    fdisk -l 2>/dev/null | grep -E "Disk /dev/|Device|Sector size"
    echo ""

    echo "--- Использование дискового пространства ---"
    df -h
    echo ""

    echo "--- Информация о SMART статусе дисков ---"
    for disk in $(lsblk -d -n -o NAME | grep -E "^sd|^nvme"); do
        echo "=== Диск /dev/$disk ==="
        if command -v smartctl &> /dev/null; then
            smartctl -i /dev/$disk 2>/dev/null | head -20
            echo ""
            smartctl -H /dev/$disk 2>/dev/null
        else
            echo "Утилита smartctl не установлена"
        fi
        echo ""
    done
    echo ""

    echo "--- Информация о ZFS пулах (если используется) ---"
    if command -v zpool &> /dev/null; then
        zpool status
        echo ""
        zpool list
    else
        echo "ZFS не установлен или не используется"
    fi
    echo ""

} > "$REPORT_DIR/storage_info.txt"

echo "✓ Информация о жестких дисках сохранена в storage_info.txt"

# 5. Сбор информации о сетевых интерфейсах
print_header "СБОР ИНФОРМАЦИИ О СЕТЕВЫХ ИНТЕРФЕЙСАХ"
{
    echo "=== ИНФОРМАЦИЯ О СЕТЕВЫХ ИНТЕРФЕЙСАХ ==="
    echo "Дата сбора: $(date)"
    echo ""

    echo "--- Список всех сетевых интерфейсов ---"
    ip link show
    echo ""

    echo "--- IP адреса интерфейсов ---"
    ip addr show
    echo ""

    echo "--- Статистика сетевых интерфейсов ---"
    cat /proc/net/dev
    echo ""

    echo "--- Информация об Ethernet контроллерах ---"
    lspci | grep -i ethernet
    echo ""

    echo "--- Детальная информация о сетевых устройствах ---"
    lspci -v | grep -A 10 -i ethernet
    echo ""

    echo "--- Скорость и дуплекс сетевых интерфейсов ---"
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        if [ -f "/sys/class/net/$iface/speed" ] && [ -f "/sys/class/net/$iface/duplex" ]; then
            speed=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "N/A")
            duplex=$(cat /sys/class/net/$iface/duplex 2>/dev/null || echo "N/A")
            echo "Интерфейс $iface: ${speed}Mb/s, ${duplex}"
        fi
    done
    echo ""

    echo "--- Состояние сетевых соединений ---"
    ss -tuln
    echo ""

} > "$REPORT_DIR/network_info.txt"

echo "✓ Информация о сетевых интерфейсах сохранена в network_info.txt"

# 6. Создание сводного отчета
print_header "СОЗДАНИЕ СВОДНОГО ОТЧЕТА"
{
    echo "=== СВОДНЫЙ ОТЧЕТ О ЖЕЛЕЗЕ ==="
    echo "Дата создания: $(date)"
    echo "Имя хоста: $(hostname)"
    echo "Операционная система: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Версия ядра: $(uname -r)"
    echo "Архитектура: $(uname -m)"
    echo "Время работы системы: $(uptime)"
    echo ""

    echo "--- КРАТКОЕ СОДЕРЖАНИЕ ---"
    echo ""

    echo "ПРОЦЕССОРЫ:"
    lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket"
    echo ""

    echo "ОПЕРАТИВНАЯ ПАМЯТЬ:"
    free -h | grep -E "Mem:|Swap:"
    echo ""

    echo "ВИДЕОКАРТЫ:"
    lspci | grep -i vga || echo "Видеокарты не обнаружены"
    echo ""

    echo "ДИСКИ:"
    lsblk | grep -E "disk|part" | head -10
    echo ""

    echo "СЕТЕВЫЕ ИНТЕРФЕЙСЫ:"
    ip link show | grep -E "^[0-9]:" | cut -d: -f2 | sed 's/^[ \t]*//'
    echo ""

    echo "--- РАСПОЛОЖЕНИЕ ДЕТАЛЬНЫХ ОТЧЕТОВ ---"
    echo "CPU: $REPORT_DIR/cpu_info.txt"
    echo "RAM: $REPORT_DIR/ram_info.txt"
    echo "GPU: $REPORT_DIR/gpu_info.txt"
    echo "Storage: $REPORT_DIR/storage_info.txt"
    echo "Network: $REPORT_DIR/network_info.txt"
    echo ""

} > "$REPORT_DIR/summary_report.txt"

echo "✓ Сводный отчет создан в summary_report.txt"

# 7. Создание скрипта для автоматического запуска
cat > "$REPORT_DIR/run_hardware_scan.sh" << 'EOF'
#!/bin/bash
# Автоматический скрипт для запуска сбора информации о железе
# Использование: ./run_hardware_scan.sh

echo "Запуск сбора информации о железе..."
bash "$(dirname "$0")/hardware_info_collector.sh"
echo "Готово! Проверьте созданные файлы отчетов."
EOF

chmod +x "$REPORT_DIR/run_hardware_scan.sh"

# Финальное сообщение
echo ""
echo "=========================================="
echo "СБОР ИНФОРМАЦИИ ЗАВЕРШЕН УСПЕШНО!"
echo "=========================================="
echo ""
echo "Все отчеты сохранены в директории: $REPORT_DIR"
echo ""
echo "Созданные файлы:"
echo "├── summary_report.txt     - Сводный отчет"
echo "├── cpu_info.txt          - Информация о процессорах"
echo "├── ram_info.txt          - Информация об ОЗУ"
echo "├── gpu_info.txt          - Информация о видеокартах"
echo "├── storage_info.txt      - Информация о дисках"
echo "├── network_info.txt      - Информация о сети"
echo "└── run_hardware_scan.sh  - Скрипт для повторного запуска"
echo ""
echo "Для просмотра сводного отчета выполните:"
echo "cat $REPORT_DIR/summary_report.txt"
echo ""
