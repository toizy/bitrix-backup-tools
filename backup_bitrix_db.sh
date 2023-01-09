#!/bin/bash
FILENAME=("" "")

FILENAME[0]=`date +/home/vxp/backup_tools/databases/nbr/nbr_%Y.%m.%d-%H.%M.%S.sql.zip`
FILENAME[1]=`date +/home/vxp/backup_tools/databases/eurasia/eurasia_%Y.%m.%d-%H.%M.%S.sql.zip`

mysqldump --defaults-extra-file=/home/vxp/backup_tools/mysqldump_cred.cnf nbr | zip -9 > ${FILENAME[0]}
/bin/rm -rf `ls -dt /home/vxp/backup_tools/databases/nbr/* | tail -n +20`;

mysqldump --defaults-extra-file=/home/vxp/backup_tools/mysqldump_cred.cnf eurasia | zip -9 > ${FILENAME[1]}
/bin/rm -rf `ls -dt /home/vxp/backup_tools/databases/eurasia/* | tail -n +20`;

# Заливаем на Яндекс.Диск
. /home/vxp/backup_tools/yandex_backup.sh ${FILENAME[0]} ${FILENAME[1]}
