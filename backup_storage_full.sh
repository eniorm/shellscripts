#!/bin/sh
# Copyright (c) 2017 eniorm
# BSD Licence
# 
# Bourne Shell Script from FreeBSD' sh(1) shell
# Refer to: https://www.freebsd.org/cgi/man.cgi?query=sh&sektion=1&manpath=freebsd-release-ports 
#
# SIMPLE SHELL SCRIPT TO BACKUP FILES FROM A DIRECTORY
# AND SEND IT TO A NFS STORAGE VOLUME. THIS SCRIPT WILL RUN
# EVERY SUNDAY (ONCE A WEEK) AND WILL CREATE A FULL BACKUP 
# FROM DEPARTMENT FOLDERS
#
# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
# 
# set -x # UNCOMMENT TO RUNNING IN DEBUG MODE
# set -n # UNCOMMENT TO SINTAX CHECK WITHOUT RUNNING
#
#

# FORCE ONLY ROOT TO RUN THE SCRIPT
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

# LOCAL FOLDERS WHERE BACKUP ARE CREATED
DIR="$(date '+%Y_%m')"
DATA="$(date '+Dia_%d_%a_FULL')"
VOLUME="/mnt/storage"
DESTINO="${VOLUME}/BKP_departamental/${DIR}/${DATA}"

# TAR COMMANDS, FLAGS AND SETTINGS
TAR=$(which tar)
TAR_EXCLUDE="-X /root/script/tar.exclude"
TAR_EXCLUDE_MAIS="-X /root/scripts/tar.exclude.mais"
TAR_FLAGS="-czpf"

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
${MOUNT} ${MOUNT_FLAGS} "${STORAGE_IP}:${STORAGE_DIR}" "${VOLUME}"
if [ $? -ne 0 ] ; then
	echo "ERRO: nao foi possivel montar o volume NFS"
	exit 1
fi

# CREATE REMOTE FOLDER IN NFS VOLUME TO STORE BACKUP FILES
mkdir -p ${DESTINO} > /dev/null 2>&1

# LOOP TO COMPRESS DEPARTMENT FOLDERS
for SETOR in ${SETORES}
do
	cd "${DISCO1}"
	echo "BKP ${SETOR} - Inicio: $(date)"
	${TAR} ${TAR_EXCLUDE} ${TAR_FLAGS} "${DESTINO}/${SETOR}.tgz" "$SETOR"
	echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/${SETOR}.tgz"
	echo "BKP ${SETOR} - Fim: $(date)"
	echo -e "\n\n"
done

# BACKUP/COMPRESS INDIVIDUAL FOLDERS (OUT OF THE LIST OF DEPARTMENTS)
# THIS DEPARTMENTS HAS INDIVIDUAL NEEDS

# STI FOLDER, COMPRESS WITHOUT ANY EXCLUSION
cd ${DISCO1}
echo "BKP STI - Inicio: $(date)"
${TAR} ${TAR_FLAGS} "${DESTINO}/sti.tgz" "sti"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/sti.tgz"
echo "BKP STI- Fim: $(date)"
echo -e "\n\n"

# OBRAS FOLDER, COMPRESS WITH MORE EXCLUSIONS
cd ${DISCO2}
echo "BKP OBRAS - Inicio: $(date)"
${TAR} ${TAR_EXCLUDE_MAIS} ${TAR_FLAGS} "${DESTINO}/obras.tgz" "obras"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/obras.tgz"
echo "BKP OBRAS- Fim: $(date)"
echo -e "\n\n"

# ASCOM FOLDER, COMPRESS WITH MORE EXCLUSIONS
cd ${DISCO2}
echo "BKP ASCOM - Inicio: $(date)"
${TAR} ${TAR_EXCLUDE_MAIS} ${TAR_FLAGS} "${DESTINO}/ascom.tgz" "ascom"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/ascom.tgz"
echo "BKP ASCOM- Fim: $(date)"
echo -e "\n\n"

# UMMOUNT NFS VOLUME
${UMOUNT} ${VOLUME}

# END
exit 0
# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
