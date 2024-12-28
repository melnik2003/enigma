
#Скрипт для шифрования папки или файла
#Для работы требуются программы tar, gpg, wipe, tree
#Скрипт работает в полуавтоматическом режиме, ввод паролей происходит внутри
#интерфейса gpg


#Имя пользователя в системе
user="max"
#Имя рабочей папки
work_folder_name="archives/"
#Путь к рабочей папке
path_to_archives="/home/${user}/${work_folder_name}"
#Путь к подпапке с "сырыми" (нешифрованными) файлами
path_to_raw="${path_to_archives}raw"
#Путь к папке с временными файлами
path_to_temp="${path_to_archives}temp"
#Путь к папке с gpg архивами
path_to_encrypted="${path_to_archives}encrypted"
#Путь к папке с расшифрованными файлами
path_to_decrypted="${path_to_archives}decrypted"

#Переменные для монтирования, пока что не работают
device_name="b"
path_to_device="/dev/sd${device_name}1"
path_to_mount="/mnt/hdd1"
path_to_sync="${path_to_mount}/blob"

#Если 1, gpg архивы перетираются, если же 0, просто удаляются
#Перетирая gpg архивы вы быстрее уменьшаете ресурс вашего диска
wipe_gpg=0

#Результат выполнения программы, не менять
result=-1
#Сообщение о конкретной ошибке
specific_error=""

#Префиксы для сообщений о результатах работы
done_prefix="\e[32m[DONE]\e[0m"
warning_prefix="\e[33m[WARNING]\e[0m"
error_prefix="\e[31m[ERROR]\e[0m"

#Флаг, который используется для условий вывода результата работы и очистки папки temp
flag=0

#Переменные для связи между функциями (добавлены из-за отсутствия объектов и классов
temp1=""
temp2=""

#Функции

#ВЫход из программы
tnd14_exit() {
	case $result in
		0)
			general_error="Something went wrong"
			echo -e "${error_prefix} ${general_error}"
			if [ -n "$specific_error" ]; then
				echo -e "${error_prefix} ${specific_error}"
			fi
		;;

		1)
			echo -e "${done_prefix} Operation [\e[32m${option}\e[0m] has been completed"
			tnd14_wipe $path_to_temp
		;;
	esac
	
	exit 1
}

#Установка прав доступа на фrawайл/папку
tnd14_set_rights() {
	path_to_object="$1"

	if [ ! -d $path_to_object ] || [ ! -e $path_to_object ]; then
		specific_error="There's no such file/folder"
		return 0
	fi

	case $2 in
		"777")
			rights=$2
		;;
		"755")
			rights=$2
		;;
		"733")
			rights=$2
		;;
		"711")
			rights=$2
		;;
		"700")
			rights=$2
		;;
		*)
			rights="700"
		;;
	esac

	chown -R $user $path_to_object
	sudo chmod -R $rights $path_to_object

	return 1
}

#Создание папки
tnd14_create_folder() {
	path_to_folder="$1"
	
	if [ ! -d $path_to_folder ]; then
		mkdir $path_to_folder
		tnd14_set_rights $path_to_folder

		return 1
	else
		return 0
	fi
}

#Создание обязательных папок
tnd14_mandatory_setup() {
	tnd14_create_folder $path_to_archives
	tnd14_create_folder $path_to_raw
	tnd14_create_folder $path_to_encrypted

	return 1
}

#Создание дополнительных папок, проверка на наличие в них файлов в случае прошлого сбоя
tnd14_additional_setup() {
	tnd14_create_folder $path_to_decrypted
	if [ $? -eq 0 ]; then
		if [ ! -z "$(find $path_to_temp -mindepth 1 -print -quit)" ]; then
			specific_error="Clean \e[36mdecrypted\e[0m folder"
			result=0
			tnd14_exit
		fi	
	fi

	tnd14_create_folder $path_to_temp
	if [ $? -eq 0 ]; then
		if [ ! -z "$(find $path_to_temp -mindepth 1 -print -quit)" ]; then
			specific_error="Clean \e[36mtemp\e[0m folder"
			result=0
			tnd14_exit
		fi	
	fi
	
	return 1
}

