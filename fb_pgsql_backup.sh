#!/bin/bash
# Copyright (c) 2017 eniorm
# BSD Licence
# 
# SIMPLE BASH SHELL SCRIPT TO BACKUP DATABASES
# AND SEND IT TO A NFS STORAGE VOLUME
#
# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
# 
# 
# set -x # UNCOMMENT TO RUNNING IN DEBUG MODE
# set -n # UNCOMMENT TO SINTAX CHECK WITHOUT RUNNING
#


# LIST OF FIREBIRD DATABASES ALIASES
BANCOS_FB15="aspMateriais aspLeis"
BANCOS_FB21="aspReceitas aspCemiterio aspSequencia aspDigitalizacao"
BANCOS_FB25="aspRH aspCompras aspContabil aspPatrimonio aspFrota aspProcesso aspPrestacao"

# LIST OF PGSQL DATABASES NAMES
BANCOS_PGSQL="saude saude-log"
BANCOS_PGSQL+=" educacao educacao-log chat-educacao"
BANCOS_PGSQL+=" compras compras-log"
BANCOS_PGSQL+=" rhweb rh-log"
BANCOS_PGSQL+=" receitas"
BANCOS_PGSQL+=" social social-log"
BANCOS_PGSQL+=" jasperserver postgres"

# FOR DB AUTHENTICATION
ISC_USER="<username>"
ISC_PASS="<pwd>"
export PGPASSWORD="<pwd>"

# OUTRAS MACROS
EMAIL="somebox@someent.tld"
ARGS="-b -v -t -g -ig -mode read_write"
DIR="/somedir/backups"
DATA=$(date +%Y_%m_%d)
MES=$(date +%Y_%m)
DESTINO="${DIR}/${MES}/${DATA}"
LOG="${DESTINO}"
IDX_SQL="/root/scripts/indices_firebird.sql"
NETWORK="NET-IP/NET-BITMASK"

# TAR COMMAND AND FLAGS
TAR="$(which tar)"
TAR+=" -c -z -p -f"

# STORAGE
STORAGE_IP="STORAGE-IP"
STORAGE_DIR="/share/CACHEDEV1_DATA/Download"
VOLUME="/somedir/storage"
STORAGE_DESTINO="${VOLUME}/BKP_assessor/${MES}/${DATA}"

# MOUNT COMMAND AND FLAGS
MOUNT="$(which mount)"
UMOUNT="$(which umount)"
MOUNT_FLAGS="-t nfs -o rw,tcp,noatime"

function zerar_logs()
{
	# COMPRESS FIREBIRD FILES AND FILES
	# AND EMPTY IT

	${TAR} "${DESTINO}/firebird_logs.tgz" \ 
		/opt/firebird/firebird.log \
		/opt/firebird156/firebird.log \
		/opt/firebird214/firebird.log
	
	echo > /opt/firebird/firebird.log
	echo > /opt/firebird156/firebird.log
	echo > /opt/firebird214/firebird.log
}

function bancos_acao()
{

	# STOP ALL FIREBIRD SERVICES, USING RC SCRIPTS
	# DO A FORCED STOP WITH KILL 15 AND KILL 9 IF 
	# EXISTS ANY REMAINING PROCESS

	local RCD="/etc/init.d"
	local LOG="$(mktemp)"
	local NTS="$(which netstat)"

	sync && sleep 10

	case "$1" in
		start)
			"${RCD}/firebird156" $1
			"${RCD}/firebird214" $1
			"${RCD}/firebird255" $1
			"${RCD}/postgresql"  $1
			sleep 5
			${NTS} -ant | tee ${LOG} | egrep "3050|3053|3054" || mail -s "ERRO FIREBIRD serviços parados" ${EMAIL} < ${LOG}
		;;

		stop)
			"${RCD}/firebird156" $1
			"${RCD}/firebird214" $1
			"${RCD}/firebird255" $1
			"${RCD}/postgresql"  $1

			sleep 15
			for PID in $(pgrep "fbserver|fbguard|fb_smp_server")
			do
				kill -15 ${PID}
			done

			sleep 15
			for PID in $(pgrep "fbserver|fbguard|fb_smp_server")
			do
				kill -9 ${PID}
			done
		;;

		*)
			echo "Error"
			exit 1
		;;
	esac
}

