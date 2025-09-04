#!/bin/bash
#--------------------------#
#      Desinstalaçao       #
#--------------------------#
. variaveis
. funcbasic
echo " Desinstalar Ramix"

function removeBitcoin(){
rm "$THISTEMPFOLDER/SHA256SUMS*"
rm "$THISTEMPFOLDER/*-linux-gnu.tar.gz"
rm "$THISTEMPFOLDER/*.log"
systemctl stop bitcoind
systemctl disable bitcoind
rm /etc/systemd/system/bitcoind.service
gpasswd -d admin bitcoin
userdel -rf bitcoin
groupdel bitcoin
rm "${HOME_BITCOIN_USER}/.bitcoin"
rm "${HOME_ADMIN_USER}/.bitcoin"
rm -rf "$PASTADATA/bitcoin/"
rm /usr/local/bin/bitcoin*
ufw delete "${DEFAULT_BITCOIN_PORT}"
ufw delete "${DEFAULT_BITCOINRPC_PORT}"
ufw delete "${DEFAULT_BTCTOR_PORT}"
}

function removeFulcrum(){
rm "$THISTEMPFOLDER/*shasums.txt.asc"
rm "$THISTEMPFOLDER/*.tar.gz"
rm "$THISTEMPFOLDER/*.log"
systemctl stop fulcrum
systemctl disable fulcrum
rm /etc/systemd/system/fulcrum.service
systemctl daemon-reload
gpasswd -d admin fulcrum
userdel -rf fulcrum
groupdel fulcrum
rm "${HOME_FULCRUM_USER}/.fulcrum"
rm "${HOME_ADMIN_USER}/.fulcrum"
rm -rf "$PASTADATA/fulcrum/"
rm /usr/local/bin/Fulcrum*
ufw delete "${DEFAULT_FULCRUMSSL_PORT}"
ufw delete "${DEFAULT_FULCRUMTCP_PORT}"

echo "export BTCRPCPASSWORD='xupa1234'" | sudo tee /tmp/screen_env_vars
chmod 777 /tmp/screen_env_vars
}

function removeMempool(){
rm "$THISTEMPFOLDER/*shasums.txt.asc"
rm "$THISTEMPFOLDER/*.tar.gz"
rm "$THISTEMPFOLDER/*.log"
systemctl stop mempool
systemctl disable mempool
rm /etc/systemd/system/mempool.service
systemctl daemon-reload
gpasswd -d admin mempool
userdel -rf mempool
groupdel mempool
rm "${HOME_MEMPOOL_USER}/.mempool"
rm "${HOME_ADMIN_USER}/.mempool"
rm -rf "$PASTADATA/mempool/"
rm /usr/local/bin/Fulcrum*
ufw delete "${DEFAULT_MEMPOOL_PORT}"
ufw delete "${DEFAULT_MEMPOOLHTTPS_PORT}"
sudo mysql -e "
  DROP DATABASE IF EXISTS mempool;
  DROP USER IF EXISTS 'mempool'@'localhost';
  FLUSH PRIVILEGES;
" || aviso "Erro ao remover banco de dados/usuário do Mempool."
sudo rm -R /var/www/*
sudo rm /etc/nginx/sites-avaliable/mempool-ssl.conf
}

fullREMOVE() {
 systemctl stop mempool.service
 sleep 3
 systemctl stop fulcrum.service
 sleep 3
 systemctl stop mariadb.service
 sleep 3
 systemctl stop nginx
 sleep 3
 systemctl stop bitcoind.service
 sleep 3
 systemctl disable mempool.service
 systemctl disable fulcrum.service
 systemctl disable mariadb.service
 systemctl disable nginx.service
 systemctl disable bitcoind.service
 systemctl daemon-reload
 removeBitcoin
 removeFulcrum
 removeMempool
}

fullREMOVE

exit 0