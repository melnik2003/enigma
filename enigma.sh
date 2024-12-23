#!/bin/bash
# ------------------------------------------------------------------
# [Мельников М.А.] Шифровальщик Enigma
#
# Скрипт для шифрования папки или файла
# Для работы требуются утилиты tar, gzip, gpg, wipe, tree, openssl
# Скрипт работает в полуавтоматическом режиме, ввод паролей происходит 
# внутри интерфейса gpg
# Рекомендуется инициализировать рабочую директорию и работать с ней,
# чтобы сократить риски безвозвратного удаления файлов в случае ошибки
# пользователя
# Рабочая директория не предназначена для хранения файлов и все
# файлы в ней имеют риск быть удалёнными при некорректном использовании
# скрипта или ошибки в коде
# ------------------------------------------------------------------

# --- Global -------------------------------------------------------
VERSION=0.0.1
SUBJECT=$0

MAIN_DIR="$(dirname "$(realpath "$0")")/enigma"
INPUT_DIR="${MAIN_DIR}/input"
OUTPUT_DIR="${MAIN_DIR}/output"
TEMP_DIR="${MAIN_DIR}/temp"

MAIN_SUBDIRS=("input", "output", "temp")

# Default logging level (1 - errors, 2 - warnings, 3 - info, 4 - debug)
LOGGING_LEVEL=3
# ------------------------------------------------------------------

# --- Utils --------------------------------------------------------
show_help_ru() {
    echo "Использование: . ./$0.sh [-param <value>]"
    echo ""
    echo "Основные параметры:"
    echo "-I                Инициализировать рабочую директорию"
    echo "                  Используется при первом запуске"
    echo ""
    echo "-e                Зашифровать содержимое директории input в output"
    echo "                  Можно использовать вместе с -i -o -w -W -y"
    echo ""
    echo "-d                Расшифровать каждый архив директории input в output"
    echo "                  Можно использовать вместе с -i -o -w -W -y"
    echo ""
    echo "-c                Очистить рабочую директорию"
    echo "                  Использовать с -W для жёсткой чистки"
    echo ""
    echo "-h                Напечатать эту справку"
    echo "-v                Напечатать версию программы"
    echo ""
    echo "Дополнительные параметры:"
    echo "-i <path>         Указать файлы и директории для шифрования"
    echo "                  При указании нескольких путей, для каждого из них прописывать -i <путь>"
    echo "-o <dir_path>     Указать директорию вывода"
    echo "-w                Экономно удалить входные файлы"
    echo "                  При работе в рабочей директории включено по умолчанию"
    echo "                  При расшифровке архивов происходит обычное удаление, чтобы не тратить ресурсы накопителя"
    echo "-W                Жёстко удалить входные файлы"
    echo "                  При расшифровке архивов происходит безвозвратное удаление"
    echo "-y                Пропустить все предупреждения"
}

show_main_dir() {
	echo ""
	tree $MAIN_DIR
	echo ""
}

check_path() {
    path="$1"
	
	if [ -d $path ] || [ -e $path ]; then
		return 0
	else
		show_logs 1 "noPath" "$path"
	fi
}

check_dir() {
    dir_path="$1"
	
	if [ -d $dir_path ] ; then
		return 0
	else
		show_logs 1 "noDir" "$dir_path"
	fi
}

wipe_path() {
	path="$1"
	
    check_path "$path"
    sudo wipe -rf $path

    return 0
}

### I should check if this works correctly and maybe simplify it
### I also need to check if it handles special characters in paths
get_dir_elements() {
    dir_path="$1"
    check_dir "$dir_path"
    local elements
    mapfile -t elements < <(find "$dir_path" -maxdepth 1)
    echo "${elements[@]}"
}

check_error() {
    error="$1"
    obj="$2"

    case "$error" in
        "mainParam")
            msg="Choose the only one main parameter"
        ;;
        "sudo")
            msg="Use this param with sudo"
        ;;
        "name")
            msg="Choose another name"
        ;;
        "noDir")
            msg="There's no such directory: ${obj}"
        ;;
        "noFile")
            msg="There's no such file: ${obj}"
        ;;
        "noPath")
            msg="There's no such path: ${obj}"
        ;;
        *)
            msg="$error"
        ;;
    esac

    return $msg
}

