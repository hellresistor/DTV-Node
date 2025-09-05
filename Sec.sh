#!/bin/bash
#--------------------------------------------#
#              Seguranca V0.3.0              #
#--------------------------------------------#
. variaveis
. funcbasic

function sshzone(){
### Verificar chaves SSH 
if [[ -f "$HOME_ADMIN_USER/.ssh/*.pub" ]]; then
 ok "Encontradas chaves SSH!"
else
 aviso "Nao existem chaves SSH!"
fi

while true; do 
  read -rp $'Escolha: (C/P/N)\n (C)riar chaves novas\n (P)ropria chave\n (N)ao criar chaves SSH (Nao Recomendado): ' SSHESCOLHA
  SSHESCOLHARESP=$(echo "$SSHESCOLHA" | tr '[:upper:]' '[:lower:]')
  if [[ "$SSHESCOLHARESP" == "c" ]]; then
#    while true; do
#      info "Deseja criar password para a nova chave SSH? (S)im/(N)ao"
#      read -rp "Opção: " CRIARPASSSIMNAO
#      CRIARPASSSIMNAORESP=$(echo "$CRIARPASSSIMNAO" | tr '[:upper:]' '[:lower:]')
#      if [[ "$CRIARPASSSIMNAORESP" == "s" ]]; then
#        read -s -p "Senha para as chaves SSH: " SSHKEYPASSWORD
#        echo
#        info "Criando chaves SSH protegidas por senha..."
#        sudo -u "$DEFAULT_ADMIN_USER" bash -c "printf '\n${SSHKEYPASSWORD}\n${SSHKEYPASSWORD}\n' | ssh-keygen -t rsa -b 2048 -f \"$HOME_ADMIN_USER/.ssh/id_rsa\""
#        break
#      elif [[ "$CRIARPASSSIMNAORESP" == "n" ]]; then
#        info "Criando novas chaves SSH SEM proteção de senha..."
#        sudo -u "$DEFAULT_ADMIN_USER" bash -c "printf '\n\n\n' | ssh-keygen -t rsa -b 2048 -f \"$HOME_ADMIN_USER/.ssh/id_rsa\""
#        break
#      else
#        aviso "Opcao \"$CRIARPASSSIMNAORESP\" inválida. Escolha S- Sim ou N- Nao!"
#      fi
#    done
      if confirmar "Deseja criar password para a nova chave SSH? (S/N): "; then
        read -rsp "Senha para as chaves SSH: " SSHKEYPASSWORD
        echo
        info "Criando chaves SSH protegidas por senha..."
        sudo -u "$DEFAULT_ADMIN_USER" bash -c "printf '\n${SSHKEYPASSWORD}\n${SSHKEYPASSWORD}\n' | ssh-keygen -t rsa -b 2048 -f \"$HOME_ADMIN_USER/.ssh/id_rsa\""
      else
        info "Criando novas chaves SSH SEM proteção de senha..."
        sudo -u "$DEFAULT_ADMIN_USER" bash -c "printf '\n\n\n' | ssh-keygen -t rsa -b 2048 -f \"$HOME_ADMIN_USER/.ssh/id_rsa\""
      fi
    # Verifica se a chave foi criada com sucesso
    if [[ -f "$HOME_ADMIN_USER/.ssh/id_rsa.pub" ]]; then
      CHAVEPUBLICA="$(sudo cat "$HOME_ADMIN_USER/.ssh/id_rsa.pub")"
      ok "Chave pública gerada com sucesso!"
      aviso "$CHAVEPUBLICA"
      BackupInformacao "Chave Publica SSH:"
      BackupInformacao "$CHAVEPUBLICA"
    else
      erro "Falha ao gerar a chave pública!"
    fi
    break
  elif [[ "$SSHESCOLHARESP" == "p" ]]; then
    echo "Criando diretório SSH e configurando permissões..."
    sudo mkdir -p "$HOME_ADMIN_USER/.ssh"
    sudo chown -R "$DEFAULT_ADMIN_USER:$DEFAULT_ADMIN_GROUP" "$HOME_ADMIN_USER/.ssh"
    sudo chmod 700 "$HOME_ADMIN_USER/.ssh"
    read -rp $'Cola aqui a tua chave pública:\nATENÇÃO: verifica o exemplo.\nExemplo:\nssh-ed25519 AAAAC3Nza... Nome\n> ' CHAVEPUBLICA
    if [[ "$CHAVEPUBLICA" =~ ^ssh-(rsa|ed25519) ]]; then
      echo "$CHAVEPUBLICA" | sudo tee -a "$HOME_ADMIN_USER/.ssh/authorized_keys" > /dev/null
      sudo chmod 600 "$HOME_ADMIN_USER/.ssh/authorized_keys"
      ok "Chave pública adicionada com sucesso!"
    else
      erro "A chave colada não parece ser válida. Operação cancelada."
    fi
    break
  elif [[ "$SSHESCOLHARESP" == "n" ]]; then
    aviso "NAO CRIAR CHAVES SSH! NAO RECOMENDADO!!!"
    break
  else
    aviso "Opcao \"$SSHESCOLHARESP\" inválida. Escolha uma opção válida (C, P ou N)!"
  fi
done

### Configuração do servidor SSH ###
if [ "$SSHESCOLHARESP" = "p" ] || [ "$SSHESCOLHARESP" = "c" ]; then
  if [ -z "$CHAVEPUBLICA" ]; then
    erro "CHAVE PUBLICA SSH VAZIA! Abortar configuração SSH."
    exit 1
  fi
  info "Adicionando chave pública ao servidor..."
  echo "$CHAVEPUBLICA" | sudo tee "$HOME_ADMIN_USER/.ssh/authorized_keys" > /dev/null
  sudo chown "${DEFAULT_ADMIN_USER}:${DEFAULT_ADMIN_GROUP}" "$HOME_ADMIN_USER/.ssh/authorized_keys"
  sudo chmod 400 "$HOME_ADMIN_USER/.ssh/authorized_keys"
  sudo chattr +i "$HOME_ADMIN_USER/.ssh/authorized_keys"
  ok "Chave pública SSH adicionada ao servidor."
  info "--------------------------------------"
  aviso "---      SALVE COM SUA VIDA        ---"
  aviso "---  A CHAVE PRIVADA (.ssh/id_rsa) ---"
  info "--------------------------------------"
  sleep 3
  info "Aplicando configuração personalizada no servidor SSH..."
  sudo tee /etc/ssh/sshd_config > /dev/null <<EOF
Protocol 2
Port ${DEFAULT_SSH_PORT}
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
AllowGroups ${DEFAULT_ADMIN_GROUP}
AllowUsers ${DEFAULT_ADMIN_USER}
SyslogFacility AUTH
LogLevel INFO
PermitRootLogin no
PermitEmptyPasswords no
ClientAliveCountMax 0
ClientAliveInterval 300
LoginGraceTime 30
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication no
AuthenticationMethods publickey
AuthorizedKeysFile %h/.ssh/authorized_keys
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org
IgnoreRhosts yes
HostbasedAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
TCPKeepAlive no
AcceptEnv LANGUAGE
PermitUserEnvironment no
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no
UseDNS no
Compression no
AllowAgentForwarding no
MaxAuthTries 2
MaxSessions 2
MaxStartups 2
DebianBanner no
EOF
  sudo chown root:root /etc/ssh/sshd_config
  sudo chmod 600 /etc/ssh/sshd_config
  ok "Configuracao do servidor SSH finalizada com sucesso."
else
  info "Aplicando configuração SSH básica..."
  sudo sed -i "/^#Port /s|^#||; /^Port /s| .*| ${DEFAULT_SSH_PORT}|" /etc/ssh/sshd_config
  sudo sed -i '/^#ListenAddress /s/^#//' /etc/ssh/sshd_config
  sudo sed -i '/^#AddressFamily /s/^#//' /etc/ssh/sshd_config
  sudo sed -i '/^#SyslogFacility /s/^#//' /etc/ssh/sshd_config
  sudo sed -i '/^#LogLevel /s/^#//' /etc/ssh/sshd_config
  sudo sed -i '/^#PasswordAuthentication /s/^#//' /etc/ssh/sshd_config
  sudo sed -i '/^#PermitEmptyPasswords /s/^#//' /etc/ssh/sshd_config
  sudo sed -i "/^#PermitRootLogin /s|^#||; /^PermitRootLogin /s| .*| no|" /etc/ssh/sshd_config
  sudo sed -i "/^#PubkeyAuthentication /s|^#||; /^PubkeyAuthentication /s| .*| no|" /etc/ssh/sshd_config
  sudo sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
  sudo chown root:root /etc/ssh/sshd_config
  sudo chmod 600 /etc/ssh/sshd_config
  aviso "Arquivo de configuracao SSH básico aplicado com sucesso."
fi
}

