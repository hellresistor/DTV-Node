#!/bin/bash
#--------------------------#
#      Fulcrum V0.3.0      #
#--------------------------#
. variaveis
. funcbasic

function FulcrumZone(){
 clear
 . banner/FULCRUM
 CheckInstalarPacotes "libssl-dev" "bc"
 DetectarCriarUtilizadores "${DEFAULT_FULCRUM_USER}"
 sudo adduser "${DEFAULT_FULCRUM_USER}" "${DEFAULT_BITCOIN_GROUP}"
 if [ ! -d "$PASTAFULCRUM" ]; then
  info "A pasta ${PASTAFULCRUM} nao existe. Criando..."
  sudo mkdir "$PASTAFULCRUM" || erro "Pasta ${PASTAFULCRUM} não criada!"
 else
  aviso "O diretório ${PASTAFULCRUM} já existe."
 fi
 sudo chown -R "$DEFAULT_FULCRUM_USER":"$DEFAULT_FULCRUM_GROUP" "$PASTAFULCRUM"
  sudo ufw allow "${DEFAULT_FULCRUMSSL_PORT}"/tcp comment 'allow Fulcrum SSL' || aviso "Nao foi possivel adicionar porta 50002 na firewall"
 sudo ufw allow "${DEFAULT_FULCRUMTCP_PORT}"/tcp comment 'allow Fulcrum TCP' || aviso "Nao foi possivel adicionar porta 50001 na firewall"
 sudo sed -i "/# Connections/a zmqpubhashblock=tcp://127.0.0.1:${DEFAULT_FULCRUMZMQPUBHASHBLOCK_PORT}" "$PASTABITCOIN/bitcoin.conf"
 sudo sed -i "/# Connections/a zmqpubhashtx=tcp://127.0.0.1:${DEFAULT_FULCRUMZMQPUBHASHTX_PORT}" "$PASTABITCOIN/bitcoin.conf"
 ReiniciarServico "bitcoind"
 sleep 10 
 SistemaSincronizacao "bitcoind"
 ok "Sincronizacao terminada!"
 sleep 5
 cd "$THISTEMPFOLDER"

## Verificar a arquitectura ##
 case "$(uname -m)" in
  aarch64) ESTEARCH="arm64" ;;
  x86_64|amd64) ESTEARCH="x86_64" ;;
  *) erro "Arquitectura $(uname -m) NAO SUPORTADA" ;;
 esac
 #FULCRUMVERSAO="1.12.0"
 FULCRUMVERSAO=$(curl --silent "https://api.github.com/repos/cculianu/Fulcrum/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')
 wget "https://github.com/cculianu/Fulcrum/releases/download/v$FULCRUMVERSAO/Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux.tar.gz"
 wget "https://github.com/cculianu/Fulcrum/releases/download/v$FULCRUMVERSAO/Fulcrum-$FULCRUMVERSAO-shasums.txt.asc"
 wget "https://github.com/cculianu/Fulcrum/releases/download/v$FULCRUMVERSAO/Fulcrum-$FULCRUMVERSAO-shasums.txt"
 if sha256sum --ignore-missing --check "Fulcrum-$FULCRUMVERSAO-shasums.txt" | grep -q ": OK"; then
  ok "Verificação SHA256 para Fulcrum-$FULCRUMVERSAO bem-sucedida."
 else
  erro "PROBLEMA A VERIFICAR A CHAVE SHA256 DE Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux.tar.gz"
 fi
 curl https://raw.githubusercontent.com/Electron-Cash/keys-n-hashes/master/pubkeys/calinkey.txt | gpg --import
 sleep 2
 if gpg --verify "Fulcrum-$FULCRUMVERSAO-shasums.txt.asc" | grep -q "Good signature from"; then
  ok "Assinatura bitcoin SHA256SUMS.asc válida."
 else
  erro "Assinatura inválida. Instalacao interrompida!"
 fi
 # Instalar fulcrum
 tar -xzvf "Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux.tar.gz"
 sudo install -m 0755 -o root -g root -t /usr/local/bin "Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux/Fulcrum" "Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux/FulcrumAdmin"
 # Apagar ficheiros de instalacao
 # sudo rm -r Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux Fulcrum-$FULCRUMVERSAO-$ESTEARCH-linux.tar.gz Fulcrum-$FULCRUMVERSAO-shasums.txt Fulcrum-$FULCRUMVERSAO-shasums.txt.asc
}