function reiniciar_bancos()
{
	# RESTART DATABASE SERVICES
	bancos_acao "stop"
	bancos_acao "start"
}

function apenas_root()
{
	# FORCE ONLY ROOT TO RUN THE SCRIPT
	[ $(id -u) -ne "0" ] && echo "ERRO: deve ser root" && exit 1
}

function iptables_acao()
{
	# IF THIS ACTION WAS SETTLED IN BLOCK MODE, 
	# WILL DROP ALL	# ATTEMPTS FROM NETWORK TO 
	# CONNECT IN DATABASE SERVICES

	local IPT="$(which iptables)"
	case "$1" in
		block)
			${IPT} -A INPUT -p tcp -s ${NETWORK} --dport 3050 -j DROP
			${IPT} -A INPUT -p tcp -s ${NETWORK} --dport 3053 -j DROP
			${IPT} -A INPUT -p tcp -s ${NETWORK} --dport 3054 -j DROP
			${IPT} -A INPUT -p tcp -s ${NETWORK} --dport 5432 -j DROP
		;;

		allow)
			${IPT} -F
			${IPT} -Z
		;;
	esac
}

# # #
# # # BELLOW IS THE FUNCTIONS TO DO FIREBIRD BACKUPS
# # # IF GBAK RETURNS OK, THEN BACKUP FILE WILL BE COMPRESSED
# # # AND REMOVED

function backup_fb15()
{

	local GBAK="/opt/firebird156/bin/gbak"
	local GBAK_ARGS="${ARGS}"
	cd ${DESTINO}
	${GBAK} ${GBAK_ARGS} -user ${ISC_USER} -pass ${ISC_PASS} -y "${LOG}/$1.log" -se localhost/3050:service_mgr $1 "${DESTINO}/$1.fbk"
	[ $? == "0" ] && ${TAR} "$1.fbk.tgz" "$1.fbk" && rm -f "$1.fbk"
}

function backup_fb21()
{
	local GBAK="/opt/firebird214/bin/gbak"
	local GBAK_ARGS="${ARGS}"
	cd ${DESTINO}
	${GBAK} ${GBAK_ARGS} -user ${ISC_USER} -pass ${ISC_PASS} -y "${LOG}/$1.log" -se localhost/3053:service_mgr $1 "${DESTINO}/$1.fk2"
	[ $? == "0" ] && ${TAR} "$1.fk2.tgz" "$1.fk2" && rm -f "$1.fk2"	
}

function backup_fb25()
{
	local GBAK="/opt/firebird/bin/gbak"
	local GBAK_ARGS="${ARGS}"
	cd ${DESTINO}
	${GBAK} ${GBAK_ARGS} -user ${ISC_USER} -pass ${ISC_PASS} -y "${LOG}/$1.log" -se localhost/3054:service_mgr $1 "${DESTINO}/$1.fk2"
	[ $? == "0" ] && ${TAR} "$1.fk2.tgz" "$1.fk2" && rm -f "$1.fk2"	
}

# # #
# # # BELLOW IS THE FUNCTIONS TO DO A SWEEP IN FIREBIRD DATABASES
# # #

function sweep_fb15()
{
	local BIN="/opt/firebird156/bin/gfix"
	local SWEEP_LOG="$(mktemp)"
	cd ${DESTINO}
	${BIN} -sweep -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3050:$1" 2> ${SWEEP_LOG} || mail -s "Erro Gfix: $1" ${EMAIL} < ${SWEEP_LOG}
	rm -f ${SWEEP_LOG}
}

function sweep_fb21()
{
	local BIN="/opt/firebird214/bin/gfix"
	local SWEEP_LOG="$(mktemp)"
	cd ${DESTINO}
	${BIN} -sweep -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3053:$1" 2> ${SWEEP_LOG} || mail -s "Erro Gfix: $1" ${EMAIL} < ${SWEEP_LOG}
	rm -f ${SWEEP_LOG}
}

function sweep_fb25()
{
	local BIN="/opt/firebird/bin/gfix"
	local SWEEP_LOG="$(mktemp)"
	cd ${DESTINO}
	${BIN} -sweep -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3054:$1" 2> ${SWEEP_LOG} || mail -s "Erro Gfix: $1" ${EMAIL} < ${SWEEP_LOG}
	rm -f ${SWEEP_LOG}
}

