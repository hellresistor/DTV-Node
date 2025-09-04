#!/bin/bash
#--------------------------------------------#
#             Privacidade V0.3.0             #
#--------------------------------------------#
. variaveis
. funcbasic
TORGPGKEY=$(curl -fsSL https://deb.torproject.org/torproject.org/ \
  | grep -oE '[A-F0-9]{40}\.asc' \
  | sed 's/\.asc$//' \
  | head -n 1)

function InstalarTor() {
 CheckInstalarPacotes "apt-transport-https"
 if [[ $(uname -m) == *"aarch64"* ]]; then
  echo "Debug: Dentro de aarch64"
  echo "deb     [arch=arm64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main
deb-src [arch=arm64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tor.list > /dev/null || erro "Falha ao adicionar repositório do Tor."
 elif [[ $(uname -m) == *"x86_64"* ]]; then
  echo "Debug: Dentro de x86_64"
  echo "deb     [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tor.list > /dev/null || erro "Falha ao adicionar repositório do Tor."
 fi
 wget -qO- "https://deb.torproject.org/torproject.org/${TORGPGKEY}.asc" | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
 ok "Download do .asc feito e assinado"
 sleep 2
}

function ConfigTor() {
 CheckInstalarPacotes "tor" "deb.torproject.org-keyring"
 info "Configuracao do Tor"
 sudo sed -i 's/^#CookieAuthentication.*/CookieAuthentication 1/' /etc/tor/torrc
 sudo sed -i 's/^#ControlPort.*/ControlPort 9051/' /etc/tor/torrc
 grep -Fxq "CookieAuthFileGroupReadable 1" /etc/tor/torrc || echo "CookieAuthFileGroupReadable 1" | sudo tee -a /etc/tor/torrc
 if confirmar "Deseja Limite de Bandwidth? (S/N): "; then
  echo -e "#### Guard/Middle relay limit total sum bandwidth \nAccountingStart day 12:00\n\nAccountingMax 10 GBytes\nAccountingRule sum\nRelayBandwidthRate 1 MBytes\nRelayBandwidthBurst 1 MBytes" | sudo tee -a /etc/tor/torrc > /dev/null
  ok "Configuracao de limite de banda configurado!"
 else
  aviso "Nao foi configurado Limite de Banda!"
 fi
 ConfigurarAcessoTor "/var/lib/tor/hidden_service_sshd/" "$DEFAULT_SSH_PORT"
 ReiniciarServico "tor"
 sleep 5
}

if [[ "$USETOR" == 1 ]]; then
 clear
 . TOR
 sleep 3
 InstalarTor
 screenSessionCheck "${DEFAULT_ADMIN_USER}" "session_${DEFAULT_ADMIN_USER}" "ConfigTor"
else
 aviso "Não permitiste usar TOR nas Variaveis..."
fi