#Функции на будущее
tnd14_replace() {
	return 0
}
tnd14_merge() {
	return 0
}

#Дебаг
tnd14_debug() {
	echo ""
	tree -CL 2 $path_to_archives
	echo ""
	if [ -e $path_to_device ]; then
		sudo mount $path_to_device $path_to_mount
		tree -CL 2 $path_to_mount
		echo ""
		sudo umount $path_to_mount
	fi

	return 1
}

tnd14_help() {
	echo ""
	echo "GENERAL"
	echo "	Use with sudo"
	echo -e "	File/folder to encrypt should be in \e[36mraw\e[0m folder"
	echo -e "	Archive to decrypt should be in \e[36mencrypted\e[0m folder"
	echo ""
	echo "OPTIONS"
	echo "	--debug					Debug"
	echo "	--help					Help"
	echo -e "	--clean					Clean \e[36mtemp\e[0m and \e[36mdecrypted\e[0m folders"
	echo "	-e [object_name] [archive_name]		Encrypt"
	echo "	-se [object_name] [archive_name]	Secure encrypt"
	echo "	-S [archive_name]			Sync external hard drive"
	echo "	-d [object_name]			Decrypt"
	echo "	-sd [object_name]			Secure decrypt"
	echo ""

	return 1
}

tnd14_wipe() {
	path_to_object="$1"
	
	if [ -d $path_to_object ] || [ -e $path_to_object ]; then
		sudo wipe -rf $path_to_object
		return 1
	else
		specific_error="There's no such file/folder"
		return 0
	fi
}

tnd14_clean() {
	tnd14_wipe $path_to_temp
	tnd14_wipe $path_to_decrypted
	mkdir $path_to_decrypted

	return 1
}

tnd14_sync() {
	return 0
}

tnd14_encrypt() {
	name="$1"
	wipe_original=$2
	overwrite=$3
	
	path_to_object="${path_to_raw}/${name}"
	
	if [ ! -d $path_to_object ] || [ ! -e $path_to_object ]; then
		specific_error="There's no such file/folder"
		return 0
	fi

	if [ "$4" = "" ]; then
		new_name="$(pwgen -N 1)"
		path_to_gpg="${path_to_encrypted}/${new_`name}"
		
		while [ -e $path_to_gpg ]
		do
			new_name="$(pwgen -N 1)"
			path_to_gpg="${path_to_encrypted}/${new_name}"
		done
	else
		new_name="$4"
		path_to_gpg="${path_to_encrypted}/${new_name}"
	
		if	[ -e $path_to_gpg ]; then
			if [ $overwrite -eq 1 ]; then
				case $wipe_gpg in
					1) 
						tnd14_wipe $path_to_gpg
					;;
					*)
						rm -f $path_to_gpg
					;;
				esac
			else
				specific_error="Choose another name"
				return 0
			fi
		fi
	fi

	path_to_gpg="${path_to_encrypted}/${new_name}"

	if [ -e $path_to_gpg ]; then
		specific_error="Choose another name"
		return 0
	fi
	
	tar_name="${name}.tar.gz"
	path_to_tar="${path_to_temp}/${tar_name}"
	
	tar -czf $path_to_tar -C $path_to_raw $name
	
	gpg -o $path_to_gpg -c --no-symkey-cache --cipher-algo AES256 $path_to_tar

	if [ ! -e $path_to_gpg ]; then
		return 0
	fi

	tnd14_set_rights $path_to_gpg

	tnd14_wipe $path_to_tar

	if [ $wipe_original -eq 1 ]; then
		tnd14_wipe $path_to_object
		
	fi
	
	temp1="$new_name"
	temp2="$path_to_gpg"

	return 1
}

#Безопасное шифрование и синхронизация с внешним диском
tnd14_seS() {
	sudo mount $path_to_device $path_to_mount
	
	if [ ! -d $path_to_sync ]; then
		tnd14_create_folder $path_to_sync
	fi

	tnd14_encrypt $1 $2 $3
	if [ $? -eq 0 ]; then
		return 0
	fi
	
	new_name=$temp1
	path_to_gpg=$temp2
	path_to_copy="${path_to_sync}/${new_name}"
	
	if [ -e $path_to_copy ]; then
		case $wipe_gpg in
			1)
				tnd14_wipe $path_to_copy
			;;
			*)
				rm -f $path_to_copy
			;;
		esac
	fi
	
	cp $path_to_gpg $path_to_sync
	
	sudo umount $path_to_mount
	
	return 1
}

