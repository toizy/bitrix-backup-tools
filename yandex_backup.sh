#!/bin/bash

set -o nounset  # Следить за неинициализированными переменными
set -o errexit  # Не давать использовать нулевой код выхода команд

# TODO Сделать проверку свободного места на Я.Диске и если его недостаточно для MAX_BACKUPS архивов, то отправить письмо на почту

# ------------------------------------------------------
# ОБЪЯВЛЕНИЯ КОНСТАНТ
# ------------------------------------------------------

# Текущая директория
readonly BASE_BACKUP_DIR=$(dirname $(readlink -e $0))

# Дата для имени лога
readonly DATE_TIME=$(date +"%Y%m%d.%H%M%S")

# Путь к файлу лога
readonly LOG_PATH="$BASE_BACKUP_DIR/.logger/"
readonly LOG_FILE="$BASE_BACKUP_DIR/.logger/$DATE_TIME.log"
# Сколько дней хранить локальные логи
readonly SCRIPT_LOGS_LIFETIME=180

# Максимальное количество хранимых на Яндекс.Диске бекапов (0 - хранить все бекапы):
readonly MAX_BACKUPS='3'

# Email для отправки на него логов. Можно вбить несколько, это массив:
# EMAIL=("first@mail.ru" "second@mail.ru" "")
readonly EMAIL=('toizy@yandex.ru')

# Токен Yandex.Disk. Используется в функциях работы с Yandex.Disk REST API (uploadFile, remove_old_backups etc.)
TOKEN=""

# Массив токенов (10 штук)
readonly TOKENS=(\
    'AQAEA7qj72ZdAAeKGdnWxqj3cUnVhpr7qNGk_ag'\
    'AQAEA7qj72vGAAeKGpx9nvHL1U3yuyHvcT-9eVo'\
    'AQAEA7qj72vMAAeKGxyzp0vx4UqWtnd0DEvBQUI'\
    'AQAEA7qj72vPAAeKHh8FwMML8kMKvnEIc8MzWsU'\
    'AQAEA7qj72vVAAeKIB0fxuD2v0axtfD8VdHrzNI'\
    'AQAEA7qj72vbAAeKIVbA80zsc0XZndCXC2d3wkc'\
    'AQAEA7qj72vfAAeKIqbHIteXQ0XDgX98k0QjsqY'\
    'AQAEA7qj72vmAAeKI-1GfZu23kvygWzafzIdFco'\
    'AQAEA7qj72voAAeKJJHlrFif4EsNp-uSsTYV8eM'\
    'AQAEA7qj72vuAAeKJXoUYuRwO0HFpgJ1ekU853s')

# Массив почтовых адресов (у нас их 10)
readonly TOKENNAMES=(\
    'arch000@toizy.ru'\
    'arch001@toizy.ru'\
    'arch002@toizy.ru'\
    'arch003@toizy.ru'\
    'arch004@toizy.ru'\
    'arch005@toizy.ru'\
    'arch006@toizy.ru'\
    'arch007@toizy.ru'\
    'arch008@toizy.ru'\
    'arch009@toizy.ru')

# ------------------------------------------------------
# Функции логирования процесса бэкапа.
# ------------------------------------------------------

# logger отдаёт принятый аргумент сразу в файл
function logger()
{
    echo "["$(date "+%Y-%m-%d %H:%M:%S")"] $1" >> "$LOG_FILE"
}

# echoLogger не только отдаёт аргумент сразу в файл,
#  но и печатает его на экране.
function echoLogger()
{
    # В скрипте используется переменная оболочки nounset,
    # чтобы следить за необъявленными переменными, поэтому
    # мы должны здесь использовать условие, т.к. если 
    # в эту функцию придёт неинициализированный аргумент,
    # то скрипт завершится с ошибкой. Для этого используем 
    # такой трюк: 
    # if [[ ${1+x} ]]; then - $1 существует и не пуст
    # if [[ ${var+x} ]]; then - $var существует и не пуста
    if [[ ${1+x} ]]; then
        echo "$1"
        echo "["$(date "+%Y-%m-%d %H:%M:%S")"] $1" >> "$LOG_FILE"
    fi
}