# Добавить функцию выхода из скрипта и перенаправлять выход на неё
show_logs() {
    error_prefix="\e[31m[ERROR]\e[0m"
    warning_prefix="\e[33m[WARNING]\e[0m"
    info_prefix="\e[32m[INFO]\e[0m"
    debug_prefix="\e[34m[DEBUG]\e[0m"

    msg_log_lvl=$1
    msg="$2"
    obj="$3"

    case $msg_log_lvl in
        "1")
            if [ $LOGGING_LEVEL -ge $msg_log_lvl ]; then
                msg=$(check_error "$msg" "$obj")
                echo "${error_prefix} ${msg}" >&2
            fi

            exit 1
        ;;
        "2")
            if [ $LOGGING_LEVEL -ge $msg_log_lvl ]; then
                echo "${warning_prefix} ${msg}"
            fi
        ;;
        "3")
            if [ $LOGGING_LEVEL -ge $msg_log_lvl ]; then
                echo "${info_prefix} ${msg}"
            fi
        ;;
        "4")
            if [ $LOGGING_LEVEL -ge $msg_log_lvl ]; then
                echo "${debug_prefix} ${msg}"
            fi
        ;;
    esac
}
# ------------------------------------------------------------------

# --- Main functions -----------------------------------------------

### Add warning and $yes support
clean_main_dir() {
    paths=$(get_dir_elements "$MAIN_DIR")

    for path in "${paths[@]}"; do
        if [[ " ${MAIN_SUBDIRS[@]} " =~ "$path" ]]
            continue
        else
            wipe_path "$path"
        fi
    done
    
    paths=$(get_dir_elements "$INPUT_DIR")

    for path in "${paths[@]}"; do
        wipe_path "$path"
    done

    paths=$(get_dir_elements "$OUTPUT_DIR")

    for path in "${paths[@]}"; do
        wipe_path "$path"
    done

    paths=$(get_dir_elements "$TEMP_DIR")

    for path in "${paths[@]}"; do
        wipe_path "$path"
    done
}
# ------------------------------------------------------------------


# --- Params processing --------------------------------------------
if [ $# == 0 ] ; then
    show_help_ru
    exit 1;
fi

if [[ ! -d "$PATH_TO_SCRIPTS" || ! -d "$PATH_TO_LINKS" ]]; then
    show_logs 1 "checkPaths"
fi

if [ LOGGING_LEVEL -eq 4 ]; then
    show_main_dir
fi

declare -a main_params=("h" "v" "I" "e" "d" "c")

main_param=""

declare -a input_paths()
output_path="$OUTPUT_DIR"
wipe="econom"
yes=0

input_flag=0
output_flag=0
wipe_flag=0

while getopts ":hvIedcp:i:o:wW" param
do
    if [[ " ${main_params[@]} " =~ "$param" ]]; then
        if [ $main_param == "" ]; then
            main_param="$param"
        else
            show_logs 1 "mainParam"
        fi
    fi

    case "$param" in
        "h") pass ;;
        "v") pass ;;
        "I") pass ;;
        "e") pass ;;
        "d") pass ;;
        "c") pass ;;

        "i")
            check_path "$OPTARG"
            input_paths+=("$OPTARG")
            
            if [ wipe_flag -eq 0 ]; then
                wipe="none"
            fi
            input_flag=1
            ;;
        "o")
            check_path "$OPTARG"
            output_path="$OPTARG"
            output_flag=1
            ;;
        "w")
            wipe_flag=1
            wipe="econom"
            ;;
        "W")
            wipe_flag=1
            wipe="hard"
            ;;
        "y")
            yes=1
            ;;

        "?")
            show_logs 1 "Неизвестная опция $OPTARG"
            ;;
        ":")
            show_logs 1 "Ожидается аргумент для опции $OPTARG"
            ;;
        *)
            show_logs 1 "Неизвестная ошибка во время обработки опций"
            ;;
    esac
done

shift $(($OPTIND - 1))

unset wipe_flag
# -----------------------------------------------------------------

# --- Locks -------------------------------------------------------
LOCK_FILE=/tmp/$SUBJECT.lock
if [ -f "$LOCK_FILE" ]; then
    echo "Скрипт уже запущен"
    exit
fi

trap "rm -f $LOCK_FILE" EXIT
touch $LOCK_FILE
# -----------------------------------------------------------------

# --- Body --------------------------------------------------------
case "$main_param" in
    "h")
        show_help_ru
        ;;
    "v")
        echo "Версия: ${VERSION}"
        ;;
    "e")
        if [ input_flag -eq 0 ] || [ output_flag -eq 0 ]; then
            check_main_dir()
        fi
        if [ input_flag -eq 0 ]; then
            input_paths=$(get_dir_elements "$INPUT_DIR")
        fi
        if [ output_flag -eq 0 ]; then
            output_path=$OUTPUT_DIR
        fi
        encrypt_files $input_paths $output_path $wipe $yes
        ;;
    "d")
        if [ input_flag -eq 0 ] || [ output_flag -eq 0 ]; then
            check_main_dir()
        fi
        if [ input_flag -eq 0 ]; then
            input_paths=$(get_dir_elements "$INPUT_DIR")
        fi
        if [ output_flag -eq 0 ]; then
            output_path=$OUTPUT_DIR
        fi
        decrypt_files $input_paths $output_path $wipe $yes
        ;;
    "c")
        clean_main_dir $yes
esac

exit 0
# -----------------------------------------------------------------