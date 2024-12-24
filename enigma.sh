#!/bin/bash
# --- Info ---------------------------------------------------------
# [Мельников М.А.] "Enigma" encryption-decryption scrypt
#
# This is the script for secure and simple encryption operations
# It requires tar, gzip, gpg, wipe, tree, openssl
# The script works in semi-automatic mode, gpg interface handles some 
# of the actions like writing passwords
# I recommend thou to initialize the main directory using -i, it will 
# help reduce the damage thou can do to thine system if thou shallst 
# pass wrong file paths to the script
# The main directory is not supposed to store files, use it considering
# every file in it shalt be deleted sooner or later
# ------------------------------------------------------------------

# --- Notes --------------------------------------------------------
# Add main dir check on start
# Let -i recreate the script on use
# Add -i -e -d functions
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
    echo "Usage: . ./$0.sh [-param <value>]"
    echo ""
    echo "Main params:"
    echo "-I                Init the main directory"
    echo "                  Use on the first launch"
    echo ""
    echo "-e                Encrypt the contents of input to output"
    echo "                  Use with -i -o to specify input files and an output directory"
    echo "                  Use with -w -W to wipe input files and -y to skip warnings"
    echo ""
    echo "-d                Decrypt the contents of input to output"
    echo "                  Thou can use it with -i -o -w -W -y the same as -e"
    echo ""
    echo "-c                Clean the main directory"
    echo "                  Use with -W for thorough* cleaning"
    echo ""
    echo "-h                Print this help message"
    echo "-v                Print the script version"
    echo ""
    echo "Additional params:"
    echo "-i <path>         Specify a path for an input file or directory"
    echo "                  To use with several files and directories, thou shallst use it with -i <path> for each path"
    echo "-o <dir_path>     Specify the output directory"
    echo "-w                Wipe files sparingly"
    echo "                  When the archives art decrypted, normal deletion doth take place, lest drive resources be wasted."
    echo "-W                Wipe files thoroughly"
    echo "                  *Full and complete wiping of all non-output files, without any opportunity for restoration"
    echo "-y                Skip all warnings"
}

show_main_dir() {
	echo ""
	tree $MAIN_DIR
	echo ""
}

validate_path() {
    path="$1"
	
	if [ -d $path ] || [ -e $path ]; then
		return 0
	else
		show_logs 1 "noPath" "$path"
	fi
}

validate_dir() {
    dir_path="$1"
	
	if [ -d $dir_path ] ; then
		return 0
	else
		show_logs 1 "noDir" "$dir_path"
	fi
}

wipe_path() {
	path="$1"
	
    validate_path "$path"
    sudo wipe -rf $path

    return 0
}

### I should check if this works correctly and maybe simplify it
### I also need to check if it handles special characters in paths
get_dir_elements() {
    dir_path="$1"
    validate_dir "$dir_path"
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
            msg="Use with sudo"
        ;;
        "singletone")
            msg="The script is running right now. If not, delete the lock file: ${obj}"
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
                read -p "Dost thou wish to continue? (y/n): " answer

                if [ ! "$answer" == "y" ] || [ ! "$answer" == "Y" ]; then
                    show_logs 3 "Closing script..."
                    exit 0
                fi
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
clean_main_dir() {
    paths=$(get_dir_elements "$MAIN_DIR")

    if [ $YES -eq 0 ]; then
        show_logs 2 "The script shallst delete all from the main directory."
    fi

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

if [ LOGGING_LEVEL -eq 4 ]; then
    show_main_dir
fi

declare -a main_params=("h" "v" "I" "e" "d" "c")

main_param=""

declare -a INPUT_PATHS()
OUTPUT_PATH="$OUTPUT_DIR"
WIPE="none"
YES=0

input_flag=0
output_flag=0

while getopts ":hvIedcp:i:o:wWy" param
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
            validate_path "$OPTARG"
            INPUT_PATHS+=("$OPTARG")
            input_flag=1
            ;;
        "o")
            validate_path "$OPTARG"
            OUTPUT_PATH="$OPTARG"
            output_flag=1
            ;;
        "w")
            WIPE="spare"
            ;;
        "W")
            WIPE="complete"
            ;;
        "y")
            YES=1
            ;;

        "?")
            show_logs 1 "Unknown parameter $OPTARG"
            ;;
        ":")
            show_logs 1 "Need an argument for $OPTARG"
            ;;
        *)
            show_logs 1 "Uknown error while parsing parameters"
            ;;
    esac
done

shift $(($OPTIND - 1))
# -----------------------------------------------------------------

# --- Locks -------------------------------------------------------
LOCK_FILE=/tmp/$SUBJECT.lock
if [ -f "$LOCK_FILE" ]; then
    show_logs 1 "singletone" "$LOCK_FILE"
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
        echo "Version: ${VERSION}"
        ;;
    "e")
        if [ input_flag -eq 0 ] || [ output_flag -eq 0 ]; then
            check_main_dir()
        fi
        if [ input_flag -eq 0 ]; then
            INPUT_PATHS=$(get_dir_elements "$INPUT_DIR")
        fi
        if [ output_flag -eq 0 ]; then
            OUTPUT_PATH=$OUTPUT_DIR
        fi
        encrypt_files
        ;;
    "d")
        if [ input_flag -eq 0 ] || [ output_flag -eq 0 ]; then
            check_main_dir()
        fi
        if [ input_flag -eq 0 ]; then
            INPUT_PATHS=$(get_dir_elements "$INPUT_DIR")
        fi
        if [ output_flag -eq 0 ]; then
            OUTPUT_PATH=$OUTPUT_DIR
        fi
        decrypt_files
        ;;
    "c")
        clean_main_dir
        ;;
esac

exit 0
# -----------------------------------------------------------------