# ------------------------------------------------------
# Функции парсинга ответа от Яндекса и поиска ошибок.
# ------------------------------------------------------

function parseJson()
{
    local output=""
    regex="(\"$1\":[\"]?)([^\",\}]+)([\"]?)"
    [[ $2 =~ $regex ]] && output=${BASH_REMATCH[2]}
    echo $output
}

function checkError()
{
    echo $(parseJson 'error' "$1")
}

# ------------------------------------------------------
# Создать директорию на Яндекс.Диске. Если директория
# успешно создана или уже существует, вернём 'OK'.
#
# $1 - Путь к файлу на Яндекс.Диске
# ------------------------------------------------------
#function DirCreated()
#{
#    local json_out
#    local json_error
#    json_out=$(curl -s -X PUT -H "Authorization: OAuth $TOKEN" https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/$1)
#    json_error=$(checkError "$json_out")
#    if [[ $json_error != '' ]]; then
#        if [[ $json_error == 'DiskPathPointsToExistentDirectoryError' ]]; then
#            echo 'OK'
#        else
#            logger "Directory '$1' not created. Error: $json_error"
#            echo ''
#        fi
#    else
#        echo 'OK'
#    fi
#}

# ------------------------------------------------------
# Выполнить загрузку на Яндекс.Диск.
#
# $1 - Имя файла
# $2 - Путь к файлу на локальном диске
# ------------------------------------------------------
function uploadFile()
{
    local json_out
    local json_error
    local upload_url

    # Спрашиваем у Яндекса ссылку на загрузку файла
    json_out=$(curl -s -H "Authorization: OAuth $TOKEN" https://cloud-api.yandex.net:443/v1/disk/resources/upload?path=app:/$1)

    json_error=$(checkError "$json_out")
    if [[ $json_error != '' ]]; then
        logger "URL for '$1' not created. Error: $json_error"
        upload_url=''
    else
        upload_url=$(parseJson 'href' "$json_out")
    fi

    # Если ссылка получена...
    if [[ $upload_url != '' ]]
    then
        # ...загружаем
        json_out=$(curl -s -T "$2/$1" -H "Authorization: OAuth $TOKEN" $upload_url)
        
        echoLogger "Upload request result:"
        echoLogger $json_out

        json_error=$(checkError "$json_out")

        # Обработка ошибок
        if [[ $json_error != '' ]]
        then
            echoLogger "File '$1' not uploaded. Error: $json_error"
        else
            echoLogger "File '$1' uploaded to Yandex.Disk"
        fi
    else
        echoLogger "Can not get upload URL. File '$1' not uploaded."
    fi
}

# ------------------------------------------------------
# Посчитать число файлов в директории приложения.
#
#   1. Запрашивает у Яндекс.Диска список файлов в
#       директории приложения в формате json
#   2. Удаляет скобки и переносы строк
#   3. Находит grep'ом имена файлов
# ------------------------------------------------------
function get_backup_list()
{
    # Ищем в директории приложения все файлы бекапов и выводим их названия:
    curl -s -H "Authorization: OAuth $TOKEN" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/&sort=created&limit=100" | tr "{},[]" "\n" | grep "name[[:graph:]]*.zip" | cut -d: -f 2 | tr -d '"'
}

function get_backup_count()
{
    local count=$(get_backup_list | wc -l)
    # Мы делаем бэкап сразу двух сайтов, так что на 1 бекап у нас приходится 2 файла. Поэтому количество бекапов = количество файлов / 2:
    expr $count / 2
}

function remove_old_backups()
{
    local count=$(get_backup_count)
    local old_bkps=$((count - MAX_BACKUPS))
    if [ "$old_bkps" -gt "0" ];then
        logger "Deleting old backups from Yandex.Disk"
        # Цикл удаления старых бекапов:
        # Выполняем удаление первого в списке файла 2*old_bkps раз
        for i in $(eval echo {1..$((old_bkps * 2))}); do
            echoLogger "Removing old backups from Yandex.Disk"
            curl -X DELETE -s -H "Authorization: OAuth $TOKEN" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/$(get_backup_list | awk '(NR == 1)')&permanently=true"
        done
    fi
}

# ------------------------------------------------------
# СОЗДАТЬ ДИРЕКТОРИЮ ДЛЯ ЛОГОВ
# ------------------------------------------------------

mkdir -p $LOG_PATH

# Выбор токена из списка токенов
# Токен выбирается случайно командой shuf
TOKENS_LEN="${#TOKENS[@]}"
((TOKENS_LEN--))
CURRENT_TOKEN=$(shuf -i 0-$TOKENS_LEN -n 1)

echoLogger "Starting backup using account [ ${TOKENNAMES[$CURRENT_TOKEN]} ] (token ${TOKENS[$CURRENT_TOKEN]})"

TOKEN=${TOKENS[$CURRENT_TOKEN]}

# ------------------------------------------------------
# ЗАГРУЗКА СПИСКА ФАЙЛОВ, ПЕРЕДАННОГО В СКРИПТ
# ------------------------------------------------------
for i in "$@"
do
    # Имя файла без пути
    FILENAME=${i}
    FILENAME=${FILENAME##*/}

    # Путь к файлу без имени
    FILEPATH=${i}
    FILEPATH=${FILEPATH%/*}

    # Путь к файлу на Яндекс.Диске
    # Сейчас структуру каталогов на Яндес.Диске не используем, поэтому я закомментировал этот код.
#   REMOTE_FILEPATH=${i}
#   REMOTE_FILEPATH=${REMOTE_FILEPATH#$PWD/}    # Удаляю часть пути pwd
#   REMOTE_FILEPATH=${REMOTE_FILEPATH%/*}       # Удаляю имя файла
#   REMOTE_FILEPATH=${REMOTE_FILEPATH//\//_}    # Заменяю все слеши на '_'

#    DirCreated=$(createDir $REMOTE_FILEPATH)

#   if [[ $DirCreated != 'OK' ]]
#   then
#       echoLogger 'Error occured while creating folder on Yandex.Disk'
#       echoLogger 'Continue without uploading'
#   fi

    echoLogger "Uploading '$FILENAME' to Yandex.Disk"
    uploadFile $FILENAME $FILEPATH
done

remove_old_backups

echoLogger 'All done!'

# ------------------------------------------------------
# ОТПРАВКА ЛОГОВ НА ПОЧТУ
# ------------------------------------------------------

# Читаю файл лога в переменную
LOG_MESSAGE=$(< $LOG_FILE)

# Ищу и заменяю символы возврата каретки и перевода строки на \r\n
# Код оказался ненужным, но пусть остаётся тут на всякий случай.
#LOG_MESSAGE=${LOG_MESSAGE//$'\x0D'/$'\r'}
#LOG_MESSAGE=${LOG_MESSAGE//$'\x0A'/$'\n\;}
#echo "$LOG_MESSAGE"
#echo "$LOG_MESSAGE" >> $LOG_FILE

# Отправляю лог на почту
for i in "$EMAIL"
do
    echoLogger "Sending log mail to $i"
    echoLogger "$LOG_MESSAGE" | mail -s 'Yandex.Disk backup log files' -a "$LOG_FILE" "$i"
done

# Очистка каталога с логами. Оставляем логи за 3 месяца, остальные удаляем.
echoLogger "Clearing logs"
/bin/rm -rf $(ls -dt .logger/* | tail -n +$SCRIPT_LOGS_LIFETIME);