# # #
# # # BELLOW IS THE FUNCTIONS TO RUN A SQL SCRIPT TO MAINTAIN FIREBIRD INDEXES TO DATABASES
# # #

function manut_index_fb15()
{
	local BIN="/opt/firebird156/bin/isql"
	local IDX_LOG=$(mktemp)
	cd ${DESTINO}
	${BIN} -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3050:$1" -i ${IDX_SQL} 2> ${IDX_LOG} || mail -s "Erro script: $1" ${EMAIL} < ${IDX_LOG}
	rm -f ${IDX_LOG}	
}

function manut_index_fb21()
{
	local BIN="/opt/firebird214/bin/isql"
	local IDX_LOG=$(mktemp)
	cd ${DESTINO}
	${BIN} -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3053:$1" -i ${IDX_SQL} 2> ${IDX_LOG} || mail -s "Erro script: $1" ${EMAIL} < ${IDX_LOG}
	rm -f ${IDX_LOG}
}

function manut_index_fb25()
{
	local BIN="/opt/firebird/bin/isql"
	local IDX_LOG=$(mktemp)
	cd ${DESTINO}
	${BIN} -user ${ISC_USER} -pass ${ISC_PASS} "localhost/3054:$1" -i ${IDX_SQL} 2> ${IDX_LOG} || mail -s "Erro script: $1" ${EMAIL} < ${IDX_LOG}
	rm -f ${IDX_LOG}
}

# # #
# # # BELLOW IS THE FUNCTIONS TO DO A MAINTENANCE IN FIREBIRD DATABASES 
# # # USE THIS WITH CARE
# # #

function gfix_fb15()
{
	local GFIX="/opt/firebird156/bin/gfix"
	local LOG="$(mktemp)"
	${GFIX} -user ${ISC_USER} -pass ${ISC_PASS} -validate -full localhost/3050:$1 > ${LOG} 2>&1
	[ -s ${LOG} ] && mail -s "GFIX erro $1 ${DATA}" ${EMAIL} < ${LOG}
	rm -f ${LOG}
}

function gfix_fb21()
{
	local GFIX="/opt/firebird214/bin/gfix"
	local LOG="$(mktemp)"
	${GFIX} -user ${ISC_USER} -pass ${ISC_PASS} -validate -full localhost/3053:$1 > ${LOG} 2>&1
	[ -s ${LOG} ] && mail -s "GFIX erro $1 ${DATA}" ${EMAIL} < ${LOG}
	rm -f ${LOG}
}

function gfix_fb25()
{
	local GFIX="/opt/firebird/bin/gfix"
	local LOG="$(mktemp)"
	${GFIX} -user ${ISC_USER} -pass ${ISC_PASS} -validate -full localhost/3054:$1 > ${LOG} 2>&1
	[ -s ${LOG} ] && mail -s "GFIX erro $1 ${DATA}" ${EMAIL} < ${LOG}
	rm -f ${LOG}
}

# # #
# # # CONTINUING...
# # #

function backup_pgsql()
{
	# CREATE A DUMP FILE FROM PGSQL DATABASE
	# IF RETURNS OK, THEN COMPRESS THE DUMP FILE

	local PGDUMP="/opt/pgsql_8_4/bin/pg_dump -b -h localhost -U assessorpublico -f"
	local PG_LOG="$(mktemp)"

	${PGDUMP} "${DESTINO}/pg_$1.dump" $1 2> ${PG_LOG} || mail -s "Erro PGSQL: $1" ${EMAIL} < ${PG_LOG}
	[ -s "${DESTINO}/pg_$1.dump" ] && ${TAR} "${DESTINO}/pg_$1.dump.tgz" "${DESTINO}/pg_$1.dump" && rm -f "${DESTINO}/pg_$1.dump"
	rm -f ${PG_LOG}
}

