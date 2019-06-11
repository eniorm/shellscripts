#!/bin/bash
# Copyright (c) 2019 eniorm
# Bourne Again Shell Script from Linux bash(1) shell
# BSD License
#
# Necessário que o compactador pigz esteja
# instalado no sistema
#


# EXECUÇÃO DE TESTE DO SCRIPT
# 0 - DESATIVADO (BACKUP NORMAL)
# 1 - ATIVADO (APENAS UMA PASTA SERÁ USADA)
TESTE=1


# AJUSTAR PARÂMETROS CONFORME NECESSÁRIO
# 0 - ATIVADO
# 1 - DESATIVADO
EXIBIR_COMANDOS=1			# EXIBIR NO STDOUT OS COMANDOS EXECUTADOS
ABORTAR_NOS_ERROS=1			# ABORTAR EXECUÇÃO CASO OCORRA ALGUM ERRO
ABORTAR_SE_VARIAVEIS_EM_BRANCO=1	# ABORTAR A EXECUÇÃO SE ENCONTRAR ALGUMA VARIÁVEL NÃO DEFINIDA
TESTAR_SEM_EXECUTAR=1 			# CHECAR EXECUÇÃO, PORÉM SEM EXECUTAR OS COMANDOS
EXEC_NON_ROOT=0				# PERMITIR SER EXECUTADO POR OUTRO USUÁRIO NÃO-ROOT

# QUAL COMPACTADOR DEVE SER UTILIZADO
# (CASO O PIGZ NÃO ESTEJA INSTALADO, SERÁ USADO O GZIP)
# 0 - PADRÃO (PIGZ)
# 1 - GZIP
ZIP=0



# APLICAR OS PARÂMETROS DE MUDANÇA DE COMPORTAMENTO DO BASH 
# DE ACORDO COM AS VARIÁVEIS AJUSTADAS PELO USUÁRIO
[ $EXIBIR_COMANDOS -eq 1 ] && set -x
[ $ABORTAR_NOS_ERROS -eq 1 ] && set -e
[ $ABORTAR_SE_VARIAVEIS_EM_BRANCO -eq 1 ] && set -u
[ $TESTAR_SEM_EXECUTAR -eq 1 ] && set -n

# DEVE SER EXECUTADO SOMENTE PELO ROOR
if [ $(whoami) != "root" ] ; then
	echo "Erro: deve ser executdo pelo root"
	exit 87 # exit-code de execução non-root 
fi

# MACROS (VARIAVEIS)
DISCO1="/mnt/hd01/shares"
DISCO2="/mnt/hd02/shares"
DIR=$(date '+%Y_%m')
DATA=$(date '+Dia_%d_%a_FULL')
STORAGE="/mnt/storage"
DESTINO="${STORAGE}/backup_samba/${DIR}/${DATA}"

TAR=$(which tar)
TAR_EXCLUSOES="-X /root/scripts/tar.exclude"
TAR_EXCLUSOES_MAIS="-X /root/scripts/tar.exclude.mais"

# DEFINIR O USO DO PIGZ OU GZIP CONVENCIONAL PARA COMPACTAÇÃO
# SE O PIGZ ESTIVER INSTALADO NO SISTEMA, SERÁ USADO, SENÃO, O GZIP
PIGZ=$(which pigz 2> /dev/null)
GZIP=$(which gzip)
if [[ -f ${PIGZ} && ${ZIP} -eq 0 ]] ; then
        ZIP=${PIGZ}
else
        ZIP=${GZIP}
fi
TAR_FLAGS="-I ${ZIP} -c -p -f"

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

# DESMONTA O STORAGE CASO ESTEJA EM USO
if [ $( mount | grep "${STORAGE}" | wc -l ) -ne 0 ] ; then
	sync
	umount "${STORAGE}"
fi

# MONTAR O STORAGE VIA NFS JÁ DEFINIDO EM FSTAB. ABORTAR EM CASO DE ERRO
mount "${STORAGE}" || { echo "Não foi possível montar o Storage"; exit 1; } 

# CRIAR A PASTA DE DESTINO
mkdir -p "${DESTINO}" > /dev/null 2>&1

# BACKUP DA CONFIGURAÇÃO DO SERVIDOR
${TAR} ${TAR_FLAGS} "${DESTINO}/srvsamba_conf.tgz" /root /etc

echo -e "\n\n"

# LOOP PARA COMPACTAR OS SETORES LISTADOS NA MACRO
for SETOR in ${SETORES}
do
	cd "${DISCO1}"
	echo "BKP ${SETOR} - Início: $(date)"
	${TAR} ${TAR_EXCLUSOES} ${TAR_FLAGS} "${DESTINO}/${SETOR}.tgz" "${SETOR}"
	echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/${SETOR}.tgz"
	echo "BKP ${SETOR} - Fim: $(date)"
	echo -e "\n\n"
done

# CASO A EXECUÇÃO DO SCRIPT FOR PARA TESTES, SERÁ ENCERRADO AQUI
test ${TESTE} -eq 1 && { echo "*** EXECUÇÃO DO TESTE ENCERRADO ***"; exit 0; }

# BACKUP - STI SEM EXCLUSÕES
cd "${DISCO1}"
echo "BKP sti - Início: $(date)"
${TAR} ${TAR_EXCLUSOES} ${TAR_FLAGS} "${DESTINO}/sti.tgz" "sti"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/sti.tgz"
echo "BKP sti - Fim: $(date)"
echo -e "\n\n"

# BACKUP - ENGENHARIA - COM MAIS EXCLUSÕES
cd "${DISCO1}"
echo "BKP eng - Início: $(date)"
${TAR} ${TAR_EXCLUSOES_MAIS} ${TAR_FLAGS} "${DESTINO}/engenharia.tgz" "engenharia"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/obras.tgz"
echo "BKP engenharia - Fim: $(date)"
echo -e "\n\n"

# BACKUP - COMUNICAÇÃO - COM MAIS EXCLUSÕES
cd "${DISCO2}"
echo "BKP comunicacao - Início: $(date)"
${TAR} ${TAR_EXCLUSOES_MAIS} ${TAR_FLAGS} "${DESTINO}/comunicacao.tgz" "comunicacao"
echo -n "TAMANHO DO BACKUP: "; du -hs "${DESTINO}/ascom.tgz"
echo "BKP comunicacao - Fim: $(date)"
echo -e "\n\n"

# BACKUP: EXECUTAVEIS DO SISTEMA DE E.R.P.
[ -a "${DESTINO}/sistemas_erp.7z.tar" ] && rm -f "${DESTINO}/sistemas_erp.7z.tar"
${TAR} -cf "${DESTINO}/sistemas_erp.7z.tar" "${DISCO1}/erp"

# DESMONTAR O STORAGE
umount "${STORAGE}"

# FIM
exit 0
