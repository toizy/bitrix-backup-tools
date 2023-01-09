#!/bin/bash

readonly BASE_DIR=$(dirname $(readlink -e $0))

FILENAME=("" "")

FILENAME[0]=`date +/home/vxp/backup_tools/files/nbr/nbr_%Y.%m.%d-%H.%M.%S.zip`
FILENAME[1]=`date +/home/vxp/backup_tools/files/eurasia/eurasia_%Y.%m.%d-%H.%M.%S.zip`

cd /home/bitrix/www_nbr.ru
nice -n 19 zip -9 -r  ${FILENAME[0]} . -x bitrix/backup/* -x bitrix/cache/* -x bitrix/managed_cache/* -x upload/resize_cache/*bitrix/html_pages/* -x .git/ -x .git*
/bin/rm -rf `ls -dt /home/vxp/backup_tools/files/nbr/* | tail -n +5`;

cd /home/bitrix/www_eurasia.ee
nice -n 19 zip -9 -r  ${FILENAME[1]} . -x bitrix/backup/* -x bitrix/cache/* -x bitrix/managed_cache/* -x upload/resize_cache/*bitrix/html_pages/* -x .git/ -x .git*
/bin/rm -rf `ls -dt /home/vxp/backup_tools/files/eurasia/* | tail -n +5`;

# Заливаем на Яндекс.Диск
cd $BASE_DIR
. /home/vxp/backup_tools/yandex_backup.sh ${FILENAME[0]} ${FILENAME[1]}
