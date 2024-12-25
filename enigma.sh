#!/bin/bash
# --- Info ---------------------------------------------------------
# [Мельников М.А.] "Enigma" encryption-decryption scrypt
#
# This is the script for secure and simple encryption operations
# It requires tar, gzip, gpg, wipe, tree
# The script works in semi-automatic mode, gpg interface handles some 
# of the actions like writing passwords
# I recommend thou to initialize the main directory using -i, it will 
# help reduce the damage thou canst dost to thine system if thou shallst 
# pass wrong file paths to the script
# The main directory is not supposed to store files, use it considering
# every file in it shalt be deleted sooner or later
# ------------------------------------------------------------------

# --- Notes --------------------------------------------------------
# Add -e -d functions
# Add debug and info logs
# Test if get_dir_elements handles special characters in paths
# ------------------------------------------------------------------

# --- Global -------------------------------------------------------
VERSION=0.0.1
SUBJECT=$0
USERNAME=""

MAIN_DIR="$(dirname "$(realpath "$0")")/enigma"
INPUT_DIR="${MAIN_DIR}/input"
OUTPUT_DIR="${MAIN_DIR}/output"
TEMP_DIR="${MAIN_DIR}/temp"

MAIN_SUBDIRS=("input", "output", "temp")

# Global logging level (1 - errors, 2 - warnings, 3 - info, 4 - debug)
LOGGING_LEVEL=3
# ------------------------------------------------------------------

# --- Utils --------------------------------------------------------
show_help_en() {
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
    echo "                  Thou can use it with -u -i -o -w -W -y the same as -e"
    echo ""
    echo "-c                Clean the main directory"
    echo "                  Use with -W for thorough* cleaning"
    echo ""
    echo "-h                Print this help message"
    echo "-v                Print the script version"
    echo ""
    echo "Additional params:"
    echo "-u                Set the name of a user that shallst claim the ownership of an archive"
    echo "-l                Choose logging level (1 - errors, 2 - warnings, 3 - info, 4 - debug)"
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
	
	if [ -e $path ]; then
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

validate_file() {
    file_path="$1"
	
	if [ -f $dir_path ] ; then
		return 0
	else
		show_logs 1 "noFile" "$dir_path"
	fi
}

wipe_path() {
	path="$1"
	
    validate_path "$path"
    sudo wipe -rf $path

    return 0
}

get_dir_elements() {
    dir_path="$1"
    validate_dir "$dir_path"
    local elements
    mapfile -t elements < <(find "$dir_path" -maxdepth 1)
    echo "${elements[@]}"
}

main_dir_okay() {
    if [ ! -d "$MAIN_DIR" ]; then
        return 0
    fi
    if [ ! -d "$INPUT_DIR" ]; then
        return 0
    fi
    if [ ! -d "$OUTPUT_DIR" ]; then
        return 0
    fi
    if [ ! -d "$TEMP_DIR" ]; then
        return 0
    fi

    return 1
}

generate_name() {
    length=16
    cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c $length
}

check_error() {
    error="$1"
    obj="$2"

    case "$error" in
        "mainParam")
            msg="Choose the only one main parameter"
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
init_main_dir() {
    if [ ! -d "$MAIN_DIR" ]; then
        mkdir "$MAIN_DIR"
        show_logs 3 "Created ${MAIN_DIR}"
    fi
    if [ ! -d "$INPUT_DIR" ]; then
        mkdir "$INPUT_DIR"
        show_logs 3 "Created ${INPUT_DIR}"
    fi
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir "$OUTPUT_DIR"
        show_logs 3 "Created ${OUTPUT_DIR}"
    fi
    if [ ! -d "$TEMP_DIR" ]; then
        mkdir "$TEMP_DIR"
        show_logs 3 "Created ${TEMP_DIR}"
    fi

    return 0
}

clean_main_dir() {
    local paths=$(get_dir_elements "$MAIN_DIR")

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

    return 0
}

encrypt_files() {
    local new_name="$(generate_name)"
    local new_dir="${TEMP_DIR}/${new_name}"

    if [ INPUT_FLAG -eq 0 ]; then
        cp -r "${INPUT_DIR}" "${new_dir}"
    else
        mkdir "$new_dir"
        for input_element in "${INPUT_PATHS[@]}"; do
            cp "$input_element" "$new_dir" 
        done
    fi

    local path_to_tar="${new_dir}.tar.gz"
    tar -czf "$path_to_tar" "$new_dir"

    local path_to_gpg="${path_to_tar}.gpg"
    gpg -o $path_to_gpg -c --no-symkey-cache --cipher-algo AES256 $path_to_tar

    local path_to_hidden="${new_dir}.dat"
    mv $path_to_gpg $path_to_hidden

    mv -t "$OUTPUT_DIR" "$path_to_hidden"

    chown -R "$USERNAME" "$path_to_hidden"

    wipe_path $new_dir
    wipe_path $path_to_tar

    if [ ! "$WIPE" == "none" ]; then
        for input_element in "${INPUT_PATHS[@]}"; do
           wipe_path "$input_element"
        done
    fi
}
# ------------------------------------------------------------------


# --- Params processing --------------------------------------------
if [ $# == 0 ] ; then
    show_help_en
    exit 1
fi

if [ $LOGGING_LEVEL -eq 4 ]; then
    show_main_dir
fi

declare -a main_params=("h" "v" "I" "e" "d" "c")

main_param=""

declare -a INPUT_PATHS()
OUTPUT_PATH="$OUTPUT_DIR"
WIPE="none"
YES=0

INPUT_FLAG=0
OUTPUT_FLAG=0

while getopts ":hvIedcu:l:i:o:wWy" param
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

        "l")
            if [[ "$OPTARG" =~ ^-?[0-9]+$ ]]; then
                if (( OPTARG >= 1 && OPTARG <= 4 )); then
                    LOGGING_LEVEL=$OPTARG
                    continue
                fi
            fi
            show_logs 1 "Wrong argument for -l option: $OPTARG, use 1-4 instead"
            ;;
        "i")
            validate_path "$OPTARG"
            INPUT_PATHS+=("$OPTARG")
            INPUT_FLAG=1
            ;;
        "o")
            validate_dir "$OPTARG"
            OUTPUT_PATH="$OPTARG"
            OUTPUT_FLAG=1
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

