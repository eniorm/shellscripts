#!/bin/bash
# Copyright (c) 2019 eniorm
# Bourne Again Shell Script from Linux bash(1) shell
# BSD License
#
# Necessário que o compactador pigz esteja
# instalado no sistema
#

# AJUSTAR PARÂMETROS
set -x # EXIBIR NO STDOUT OS COMANDOS EXECUTADOS
set -e # ABORTAR EXECUÇÃO CASO OCORRA ALGUM ERRO
set -u # ABORTAR A EXECUÇÃO SE ENCONTRAR ALGUMA VARIÁVEL NÃO DEFINIDA
#set -n # CHECAR EXECUÇÃO, PORÉM SEM EXECUTAR OS COMANDOS

# EXECUÇÃO DE TESTE DO SCRIPT
# 0 - DESATIVADO (BACKUP NORMAL)
# 1 - ATIVADO (APENAS UMA PASTA SERÁ USADA)
TESTE=0



# DEVE SER EXECUTADO SOMENTE PELO ROOR
if [ $(whoami) != "root" ] ; then
	echo "Erro: deve ser executdo pelo root"
	exit 87 # exit-code de execução non-root 
fi

# MACROS (VARIAVEIS)
DISCO1="/mnt/hd01/shares"
DISCO2="/mnt/hd02/shares"
DIR=$(date '+%Y_%m')
date=$(date '+Dia_%d_%a_INC')
STORAGE="${DISCO2}/storage"
DESTINO="${STORAGE}/backup_samba/${DIR}/${date}"

TAR=$(which tar)
TAR_EXCLUSOES="-X /root/scripts/tar.exclude"
TAR_EXCLUSOES_MAIS="-X /root/scripts/tar.exclude.mais"

# DEFINIR O USO DO COMPACTADOR PIGZ OU GZIP
TAR_FLAGS="-I pigz -c -p -f" # USANDO O PIGZ
#TAR_FLAGS="-c -z -p -f" # FAZ USO DO GZIP NORMAL DO SISTEMA

FIND=$(which find)
FIND_FLAGS="-type f -mmin -900 -print"

LISTA="/tmp/listabkp.txt"


# DEFINIR PELO MENOS UMA PASTA PARA EXECUÇÃO DO BACKUP
SETORES="administracao "

# EM EXECUÇÃO DE TESTES, OS DEMAIS SETORES NÃO SERÃO COPIADOS
# ACRESCENTE NO FINAL UMA NOVA PASTA DE SETOR SE FOR NECESSÁRIO
if [ ${TESTE} -eq 0 ] ; then
	SETORES+="biblioteca "
	SETORES+="coordenacao "
	SETORES+="diretoria "
	SETORES+="professores "
fi

# DESMONTA O STORAGE CASO ESTEJA MONTADO POR USO ANTERIOR
if [ $( mount | grep "${STORAGE}" | wc -l ) -ne 0 ] ; then
	sync
	umount "${STORAGE}"
fi

# MONTAR O STORAGE, ABORTAR EM CASO DE ERRO
mount "${STORAGE}" || { echo "Não foi possível montar o Storage"; exit 1; } 

# CRIAR A PASTA DE DESTINO
mkdir -p "${DESTINO}" > /dev/null 2>&1

echo -e "\n\n"

# LOOP PARA COMPACTAR OS SETORES LISTADOS NA MACRO
for SETOR in ${SETORES}
do
	[ -f ${LISTA} ] && rm -f ${LISTA}
	cd "${DISCO1}"
	echo "BKP ${SETOR} - Início: $(date)"	
	${FIND} ${SETOR} ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUSOES} ${TAR_FLAGS} "${DESTINO}/${SETOR}_INC.tgz" -T "${LISTA}"
	echo "BKP ${SETOR} - Fim: $(date)"
	echo -e "\n\n"
done

# CASO A EXECUÇÃO DO SCRIPT FOR PARA TESTES, SERÁ ENCERRADO AQUI
test $TESTE -eq 1 && { echo "*** EXECUÇÃO DO TESTE ENCERRADO ***"; exit 0; }

# BACKUP - STI SEM EXCLUSÕES
[ -f ${LISTA} ] && rm -f "${LISTA}"
cd "${DISCO1}"
echo "BKP sti - Início: $(date)"
${FIND} "sti" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_FLAGS} "${DESTINO}/sti_INC.tgz" -T "${LISTA}"
echo "BKP sti - Fim: $(date)"
echo -e "\n\n"

# BACKUP - ENGENHARIA - COM MAIS EXCLUSÕES
[ -f ${LISTA} ] && rm -f "${LISTA}"
cd "${DISCO1}"
echo "BKP engenharia - Início: $(date)"
${FIND} "engenharia" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUSOES_MAIS} ${TAR_FLAGS} "${DESTINO}/engenharia_INC.tgz" -T "${LISTA}"
echo "BKP engenharia - Fim: $(date)"
echo -e "\n\n"

# BACKUP - COMUNICAÇÃO - COM MAIS EXCLUSÕES
[ -f ${LISTA} ] && rm -f "${LISTA}"
cd "${DISCO2}"
echo "BKP comunicacao - Início: $(date)"
${FIND} "comunicacao" ${FIND_FLAGS} > ${LISTA} && [ -s ${LISTA} ] && ${TAR} ${TAR_EXCLUSOES_MAIS} ${TAR_FLAGS} "${DESTINO}/comunicacao_INC.tgz" -T "${LISTA}"
echo "BKP comunicacao - Fim: $(date)"
echo -e "\n\n"

# DESMONTAR O STORAGE
sync
umount "${STORAGE}"

# FIM
exit 0