function GerarFulcrumConf() {
 clear
 . banner/FULCRUM
 cd "${HOME_FULCRUM_USER}"
 ln -s "$PASTAFULCRUM" "${HOME_FULCRUM_USER}/.fulcrum"
 DetectarRede
 if openssl req -newkey rsa:2048 -sha256 -nodes -x509 -days 3650 -subj "/O=Fulcrum" -keyout "$PASTAFULCRUM/key.pem" -out "$PASTAFULCRUM/cert.pem" ; then
  ok "Certificados e Chaves criadas com sucesso."
 else
  erro "Falha ao criar os Certificados e Chaves"
 fi
 info "A criar ficheiro fulcrum.conf ..."
 echo "# RaMiX: fulcrum configuration
# $PASTAFULCRUM/fulcrum.conf

## Bitcoin Core settings
bitcoind = 127.0.0.1:$DEFAULT_BITCOINRPC_PORT

# RPC AUTH


## Admin Script settings
admin = $DEFAULT_FULCRUMADMIN_PORT

## Fulcrum server general settings
datadir = $PASTAFULCRUM/fulcrum_db
cert = $PASTAFULCRUM/cert.pem
key = $PASTAFULCRUM/key.pem
ssl = 0.0.0.0:$DEFAULT_FULCRUMSSL_PORT
tcp = 0.0.0.0:$DEFAULT_FULCRUMTCP_PORT
peering = false

# RPi optimizations
bitcoind_timeout = 600
bitcoind_clients = 1
worker_threads = 1
db_mem = 1024.0

# 4GB RAM (default)
db_max_open_files = 200
fast-sync = 1024

# Set utxo-cache according to your device performance,
# recommended: utxo-cache=1/2 x RAM available e.g: 4GB RAM -> utxo-cache=2000
utxo-cache = 2000

" | tee "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
 chmod 755 "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
 BuscarScreenVars
 if [[ "$BTCRPCAUTHMETOD" == "cookie" ]]; then
  info "Configurar metodo de autenticacao rpcauth/cookie file"
  sed -i "/# RPC AUTH/a $BTCRPCPASSWORDHASHED" "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
 elif [[ "$BTCRPCAUTHMETOD" == "password" ]]; then
  info "Configurar metodo de autenticacao rpcuser e rpcpass"
  sed -i "/# RPC AUTH/a rpcpassword = $BTCRPCPASSWORD" "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
  sed -i "/# RPC AUTH/a rpcuser = $BTCRPCUSERNAME" "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
  ok "Metodo autenticacao configurado"
 else
  erro "Valor inválido para a variável BTCRPCAUTHMETOD no ficheiro variaveis"
 fi
 if [[ "$MAINORTESTNET" == "testnet4" ]]; then
  mkdir "$PASTAFULCRUM/fulcrum_${MAINORTESTNET}_db"
  chown -R "$DEFAULT_FULCRUM_USER":"$DEFAULT_FULCRUM_GROUP" "$PASTAFULCRUM/fulcrum_${MAINORTESTNET}_db"
  sed -i '2itestnet4 = true' "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
  sed -i "s|^datadir *=.*|datadir = ${PASTAFULCRUM}/fulcrum_${MAINORTESTNET}_db|" "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
  ok "Configurado para testnet"
 fi
 if [[ "$MAINORTESTNET" == "mainnet" ]]; then
  mkdir "$PASTAFULCRUM/fulcrum_db"
  chown -R "$DEFAULT_FULCRUM_USER":"$DEFAULT_FULCRUM_GROUP" "$PASTAFULCRUM/fulcrum_db"
  sed -i "s|^datadir *=.*|datadir = ${PASTAFULCRUM}/fulcrum_db|" "${HOME_FULCRUM_USER}/.fulcrum/fulcrum.conf"
  ok "Configurado para mainnet"
 fi
}

function GerarServicoFulcrum() {
 clear
 . banner/FULCRUM
 info "A Gerar o arquivo de servico fulcrum.service ..."
 echo "# RaMiX: systemd unit for Fulcrum
# /etc/systemd/system/fulcrum.service

[Unit]
Description=Fulcrum
Requires=bitcoind.service
After=bitcoind.service

StartLimitBurst=2
StartLimitIntervalSec=20

[Service]
ExecStart=/usr/local/bin/Fulcrum ${PASTAFULCRUM}/fulcrum.conf
# ExecStop=/usr/local/bin/FulcrumAdmin -p $DEFAULT_FULCRUMADMIN_PORT stop

User=$DEFAULT_FULCRUM_USER
Group=$DEFAULT_FULCRUM_GROUP

# Process management
####################
Type=exec
KillSignal=SIGINT
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/fulcrum.service
 sudo systemctl daemon-reload
 ok "Servico daemon reloaded"
 sleep 1
 aviso "Habilitar servico fulcrum"
 HabilitarServico "fulcrum"
 aviso "Iniciar Servico"
 sleep 1
 IniciarServico "fulcrum"
 sleep 3
 SistemaSincronizacao "fulcrum"
}

# Main
clear
. banner/FULCRUM
sleep 4
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "FulcrumZone"
screenSessionCheck "${DEFAULT_FULCRUM_USER}" "session_${DEFAULT_FULCRUM_USER}" "GerarFulcrumConf"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "GerarServicoFulcrum"

if [[ "$USETOR" == 1 ]]; then
 info "A configurar Tor no Fulcrum..."
 ConfigurarAcessoTor "/var/lib/tor/hidden_service_fulcrum_tcp_ssl" "$DEFAULT_FULCRUMTCP_PORT"
 ConfigurarAcessoTor "/var/lib/tor/hidden_service_fulcrum_tcp_ssl" "$DEFAULT_FULCRUMSSL_PORT"
 sudo systemctl reload tor
fi