#Расшифровка
tnd14_decrypt() {
	name="$1"
	wipe_original=$2
	
	path_to_gpg="${path_to_encrypted}/${name}"

	tar_name="${name}.tar.gz"
	path_to_tar="${path_to_archives}/${tar_name}"
	
	if [ ! -e $path_to_gpg ]; then
		error="There's no such archive"
		return 0
	fi
	
	tar_name="${name}.tar.gz"
	path_to_tar="${path_to_temp}/${tar_name}"
	
	gpg -o $path_to_tar -d $path_to_gpg

	if [ ! -e $path_to_tar ]; then
		return 0
	fi

	tar -xzf $path_to_tar -C $path_to_decrypted

	path_to_object="${path_to_decrypted}/${name}"

	for file in ${path_to_decrypted}/*; do
		tnd14_set_rights $file
	done
	
	tnd14_wipe $path_to_tar

	if [ $wipe_original -eq 1 ]; then
		case $wipe_gpg in
			1)
				tnd14_wipe $path_to_gpg
			;;
			*)
				rm -f $path_to_gpg
			;;
		esac
	fi
	
	return 1
}

#Безопасная расшифровка и синхронизация с внешним диском
tnd14_seS() {
	sudo mount $path_to_device $path_to_mount
	tnd14_decrypt $1 $2 $3
	if [ $? -eq 0 ]; then
		return 0
	fi
	
	new_name=$temp1
	path_to_gpg=$temp2
	path_to_copy="${path_to_sync}/${new_name}"
	
	if [ -e $path_to_gpg ]; then
		case $wipe_gpg in
			1)
				tnd14_wipe $path_to_copy
			;;
			*)
				rm -f $path_to_copy
			;;
		esac
	fi
	
	sudo umount $path_to_mount
	
	return 1
}


#ВЫбранная опция
option="$1"

#Проверка на sudo
if [ "$EUID" -ne 0 ] && [ ! "$option" = "--help" ] && [ ! "$option" = "--debug" ]; then
	specific_error="Use with sudo"
	result=0
	tnd14_exit
fi

#Проверка на кол-во опций
if [ $# -eq 0 ]; then
	specific_error="Input option"
	result=0
	tnd14_exit
fi

#Инициализация перед запуском
tnd14_mandatory_setup
tnd14_additional_setup

#Проверка опций
case $option in
	"--help")
		option="help"
		tnd14_help
		result=1
	;;
	"--debug")
		option="debug"
		tnd14_debug
		result=1
	;;
	"--clean")
		option="clean"
		tnd14_clean
		result=1
	;;
	*)		
		flag=1
	;;	
esac

if [ $result -eq -1 ]; then
	if [ $# -eq 1 ]; then
		specific_error="Input name"
		result=0
	else
		case $option in
			"-e")
				option="encrypt"
				tnd14_encrypt "$2" 0 "$3"
				result=$?
			;;
			"-se")
				option="secure encrypt"
				tnd14_encrypt "$2" 1 "$3"
				result=$?
			;;
			"-d")
				option="decrypt"
				tnd14_decrypt "$2" 0
				result=$?
			;;
			"-sd")
				option="secure decrypt"
				tnd14_decrypt "$2" 1
				result=$?
			;;
		esac

		case $option in
			"-seS")
				option="secure encrypt and sync"
				tnd14_seS "$2" 1 "$3"
				result=$?
			;;
			"-sdS")
				option="secure decrypt and sync"
				tnd14_sdS "$2" 1 "$3"
				result=$?
			;;
		esac
	fi
fi

#Перетирание временных файлов при успешном выполнении
if [ $flag -eq 1 ] && [ $result -eq 1 ]; then
	tnd14_wipe $temp
fi

if [ $result -eq -1 ]; then
	specific_error="There is no such option, see --help"
	result=0
fi

#Выход из скрипта
tnd14_exit
