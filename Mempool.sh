#!/bin/bash
#--------------------------#
#      Fulcrum V0.3.0      #
#--------------------------#
. variaveis
. funcbasic

function RequisitosMempool(){
 . banner/MEMPOOL
 if node -v >/dev/null 2>&1 ; then
  ok " node js instalado $(node -v)" 
  NPMLATEST=$(npm view npm version)
  NPMCURRENT=$(npm -v)
  if [ "$(printf '%s\n%s' "$NPMLATEST" "$NPMCURRENT" | sort -V | tail -n1)" != "$NPMCURRENT" ]; then
   aviso "Nova versão do npm disponível: $NPMCURRENT → $NPMLATEST"
   sudo npm install -g npm@"$NPMLATEST"
  else
   ok "npm já está atualizado ($NPMCURRENT)"
  fi
 else
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  CheckInstalarPacotes "nodejs" "build-essential"
 fi
 if [[ -z "$DEFAULT_MEMPOOL_PORT" ]] ; then
  erro "DEFAULT_MEMPOOL_PORT não definido"
 else
  sudo ufw allow "$DEFAULT_MEMPOOL_PORT"/tcp comment 'allow Mempool SSL'
 fi
 DetectarCriarUtilizadores "${DEFAULT_MEMPOOL_USER}"
 sudo adduser "${DEFAULT_MEMPOOL_USER}" "${DEFAULT_BITCOIN_GROUP}"
 info " Instalar MariaDB e Criar BD.."
 CheckInstalarPacotes "mariadb-server" "mariadb-client"
 MEMPOOLGENPASSM=$(gpg --gen-random --armor 1 32)
 BackupInformacao "# MEMPOOL Generated password [M]"
 BackupInformacao "MEMPOOLGENPASSM=\"$MEMPOOLGENPASSM\""
 echo "export MEMPOOLGENPASSM='$MEMPOOLGENPASSM'" > "$THISTEMPFOLDER/screen_env_vars"
 sudo mysql -e "
  CREATE DATABASE IF NOT EXISTS mempool;
  GRANT ALL PRIVILEGES ON mempool.* TO 'mempool'@'localhost' IDENTIFIED BY '$(printf '%q' "$MEMPOOLGENPASSM")';
  FLUSH PRIVILEGES;
 " || erro "Erro ao executar comandos SQL."
 ok "Banco de dados 'mempool' criado e permissões atribuídas com sucesso."
 info "Checking.... Cargo-Rust"
 RUSTVER=$(sudo -u "${DEFAULT_MEMPOOL_USER}" bash -c "cargo --version" 2>/dev/null)
 if [[ -z "$RUSTVER" ]]; then
  info "Rust não encontrado para o utilizador ${DEFAULT_MEMPOOL_USER}, instalando..."
  sudo -u "${DEFAULT_MEMPOOL_USER}" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
  ok "Rust instalado para ${DEFAULT_MEMPOOL_USER}"
 else
  ok "Rust já está instalado: $RUSTVER"
 fi
 info "A Gerar o arquivo de servico mempool.service ..."
 echo "# /etc/systemd/system/mempool.service
[Unit]
Description=mempool
After=bitcoind.service

[Service]
WorkingDirectory=$HOME_MEMPOOL_USER/mempool/backend
ExecStart=/usr/bin/node --max-old-space-size=2048 dist/index.js
User=$DEFAULT_MEMPOOL_USER

# Restart on failure but no more than default times (DefaultStartLimitBurst=5) every 10 minutes (600 seconds). Otherwise stop
Restart=on-failure
RestartSec=600

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/mempool.service
 sudo systemctl daemon-reload
 HabilitarServico "mempool"
 #IniciarServico "mempool"
}

