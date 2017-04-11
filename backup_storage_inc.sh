#!/bin/sh
# Copyright (c) 2017 eniorm
# BSD Licence
# 
# Bourne Shell Script from FreeBSD' sh(1) shell
# Refer to: https://www.freebsd.org/cgi/man.cgi?query=sh&sektion=1&manpath=freebsd-release-ports 
#
# SIMPLE SHELL SCRIPT TO BACKUP ONLY CHANGED FILES 
# IN LAST 11H, COMPRESS IT AND SEND TO A NFS STORAGE
# VOLUME. THIS SCRIPT WILL RUN EVERY DAY FROM MONDAY 
# TO FRIDAY AND WILL CREATE A INCREMENTAL BACKUP
# FROM DEPARTMENT FOLDERS
#
# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
# 
# set -x # UNCOMMENT TO RUNNING IN DEBUG MODE
# set -n # UNCOMMENT TO SINTAX CHECK WITHOUT RUNNING
#

# # FORCE ONLY ROOT TO RUN THE SCRIPT
if [ $(whoami) != "root" ] ; then
	echo "ERRO: deve ser root para continuar"
	exit 1
fi

# SOME ADJUSTS TO CORRECT CHARSET AND ACCENTS IN FILENAMES
export LANG="pt_BR.ISO8859-1"
export LC_COLLATE="pt_BR.ISO8859-1"
export LC_ALL="pt_BR.ISO8859-1"

# LIST OF DEPARTMENT FOLDERS IN DISK 1
SETORES="administracao asgov compras contabilidade controladoria convenios gabinete juridico licitacoes patrimonio prestconv rh secsaude seplan tesouraria tributos uac"

# BACKUP DESTINATION: NFS STORAGE
STORAGE_IP="STORAGE-IP"
STORAGE_DIR="/share/CACHEDEV1_DATA/Download"

# DISKS WHERE THE FILES IS
DISCO1="/arquivos/disco1"
DISCO2="/arquivos/disco2"

# LOCAL WHERE BACKUP ARE CREATED
DIR="$(date '+%Y_%m')"
DATA="$(date '+Dia_%d_%a_INC')"
VOLUME="/mnt/storage"
DESTINO="${VOLUME}/BKP_departamental/${DIR}/${DATA}"

# TAR COMMAND, FLAGS AND EXCLUSIONS
TAR=$(which tar)
TAR_EXCLUDE="-X /root/scripts/tar.exclude"
TAR_EXCLUDE_MAIS="-X /root/scripts/tar.exclude.mais"
TAR_FLAGS="-czpf"

# FIND COMMAND AND FLAGS
FIND="$(which find)"
FIND_FLAGS="-type f -ctime -11h -print"

# TEMPORARY FILE WHERE THE FILENAME LIST WILL BE SAVED
LISTA="/tmp/listabkp.txt"

# MOUNT AND UMOUNT COMMANDS, AND FLAGS TO MOUNT NFS
MOUNT=$(which mount)
UMOUNT=$(which umount)
MOUNT_FLAGS="-o rw,tcp,noatime"

# CHECK IF NFS VOLUME IS ALREADY MOUNTED, AND UMOUNT IT
if [ $( ${MOUNT} | grep "${VOLUME}" | wc -l | cut -w -f2 ) -ne 0 ] ; then
	${UMOUNT} ${VOLUME}
fi

# MOUNT NFS VOLUME, BUT IF FAIL, THIS SCRIPT CANNOT CONTINUE
# SO STOP IMMEDIATELY, WITH EXIT 1
${MOUNT} "${STORAGE_IP}:${STORAGE_DIR}" "${VOLUME}"
if [ $? -ne 0 ] ; then
	echo "ERRO: nao foi possivel montar o volume NFS"
	exit 1
fi

# CREATE REMOTE FOLDER IN NFS VOLUME TO STORE BACKUP FILES
mkdir -p ${DESTINO} > /dev/null 2>&1

# LOOP TO FIND CHANGED FILES IN LAST 11H IN DEDEPARTMENT FOLDERS
# AND COMPRESS IT. DESTINATION OF TAR FILE IS IN STORAGE VOLUME FOLDER
for SETOR in ${SETORES}
do
	[ -f ${LISTA} ] && rm -f ${LISTA}
	cd ${DISCO1}
	echo "BKP ${SETOR} - Inicio: $(date)"
	
	${FIND} ${SETOR} ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUDE} ${TAR_FLAGS} ${DESTINO}/${SETOR}_INC.tgz -T ${LISTA}

	echo "BKP ${SETOR} - Fim: $(date)"
	echo -e "\n\n"

done

# BACKUP/COMPRESS INDIVIDUAL FOLDERS (OUT OF THE LIST OF DEPARTMENTS)
# THIS DEPARTMENTS HAS INDIVIDUAL NEEDS

# STI FOLDER, COMPRESS WITHOUT ANY EXCLUSION
[ -f "${LISTA}" ] && rm -f "${LISTA}"
cd ${DISCO1}
echo "BKP STI - Inicio: $(date)"
${FIND} "sti" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_FLAGS} ${DESTINO}/sti_INC.tgz -T ${LISTA}
echo "BKP STI - Fim: $(date)"
echo -e "\n\n"

# OBRAS FOLDER, COMPRESS WITH MORE EXCLUSIONS
[ -f "${LISTA}" ] && rm -f ${LISTA}
cd ${DISCO2}
echo "BKP OBRAS - Inicio: $(date)"
${FIND} "obras" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUDE_MAIS} ${TAR_FLAGS} ${DESTINO}/obras_INC.tgz -T ${LISTA}
echo "BKP OBRAS - Fim: $(date)"
echo -e "\n\n"

# ASCOM FOLDER, COMPRESS WITH MORE EXCLUSIONS
[ -f "${LISTA}" ] && rm -f ${LISTA}
cd ${DISCO2}
echo "BKP ASCOM - Inicio: $(date)"
${FIND} "ascom" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUDE_MAIS} ${TAR_FLAGS} ${DESTINO}/ascom_INC.tgz -T ${LISTA}
echo "BKP ASCOM - Fim: $(date)"
echo -e "\n\n"

# UMMOUNT NFS VOLUME
${UMOUNT} ${VOLUME}

# END
exit 0
# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