if [ "$main_param" == "e" ] || [ "$main_param" == "d" ]; then
    if [ INPUT_FLAG -eq 0 ] || [ OUTPUT_FLAG -eq 0 ]; then
        if [ $(main_dir_okay) -eq 0 ] {
            show_logs 2 "Something's wrong with the main directory, the script shallst recover it."
            init_main_dir
        }
    fi
    if [ INPUT_FLAG -eq 0 ]; then
        INPUT_PATHS=$(get_dir_elements "$INPUT_DIR")
        declare -A seen_basenames

        for file_path in "${INPUT_DIR[@]}"; do
            base_name=$(basename "$file_path")
            
            if [[ -n "${seen_basenames[$base_name]}" ]]; then
                show_logs 1 "Duplicate file found with basename \"${base_name}\"."
            fi
            
            seen_basenames["$base_name"]=1
        done

        unset seen_basenames
    fi
    if [ OUTPUT_FLAG -eq 0 ]; then
        OUTPUT_PATH=$OUTPUT_DIR
    fi
fi

case "$main_param" in
    "h")
        show_help_en
        ;;
    "v")
        echo "Version: ${VERSION}"
        ;;
    "I")
        if [ "$EUID" -eq 0 ]; then
            show_logs 1 "Use without sudo"
        fi
        init_main_dir
        show_logs 3 "Everything went well, now thou canst put files inside the \"input\" directory"
        ;;
    "e")
        if [ "$EUID" -ne 0 ]; then
            show_logs 1 "Use with sudo"
        fi
        encrypt_files
        ;;
    "d")
        if [ "$EUID" -ne 0 ]; then
            show_logs 1 "Use with sudo"
        fi
        decrypt_files
        ;;
    "c")
        if [ "$EUID" -ne 0 ]; then
            show_logs 1 "Use with sudo"
        fi
        clean_main_dir
        ;;
esac

exit 0
# -----------------------------------------------------------------