function DownloadMempool(){
 . banner/MEMPOOL
 cd "${HOME_MEMPOOL_USER}"
 MEMPOOLVERSAO=$(curl --silent "https://api.github.com/repos/mempool/mempool/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
 git clone https://github.com/mempool/mempool
 cd "${HOME_MEMPOOL_USER}/mempool"
 git checkout "$MEMPOOLVERSAO"
}

function BackendMempool(){
 . banner/MEMPOOL
 if ! grep -q 'source ~/.cargo/env' "${HOME_MEMPOOL_USER}/.bashrc"; then
  echo "source ~/.cargo/env" >> "${HOME_MEMPOOL_USER}/.bashrc"
 fi
 source "${HOME_MEMPOOL_USER}/.cargo/env" info "Instalar o Backend da Mempool.." 
 cd "${HOME_MEMPOOL_USER}/mempool/backend"
 npm install --prod
 npm run build
 BuscarScreenVars
 cat > "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json" <<EOTF
{
  "MEMPOOL": {
    "OFFICIAL": false,
    "NETWORK": "mainnet",
    "BACKEND": "electrum",
    "ENABLED": true,
    "HTTP_PORT": 8999,
    "SPAWN_CLUSTER_PROCS": 0,
    "API_URL_PREFIX": "/api/v1/",
    "POLL_RATE_MS": 2000,
    "CACHE_DIR": "./cache",
    "CACHE_ENABLED": true,
    "CLEAR_PROTECTION_MINUTES": 20,
    "RECOMMENDED_FEE_PERCENTILE": 50,
    "BLOCK_WEIGHT_UNITS": 4000000,
    "INITIAL_BLOCKS_AMOUNT": 8,
    "MEMPOOL_BLOCKS_AMOUNT": 8,
    "INDEXING_BLOCKS_AMOUNT": 11000,
    "BLOCKS_SUMMARIES_INDEXING": false,
    "GOGGLES_INDEXING": false,
    "USE_SECOND_NODE_FOR_MINFEE": false,
    "EXTERNAL_ASSETS": [],
    "EXTERNAL_MAX_RETRY": 1,
    "EXTERNAL_RETRY_INTERVAL": 0,
    "USER_AGENT": "mempool",
    "STDOUT_LOG_MIN_PRIORITY": "debug",
    "AUTOMATIC_POOLS_UPDATE": false,
    "POOLS_JSON_URL": "https://raw.githubusercontent.com/mempool/mining-pools/master/pools-v2.json",
    "POOLS_JSON_TREE_URL": "https://api.github.com/repos/mempool/mining-pools/git/trees/master",
    "POOLS_UPDATE_DELAY": 604800,
    "AUDIT": false,
    "RUST_GBT": true,
    "LIMIT_GBT": false,
    "CPFP_INDEXING": false,
    "DISK_CACHE_BLOCK_INTERVAL": 6,
    "MAX_PUSH_TX_SIZE_WEIGHT": 4000000,
    "ALLOW_UNREACHABLE": true,
    "PRICE_UPDATES_PER_HOUR": 1,
    "MAX_TRACKED_ADDRESSES": 100,
    "UNIX_SOCKET_PATH": ""
  },
  "CORE_RPC": {
    "HOST": "127.0.0.1",
    "PORT": "$DEFAULT_BITCOINRPC_PORT",
    "TIMEOUT": 60000,
    "DEBUG_LOG_PATH": "${PASTABITCOIN}/debug.log"
  },
  "ELECTRUM": {
    "HOST": "127.0.0.1",
    "PORT": "$DEFAULT_FULCRUMSSL_PORT",
    "TLS_ENABLED": true
  },
  "SECOND_CORE_RPC": {
    "HOST": "127.0.0.1",
    "PORT": 8332,
    "USERNAME": "mempool",
    "PASSWORD": "mempool",
    "TIMEOUT": 60000,
    "COOKIE": false,
    "COOKIE_PATH": "$PASTABITCOIN/.cookie"
  },
  "DATABASE": {
    "ENABLED": true,
    "HOST": "127.0.0.1",
    "PORT": "$DEFAULT_MYSQL_PORT",
    "SOCKET": "/run/mysqld/mysqld.sock",
    "USERNAME": "mempool",
    "PASSWORD": "$MEMPOOLGENPASSM",
    "DATABASE": "mempool",
    "TIMEOUT": 180000
  },
  "STATISTICS": {
    "ENABLED": true,
    "TX_PER_SECOND_SAMPLE_PERIOD": 150
  },
  "LND": {
    "TLS_CERT_PATH": "tls.cert",
    "MACAROON_PATH": "readonly.macaroon",
    "REST_API_URL": "https://localhost:8080",
    "TIMEOUT": 10000
  },
  "SOCKS5PROXY": {
    "ENABLED": false,
    "USE_ONION": false,
    "HOST": "127.0.0.1",
    "PORT": ${DEFAULT_TORBRIDGE_PORT}
  },
  "EXTERNAL_DATA_SERVER": {
    "MEMPOOL_API": "https://mempool.space/api/v1",
    "MEMPOOL_ONION": "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api/v1",
    "LIQUID_API": "https://liquid.network/api/v1",
    "LIQUID_ONION": "http://liquidmom47f6s3m53ebfxn47p76a6tlnxib3wp6deux7wuzotdr6cyd.onion/api/v1"
  },
  "MEMPOOL_SERVICES": {
    "API": "https://mempool.space/api/v1/services",
    "ACCELERATIONS": false
  },
  "STRATUM": {
    "ENABLED": false,
    "API": "http://localhost:1234"
  },
  "PRICE_DATA_SERVER": {
    "TOR_URL": "http://wizpriceje6q5tdrxkyiazsgu7irquiqjy2dptezqhrtu7l2qelqktid.onion/getAllMarketPrices"
  }
}
EOTF

if [[ "$BTCRPCAUTHMETOD" == "cookie" ]]; then
 info "Configurar metodo de autenticacao rpcauth"
 sed -i "/\"TIMEOUT\": 60000,/a \ \ \ \ \"COOKIE_PATH\": \"${HOME_BITCOIN_USER}/.cookie\"," "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 sed -i "/\"TIMEOUT\": 60000,/a \ \ \ \ \"COOKIE\": true," "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
elif [[ "$BTCRPCAUTHMETOD" == "password" ]]; then
 info "Configurar metodo de autenticacao rpcuser e rpcpass"
 sed -i "/\"TIMEOUT\": 60000,/a \ \ \ \ \"USERNAME\": \"${BTCRPCUSERNAME}\"," "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 sed -i "/\"TIMEOUT\": 60000,/a \ \ \ \ \"PASSWORD\": \"${BTCRPCPASSWORD}\"," "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 sed -i "/\"TIMEOUT\": 60000,/a \ \ \ \ \"COOKIE\": false," "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 ok "Metodo autenticacao configurado"
else
 erro "Valor inválido para a variável BTCRPCAUTHMETOD"
fi
if [[ "$MAINORTESTNET" == "testnet4" ]]; then
 info "A configurar para testnet4"
 sed -i 's/"NETWORK": *"[^"]*"/"NETWORK": "testnet4"/' "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 ok "testnet4 configurado no ficheiro .conf"
fi
npm run start
ok "Configuracao de Backend Terminada"
}

function FrontendMempool(){
 . banner/MEMPOOL
 info "Instalar o Frontend da Mempool.."
 cd "${HOME_MEMPOOL_USER}/mempool/frontend"
 npm install --prod
 npm run build
 ok "Frontend da Mempool Instalado com sucesso!"
}

function ConfigMempool() {
 . banner/MEMPOOL
 sudo rsync -av --delete "${HOME_MEMPOOL_USER}/mempool/frontend/dist/" /var/www/
 sudo chown -R www-data:www-data /var/www/mempool
 sudo chmod 600 "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 info "configurar nginx... "
 echo "proxy_read_timeout 300;
proxy_connect_timeout 300;
proxy_send_timeout 300;

        map \$http_accept_language \$header_lang {
                default en-US;
                ~*^en-US en-US;
                ~*^en en-US;
                ~*^ar ar;
                ~*^ca ca;
                ~*^cs cs;
                ~*^de de;
                ~*^es es;
                ~*^fa fa;
                ~*^fr fr;
                ~*^ko ko;
                ~*^it it;
                ~*^he he;
                ~*^ka ka;
                ~*^hu hu;
                ~*^mk mk;
                ~*^nl nl;
                ~*^ja ja;
                ~*^nb nb;
                ~*^pl pl;
                ~*^pt pt;
                ~*^ro ro;
                ~*^ru ru;
                ~*^sl sl;
                ~*^fi fi;
                ~*^sv sv;
                ~*^th th;
                ~*^tr tr;
                ~*^uk uk;
                ~*^vi vi;
                ~*^zh zh;
                ~*^hi hi;
        }
  
        map \$cookie_lang \$lang {
                default \$header_lang;
                ~*^en-US en-US;
                ~*^en en-US;
                ~*^ar ar;
                ~*^ca ca;
                ~*^cs cs;
                ~*^de de;
                ~*^es es;
                ~*^fa fa;
                ~*^fr fr;
                ~*^ko ko;
                ~*^it it;
                ~*^he he;
                ~*^ka ka;
                ~*^hu hu;
                ~*^mk mk;
                ~*^nl nl;
                ~*^ja ja;
                ~*^nb nb;
                ~*^pl pl;
                ~*^pt pt;
                ~*^ro ro;
                ~*^ru ru;
                ~*^sl sl;
                ~*^fi fi;
                ~*^sv sv;
                ~*^th th;
                ~*^tr tr;
                ~*^uk uk;
                ~*^vi vi;
                ~*^zh zh;
                ~*^hi hi;
        }
  
server {
    listen $DEFAULT_MEMPOOLHTTPS_PORT ssl;
    listen [::]:$DEFAULT_MEMPOOLHTTPS_PORT ssl;
    server_name _;
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_session_timeout 4h;
    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers on;
    include /etc/nginx/snippets/nginx-mempool.conf;
}
" | sudo tee /etc/nginx/sites-available/mempool-ssl.conf

sudo ln -sf /etc/nginx/sites-available/mempool-ssl.conf /etc/nginx/sites-enabled/
sudo rsync -av "$HOME_MEMPOOL_USER/mempool/nginx-mempool.conf" /etc/nginx/snippets
sudo mv /etc/nginx/nginx.conf /etc/nginx/donttrustverify-nginx.conf.bak
echo "user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

http {
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        server_tokens off;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ssl_protocols TLSv1.3;
        ssl_prefer_server_ciphers on;
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        gzip on;
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}

stream {
        ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
        ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout 4h;
        ssl_protocols TLSv1.3;
        ssl_prefer_server_ciphers on;
        include /etc/nginx/streams-enabled/*.conf;
}
" | sudo tee  /etc/nginx/nginx.conf

 VerificarNginx

 if [[ "$USETOR" == 1 ]]; then
 info "Configuracao Tor no Mempool..."
 VerificarServico "tor"
 sudo adduser "${DEFAULT_MEMPOOL}" "${DEFAULT_TOR_GROUP}"
 PararServico "mempool"
 sed -i 's/"SOCKS5PROXY": {\n\(\s*\)"ENABLED": false,/"SOCKS5PROXY": {\n\1"ENABLED": true,/' "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 sed -i 's/"USE_ONION": false,/"USE_ONION": true,/' "${HOME_MEMPOOL_USER}/mempool/backend/mempool-config.json"
 ConfigurarAcessoTor "/var/lib/tor/hidden_service_mempool" "$DEFAULT_MEMPOOLHTTPS_PORT"
 sudo systemctl reload tor
 IniciarServico "mempool"
 ok "Tor ativado no mempool-config.json"
fi

}

# Menu de seleção
clear
. banner/MEMPOOL
sleep 4
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "RequisitosMempool"
screenSessionCheck "${DEFAULT_MEMPOOL_USER}" "session_${DEFAULT_MEMPOOL_USER}" "DownloadMempool"
screenSessionCheck "${DEFAULT_MEMPOOL_USER}" "session_${DEFAULT_MEMPOOL_USER}" "BackendMempool"
screenSessionCheck "${DEFAULT_MEMPOOL_USER}" "session_${DEFAULT_MEMPOOL_USER}" "FrontendMempool"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "ConfigMempool"