function email_logs()
{
	# GET LAST LINE FROM FIREBIRD GBAK LOGS AND SEND TO EMAIL
	tail -n1 ${DESTINO}/*.log | mail -s "GBAK relatorio $DATA" ${EMAIL}
}

function excluir_bkps_antigos()
{
	# WILL REMOVE OLD BACKUP FILES FROM 3 LAST DAYS
	cd ${DIR}
	find ${DIR} -type f -ctime +3d -exec rm -f {} \;
	find ${DIR} -type f -atime +3d -exec rm -f {} \;
}

function montar_desmontar_nfs()
{
	# FUNCTION TO MOUNT AND UMOUNT A NFS VOLUME FROM STORAGE

	case "$1" in
		"montar")
			${MOUNT} ${MOUNT_FLAGS} ${STORAGE_IP}:${STORAGE_DIR} ${VOLUME}
			if [ $? -ne 0 ] ; then
				echo "ERRO: nao foi possivel montar o volume NFS"
				exit 1
			fi
		;;

		"desmontar")
			if [ $( ${MOUNT} | grep "${VOLUME}" | wc -l ) -ne 0 ] ; then
				sync
				${UMOUNT} ${VOLUME}
			fi
		;;
	esac
}

function enviar_backups_storage()
{
	# TO SEND BACKUP FILES TO STORAGE
	#

	# IF NFS IS MOUNTED, UMOUNT THEN FIRST
	montar_desmontar_nfs "desmontar"
	
	# MOUNT THE NFS VOLUME
	montar_desmontar_nfs "montar"

	# CREATE A SERVER CONFIG BACKUP
	${TAR} ${DESTINO}/dbserver_conf.tgz /etc /root/scripts

	mkdir -p ${STORAGE_DESTINO} 2> /dev/null

	# LOOP FOR COPY ALL FILES FROM LOCAL TO STORAGE VOLUME 
	# IF NECESSARY, REMOVE BACKUPS FROM LOCAL

	cd ${DESTINO}
	for ARQUIVO in *;
	do
		cp "${DESTINO}/${ARQUIVO}" "${STORAGE_DESTINO}/"
		# [ $? == 0 ] && rm -f "${ARQUIVO}" # UNCOMMENT TO REMOVE BACKUPS FROM LOCAL
	done
}


# # # 
# # # THE EXEC OF SCRIPT STARTS BELLOW
# # # 


# 0) CHECK IF IS ROOT
apenas_root;

# 1) CREATE A LOCAL FOLDER DO SEND BACKUP FILES
mkdir -p ${DESTINO} 2> /dev/null

# 2) REMOVE OLD BACKUP FILES
excluir_bkps_antigos;

# 3) STOP DATABASE SERVICES
bancos_acao "stop";

# 4) EMPTY THE LOGS
zerar_logs;

# 5) DROP CONNECTIONS
iptables_acao "block";

# 6) START DATABASE SERVICES
bancos_acao "start";

# 7) START OF FIREBIRD 1.5 BACKUP SERVICES ON EARCH DATABASE
for BANCO in ${BANCOS_FB15}
do
	backup_fb15 ${BANCO}
	sweep_fb15 ${BANCO}
	gfix_fb15 $BANCO
	manut_index_fb15 ${BANCO}
done
unset ${BANCO}

# 8) START OF FIREBIRD 2.1 BACKUP SERVICES ON EARCH DATABASE
for BANCO in ${BANCOS_FB21}
do
	backup_fb21 ${BANCO}
	sweep_fb21 ${BANCO}
	gfix_fb21 ${BANCO}
	manut_index_fb21 ${BANCO}
done
unset ${BANCO} 

# 9) START OF FIREBIRD 2.5 BACKUP SERVICES ON EARCH DATABASE
for BANCO in ${BANCOS_FB25}
do
	backup_fb25 ${BANCO}
	sweep_fb25 ${BANCO}
	gfix_fb25 ${BANCO}
	manut_index_fb25 ${BANCO}
done
unset ${BANCO}

# 10) START OF PGSQL BACKUP SERVICES ON EARCH DATABASE
for BANCO in ${BANCOS_PGSQL}
do
	backup_pgsql ${BANCO}
done
unset ${BANCO}

# 11) SEND ALL LOGS TO EMAIL
email_logs;

# 12) SEND BACKUP FILES TO STORAGE
enviar_backups_storage;

# 13) UMOUNT NFS VOLUME
montar_desmontar_nfs "desmontar";

# 14) RESTART DATABASE SERVICES
reiniciar_bancos;

# 15) EMPTY IPTABLES RULES TO ALLOW CONNECTIONS AGAIN
iptables_acao "allow";

# END
exit 0

# ALL SUGGESTIONS, COMMENTS AND IMPROVEMENTS ARE WELCOME