function ufwzone(){
 ### Configurar UFW firewall ###
 CheckInstalarPacotes "ufw"
 sudo ufw default deny incoming
 sudo ufw default allow outgoing
 sudo ufw allow "$DEFAULT_SSH_PORT"/tcp comment 'Permitir SSH from anywhere'
 sudo ufw logging off
 sudo ufw enable
 sudo systemctl enable ufw
 ### Incrementer o limite de openfiles ###
 echo "*    soft nofile 128000
*    hard nofile 128000
root soft nofile 128000
root hard nofile 128000" | sudo tee /etc/security/limits.d/90-limits.conf > /dev/null
}

function nginxzone(){
### Configurar nginx ###
CheckInstalarPacotes "nginx" "libnginx-mod-stream"
sudo openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
echo "user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 768;
}

http {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:HTTP-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/sites-enabled/*.conf;
}

stream {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:STREAM-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/streams-enabled/*.conf;
}
" | sudo tee /etc/nginx/nginx.conf > /dev/null
sudo chmod 0644 /etc/nginx/nginx.conf
sudo chown root /etc/nginx/nginx.conf

sudo mkdir /etc/nginx/streams-enabled
sudo rm /etc/nginx/sites-enabled/default

### Verificar configuracao nginx ###
VerificarNginx
}

function FailTwoBan() {
CheckInstalarPacotes "fail2ban"
}

# Main
. SSH
info "A configurar SSH, UFW firewall, nginx https server, Fail2ban"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "sshzone"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "ufwzone"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "nginxzone"
screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "FailTwoBan"
