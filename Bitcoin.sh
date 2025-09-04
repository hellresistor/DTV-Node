#!/bin/bash
#--------------------------#
#      Bitcoin V0.3.0      #
#--------------------------#
. variaveis
. funcbasic

function BitcoinZone() {
 clear
 . banner/BTC
 # Criar user bitcoin
 DetectarCriarUtilizadores "${DEFAULT_BITCOIN_USER}"
 sudo adduser "${DEFAULT_ADMIN_USER}" "${DEFAULT_BITCOIN_GROUP}"
 if [ ! -d "$PASTABITCOIN" ]; then
  info "A pasta $PASTABITCOIN nao existe. Criando..."
  sudo mkdir "$PASTABITCOIN" || erro "Pasta $PASTABITCOIN não criada!"
 else
  aviso "O diretório $PASTABITCOIN já existe."
 fi
 sudo chown "$DEFAULT_BITCOIN_USER":"$DEFAULT_BITCOIN_GROUP" "$PASTABITCOIN"
 cd "$THISTEMPFOLDER"
 if [[ "$COREORKNOTS" == "core" ]]; then
  BTCVERSAO=$(curl --silent "https://api.github.com/repos/bitcoin/bitcoin/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')
  #BTCVERSAO="28.0"
  BTCREPFILE="bitcoin-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz"
  BTCREPDIR="bitcoin-core-$BTCVERSAO"
  BTCLINK="https://bitcoincore.org/bin/$BTCREPDIR/$BTCREPFILE"
  BTCLINKSUMS="https://bitcoincore.org/bin/$BTCREPDIR/SHA256SUMS"
  BTCLINKASC="https://bitcoincore.org/bin/$BTCREPDIR/SHA256SUMS.asc"
  REPBUILDKEYS="https://api.github.com/repositories/355107265/contents/builder-keys"
 fi
 if [[ "$COREORKNOTS" == "knots" ]]; then
#  BTCVERSAO="28.1.knots20250305"
  BTCVERSAO="$(curl --silent "https://api.github.com/repos/bitcoinknots/bitcoin/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')"
  BTCVERSAOPRE="${BTCVERSAO%%.*}.x"
  BTCREPDIR="bitcoin-knots-$BTCVERSAO"
  BTCREPFILE="bitcoin-knots-$BTCVERSAO-$(uname -m)-linux-gnu.tar.gz"
  BTCLINK="https://bitcoinknots.org/files/$BTCVERSAOPRE/$BTCVERSAO/$BTCREPFILE"
  BTCLINKSUMS="https://bitcoinknots.org/files/$BTCVERSAOPRE/$BTCVERSAO/SHA256SUMS"
  BTCLINKASC="https://bitcoinknots.org/files/$BTCVERSAOPRE/$BTCVERSAO/SHA256SUMS.asc"
  REPBUILDKEYS="https://github.com/bitcoinknots/guix.sigs"
 fi
 
 wget "$BTCLINK"
 wget "$BTCLINKSUMS"
 wget "$BTCLINKASC"
 sudo ufw allow "$DEFAULT_BITCOIN_PORT"/tcp comment 'allow incoming connections to Bitcoin from anywhere'
 if sha256sum --ignore-missing --check SHA256SUMS | grep -q ": OK"; then
  echo "Verificação SHA256 bem-sucedida."
 else
  erro "PROBLEMA A VERIFICAR A CHAVE SHA256"
 fi
 sleep 2
 curl -s "$REPBUILDKEYS" |  grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do OUTPUT=$(curl -s "$url" | gpg --import 2>&1); if echo "$OUTPUT" | grep -q "imported"; then echo "$OUTPUT"; echo "OK!"; else echo "Detalhes do erro: $OUTPUT"; read -n 1 -s -r -p "Clique qualquer tecla para continuar..."; fi; done
 sleep 2
 
 if gpg --verify SHA256SUMS.asc 2>&1 | grep -q "Good signature from"; then
  echo "Assinatura SHA256SUMS.asc válida!"
 else
  echo "Assinatura inválida. O script vai ser interrompido."
 fi
  
 # Instalar bitcoind
 tar -xvf "$BTCREPFILE"
 sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$BTCVERSAO/bin/*
 
 # Gerar serviço bitcoin core
 info "A Gerar o arquivo de servico bitcoind.service ..."
# cat <<'EOF' > /etc/systemd/system/bitcoind.service
cat <<EOF | sudo tee /etc/systemd/system/bitcoind.service > /dev/null
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
# Service execution
ExecStart=/usr/local/bin/bitcoind \\
                                  -pid=/run/bitcoind/bitcoind.pid \\
                                  -conf=${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf \\
                                  -datadir=${HOME_BITCOIN_USER}/.bitcoin \\
                                  -startupnotify='systemd-notify --ready' \\
                                  -shutdownnotify='systemd-notify --status="Stopping"'
# Process management
Type=notify
NotifyAccess=all
PIDFile=/run/bitcoind/bitcoind.pid
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

# Directory creation and permissions
User=$DEFAULT_BITCOIN_USER
Group=$DEFAULT_BITCOIN_GROUP
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710
UMask=0027

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF

 if [[ "$MAINORTESTNET" == "testnet4" ]]; then
  sudo sed -i 's|ExecStart=/usr/local/bin/bitcoind |ExecStart=/usr/local/bin/bitcoind -testnet4 |' /etc/systemd/system/bitcoind.service
  sudo sed -i 's|\-datadir=\${HOME_BITCOIN_USER}/.bitcoin|\-datadir=\${HOME_BITCOIN_USER}/.bitcoin/testnet4|' /etc/systemd/system/bitcoind.service
 fi

 if ln -s "$PASTABITCOIN" "${HOME_ADMIN_USER}"/.bitcoin ; then
  ok "Acesso a user ${DEFAULT_ADMIN_USER} para executar comandos bitcoin-cli"
 else
  aviso "Problema a dar acesso de execuçao do bitcoin-cli ao user: ${DEFAULT_ADMIN_USER}"
 fi

 sudo systemctl daemon-reload
}

function ConfigurarBitcoin(){
 clear
 . banner/BTC
 cd "${HOME_BITCOIN_USER}"
 ln -s "$PASTABITCOIN" "${HOME_BITCOIN_USER}/.bitcoin"
 DetectarRede
 info "A criar ficheiro bitcoin.conf ..."
 echo "# RaMiX: bitcoind configuration
 # ${HOME_BITCOIN_USER}/bitcoin.conf
server=1
txindex=1
uacomment= $MEUNODENAME
disablewallet=1
rpccookieperms=group
dbcache=2048
blocksonly=1
datacarrier=0
rejecttokens=1
dustrelayfee=0.00000010
assumevalid=0
blockfilterindex=1
peerblockfilters=1
coinstatsindex=1
listen=1

# Privacy Zone
#bind=127.0.0.1=onion
#debug=tor
#debug=i2p
nodebuglogfile=1
#proxy=unix:/run/tor/socks
#onlynet=onion
#onlynet=i2p
onlynet=ipv4
onlynet=ipv6
#i2psam=127.0.0.1:7656

# Bind Zone
bind=127.0.0.1

# RPC AUTH

# Connections

" | tee "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
 if [[ "$COREORKNOTS" == "knots" ]]; then
  read -r -d '' KNOTS_BLOCK <<'EOF'
# Controle de transações e spam (Knots extras)
acceptnonstddatacarrier=1
acceptnonstdtxn=1
bytespersigop=1
bytespersigopstrict=1
maxscriptsize=1650
permitbaremultisig=1
permitbarepubkey=1
datacarriercost=1
datacarriersize=35
EOF
  if grep -q '^\s*#\s*Privacy Zone' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"; then
    sed -i "/^\s*#\s*Privacy Zone/i $KNOTS_BLOCK" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
    ok "Bloco de opcoes Knots adicionado em bitcoin.conf"
  fi
 fi 
 
 chmod 755 "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf" 
 aviso "Configurar password para acesso RPC!"
 DefinirPassword "BTCRPCPASSWORD" "Digite password: "
 BuscarScreenVars
 if [[ "$BTCRPCAUTHMETOD" == "cookie" ]]; then
  info "Configurar metodo de autenticacao rpcauth"
  wget -q -P "${HOME_BITCOIN_USER}/.bitcoin" "https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py"
  info "Gerar Bitcoin RPC password"
  python3 "${HOME_BITCOIN_USER}/.bitcoin/rpcauth.py" "$BTCRPCUSERNAME" "$BTCRPCPASSWORD" | grep -oE "rpcauth=[^ ]+" > "${HOME_BITCOIN_USER}/PasswordB.txt"
  BTCRPCPASSWORDHASHED=$(grep -oE "rpcauth=[^ ]+" "${HOME_BITCOIN_USER}/PasswordB.txt")
  if [[ -z "$BTCRPCPASSWORDHASHED" ]]; then
   erro "Não foi possível gerar o hash da senha RPC."
  fi
  BackupInformacao "BTCRPCPASSWORDHASHED=$BTCRPCPASSWORDHASHED"
  sed -i "/# RPC AUTH/a $BTCRPCPASSWORDHASHED" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
 elif [[ "$BTCRPCAUTHMETOD" == "password" ]]; then
  info "Configurar metodo de autenticacao rpcuser e rpcpass"
  sed -i "/# RPC AUTH/a rpcpassword=$BTCRPCPASSWORD" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  sed -i "/# RPC AUTH/a rpcuser=$BTCRPCUSERNAME" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  ok "Metodo autenticacao configurado"
 else
  erro "Valor inválido para a variável BTCRPCAUTHMETOD"
 fi

 if [[ "$MAINORTESTNET" == "testnet4" ]]; then
  info "Entrou na config da testnet no bitcoin.conf e entra no coment swk sys"
  ComentAwkSys "# Bind Zone" "#" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  info "Terminou o comente"
  echo "
# Testnet4 Zone
[testnet4]
testnet=1
port=48333
rpcport=48332
bind=127.0.0.1
bind=$ESTEIPINFO
rpcbind=127.0.0.1
rpcbind=$ESTEIPINFO
rpcallowip=127.0.0.1
" | tee -a "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  ok "testnet4 configurado no ficheiro .conf"
 fi
 info "Checkar as permissoes"
 if ! chmod 640 "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"; then
  erro "Falha a atribuir permissoes no Arquivo bitcoin.conf !"
 fi
}

function PrimeiroArranque() {
 info "Indo para start and sync btc"
 StartBitcoinAndSync
 aviso "Parando servico bitcoind para Configuracao apos sincronizacao concluida"
 PararServico "bitcoind"
 sleep 1
}

function ConfigBitcoinFinal() {
 if grep -q '^[^#]*dbcache=' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"; then
  sed -i '/dbcache=/s/^/#/' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  info "Linha 'dbcache=' foi comentada."
 fi
 if grep -q '^[^#]*blocksonly=' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"; then
  sed -i '/blocksonly=/s/^/#/' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
  echo "Linha 'blocksonly=' foi comentada."
 fi
 if grep -q "^assumevalid=" "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf" ; then
  sed -i '/^'"assumevalid="'/s/^/#/' "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf"
 else
  echo "#assumevalid=0" | tee -a "${HOME_BITCOIN_USER}/.bitcoin/bitcoin.conf" > /dev/null
 fi
}

function ConfigurarTorBitcoin() {
 info "Configuracao Tor no Bitcoin..."
 VerificarServico "tor"
 sudo adduser "${DEFAULT_BITCOIN_USER}" "${DEFAULT_TOR_GROUP}"
 PararServico "bitcoind"
 sleep 10
 sudo sed -i 's/^#\?debug=tor/debug=tor/' "${PASTABITCOIN}/bitcoin.conf"
 sudo sed -i 's/^#\?bind=127.0.0.1=onion/bind=127.0.0.1=onion/' "${PASTABITCOIN}/bitcoin.conf"
 sudo sed -i 's|^#\?proxy=unix:/run/tor/socks|proxy=unix:/run/tor/socks|' "${PASTABITCOIN}/bitcoin.conf"
 sudo sed -i 's/^#\?onlynet=onion/onlynet=onion/' "${PASTABITCOIN}/bitcoin.conf"
}

############################################################################################
### Trabalhar em source mais tarde para filtro ordinals (Ordispector. Maybe Knots filter?###
function DownloadBitcoinSource(){
 cd $THISTEMPFOLDER
 sudo apt install autoconf automake build-essential libboost-filesystem-dev libboost-system-dev libboost-thread-dev libevent-dev libsqlite3-dev libtool pkg-config libzmq3-dev --no-install-recommends
 wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/bitcoin-$BTCVERSAO.tar.gz
 wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS
 wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS.asc
 wget https://bitcoincore.org/bin/bitcoin-core-$BTCVERSAO/SHA256SUMS.ots
 if sha256sum --ignore-missing --check SHA256SUMS | grep -q ": OK"; then
  echo "Verificação SHA256 bem-sucedida."
 else
  erro "PROBLEMA A VERIFICAR A CHAVE SHA256 DE bitcoin-core-$BTCVERSAO/bitcoin-$BTCVERSAO.tar.gz"
 fi
 sleep 2
 curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" |  grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do OUTPUT=$(curl -s "$url" | gpg --import 2>&1); if echo "$OUTPUT" | grep -q "imported"; then echo "$OUTPUT"; echo "OK!"; else echo "Detalhes do erro: $OUTPUT"; read -n 1 -s -r -p "Clique qualquer tecla para continuar..."; fi; done
 sleep 2
 if gpg --verify SHA256SUMS.asc 2>&1 | grep -q "Good signature from"; then
  echo "Assinatura bitcoin SHA256SUMS.asc válida."
 else
  echo "Assinatura inválida. O script será interrompido."
 fi
 ### Descompactar bitcoind ###
 tar -xvf bitcoin-$BTCVERSAO.tar.gz
 wget -O bdb.sh https://raw.githubusercontent.com/bitcoin/bitcoin/aef8b4f43b0c4300aa6cf2c5cf5c19f55e73499c/contrib/install_db4.sh
 chmod +x bdb.sh
 ./bdb.sh bitcoin-$BTCVERSAO
 cd bitcoin-$BTCVERSAO
 ./autogen.sh
 export BDB_PREFIX="$THISTEMPFOLDER/bitcoin-$BTCVERSAO/db4"
 ./configure \
   BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" \
  --disable-bench \
  --disable-maintainer-mode \
  --disable-tests \
  --with-gui=no
}
function AplicarOrdispector() {
 cd $THISTEMPFOLDER
 cd bitcoin-$BTCVERSAO
 wget https://github.com/minibolt-guide/ramix-node/blob/main/resources/ordisrespector.patch
 cat ordisrespector.patch
 aviso "Dá uma olhada no codigo..."
 sleep 5
 info "Aplicar git ordisrespector patch..."
 git apply ordisrespector.patch || erro "Problema a aplicar patch ordisrespector!"
 make -j$(nproc)
 sudo make install
}
############################################################################################

# MAIN
clear
. banner/BTC
if [[ "$COREORKNOTS" == "core" ]]; then
 info "Usando Bitcoin Core"
elif [[ "$COREORKNOTS" == "knots" ]]; then
 info "Usando Bitcoin Knots"
else
 erro "Variável COREORKNOTS incorrecta!"
fi
if [[ "$MAINORTESTNET" == "testnet4" ]]; then
 SETTESTNET="-$MAINORTESTNET"
 ok "Bitcoin em Testnet4 !"
elif [[ "$MAINORTESTNET" == "mainnet" ]]; then
 SETTESTNET=""
 ok "Bitcoin em Mainnet !"
else 
 erro "Variável MAINORTESTNET incorrecta!"
fi
if [[ "$BTCRPCAUTHMETOD" == "cookie" ]]; then
 info "Sistema de Autenticacao por ficheiro .cookie"
elif [[ "$BTCRPCAUTHMETOD" == "password" ]]; then
 info "Sistema de Autenticacao por rpcuser e rpcpassword" 
else
 erro "Variável BTCRPCAUTHMETOD incorrecta!"
fi

screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "BitcoinZone"
sleep 5
screenSessionCheck "${DEFAULT_BITCOIN_USER}" "session_${DEFAULT_BITCOIN_USER}" "ConfigurarBitcoin"
sleep 5
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "PrimeiroArranque"
sleep 5
screenSessionCheck "${DEFAULT_BITCOIN_USER}" "session_${DEFAULT_BITCOIN_USER}" "ConfigBitcoinFinal"
sleep 5
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "StartBitcoinAndSync"
sleep 5

if [[ "$USETOR" == 1 ]]; then
 info "Configurar bitcoin para usar TOR..."
 screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "ConfigurarTorBitcoin"
 screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "StartBitcoinAndSync"
fi
