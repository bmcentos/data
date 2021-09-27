#!/bin/bash

#Objetivo: Atualização do Apache NiFi 1.13.3 to 11.14.0
#Created By Bruno Miquelin

#Contexto de script
#Arquivos de instaçao corrente: /opt/nifi

#Esse script irá baixar o pacote NiFi, adicionar no OPT, copiar arquivos necessarios para atualização, realizar backup da instalação anterior, e mover nova instalação para /opt/nifi

#Variaveis
NIFI_NEW=nifi-1.14.0
OPT_HOME=/opt
DATA=`date "+%d%m%y_%H%M%S"`
NIFI_PORT=443
NIFI_PASS="nifi"

cd $OPT_HOME

clear
echo "[+] Pausando serviço, aguarde..."
systemctl stop nifi

echo "[+] Download da nova versão $NIFI_NEW"
wget https://dlcdn.apache.org/nifi/1.14.0/nifi-1.14.0-bin.tar.gz

if [ $? -ne 0 ] ; then
        echo "[-]  Houve falha no download, saindo..."
        exit 1
fi

cd $OPT_HOME
clear
echo "[+] - Descompactando pacote..."
sleep 2
tar xvzf nifi-1.14.0-bin.tar.gz

clear
echo "[+] Criando diretorio de LIBs"
mkdir $NIFI_NEW/custom_lib/

#Caso use libs customizadas
#echo "[+] Copiando LIBs"
#rsync -av nifi/lib/ $NIFI_NEW/custom_lib/

#Adicionando pass no Flow file
echo "$NIFI_PASS"| nifi-toolkit/bin/encrypt-config.sh -f $NIFI_NEW/conf/flow.xml.gz -g $NIFI_NEW/conf/flow.xml.gz nifi -n $NIFI_NEW/conf/nifi.properties -x $NIFI_NEW/conf/nifi.properties


for i in `echo "
state-management.xml
login-identity-providers.xml
zookeeper.properties
logback.xml
bootstrap.conf
bootstrap-notification-services.xml
authorizers.xml
flow.xml.gz
cert*
*jks
nifi.properties"`; do rsync -av nifi/conf/$i $NIFI_NEW/conf/; done

#Caso use Custom libs
#echo "nifi.nar.library.directory.custom=./custom_lib" >> $NIFI_NEW/conf/nifi.properties

#Altera tempo de eleição do cluster
sed -i 's/nifi.cluster.flow.election.max.wait.time=5 mins/nifi.cluster.flow.election.max.wait.time=1 mins/g' $NIFI_NEW/conf/nifi.properties
sed -i 's/nifi.sensitive.props.key=/nifi.sensitive.props.key=$NIFI_PASS/g' $NIFI_NEW/conf/nifi.properties

echo "[+] Alterando versão do NiFi corrente"
ROLL="nifi_$DATA"
mv -v nifi/ $ROLL/
mv -v "$NIFI_NEW"/ nifi/

echo "[+] Removendo trashes dos repositorios"
#Clear trashes
rm -rf nifi/database_repository/*
rm -rf nifi/flowfile_repository/*
rm -rf nifi/content_repository/*

#Cria estrutura do Zookeeper (Caso embeeded)
mkdir -p -v nifi/state/zookeeper/
cp -v $ROLL/state/zookeeper/myid nifi/state/zookeeper/

clear
echo "[+] Reiniciando serviço... (Aguarde alguns instantes timeout = 150s)"

systemctl start nifi

#Inicia contador
count=1
#Seta flag de erro
err=0

#Aguarda 150s até o serviço NiFi subir
while [ `lsof -i :$NIFI_PORT | wc -l` -ne 2 ];
 do
        echo "Aguarde ..."
        echo "$count"
        count=$((count+1))
        sleep 1
        clear
                if [ $count -eq 150 ]; then
                  echo "[-] Erro ao subir o serviço NiFi, verifique os logs"
                  err=1
                  break
                fi
 done

echo "[+] Serviço subiu na porta $NIFI_PORT, em $count segundos"
echo "FLAG: $err"
clear

#Verifica se serviço subiu corretamente ou não.
if [ $err -ne 1 ] ; then

        echo "[+] Update Ok, confirme na WebUI"



                elif [ $err -eq 1 ] ; then
                echo "[-] Houve falha na atualização, verifique os arquivos de configuração"
                sleep 5
                echo "[+] Voltando versão anterior.."
                rm -rf nifi_ERR
                mv -fv nifi nifi_ERR
                mv -v $ROLL/ nifi/
                systemctl restart nifi

fi

