#!/bin/bash
#--------------------------------------------#
#   Detectar e Preparar o Sistema V0.3.0     #
#--------------------------------------------#
. variaveis
. funcbasic

## Verificar utilizador ##
if [[ "$(whoami)" == "root" ]] ; then
 ok "Utilizador $(whoami) Logado"
else
 erro "Usa o comando < sudo -i > para iniciar sessão como root"
fi

## A detectar OS ##
if [ ! -f /etc/os-release ]; then
    CheckInstalarPacotes "lsb-release"
fi
source /etc/os-release

### Verificar distribuicao Linux ###
case "${ID,,}" in
 raspbian) ok "Sistema Operativo ${ID,,} Detectado" ;;
 debian|ubuntu) ok "Sistema Operativo ${ID,,} Detectado" ;;
 centos|rhel|rocky) erro "Distribuição CentOS/RHEL/Rocky Linux detectada." ;;
 fedora) erro "Distribuição Fedora detectada." ;;
 opensuse*|suse|sles) ok "Distribuição openSUSE/SUSE Linux Enterprise detectada." ;;
# arch) ok "Distribuição ${ID,,} Linux detectada."
 *) erro "Distribuicao Linux ${ID,,} Nao suportada, Ainda...!" ;;
esac

## Verificar a arquitectura ##
case "$(uname -m)" in
 aarch64) ESTEARCH="arm64" ;;
 x86_64) ESTEARCH="x86_64" ;;
 amd64) ESTEARCH="amd64" ;; 
 *) erro "Arquitectura $(uname -m) NAO SUPORTADA" ;;
esac
ok "Arquitectura $(uname -m) Detectado" 

## Verificar o tamanho da paginacao ##
PAGE_SIZE="$(getconf PAGE_SIZE)"
if [[ "$PAGE_SIZE" -gt "4096" ]]; then
  if [ -f /boot/firmware/config.txt ]; then
    echo "[pi5]" | sudo tee -a /boot/firmware/config.txt
    echo "kernel=kernel8.img" | sudo tee -a /boot/firmware/config.txt
    ok "Paginacao 4K habilitada no Kernel"
    aviso "Por Favor clique qualquer tecla para reiniciar o Raspberry e execute o Script novamente."
    read -n 1 -s -r
    reboot
  else
    ok "Paginacao 4K já está habilitada no Kernel!"
  fi
fi

## Verificar CPU Cores ###
CPUCORES=$(grep -c '^processor' /proc/cpuinfo)
if [[ $CPUCORES -ge 2 ]] ; then
 ok "CPU com $CPUCORES Cores"
else
 erro "CPU com 2 ou menos Cores: $CPUCORES. UPGRADE CPU Cores"
fi

## Verificar RAM ###
MEMORIARAM=$(awk '/MemTotal/ {print int($2 / 1024 / 1024)}' /proc/meminfo)
if [[ $MEMORIARAM -ge 3 ]]; then
  ok "Memória RAM superior a 3GB: ${MEMORIARAM} GB"
else
  erro "Memória RAM INFERIOR a 3GB: ${MEMORIARAM} GB. Actualize a memória RAM"
fi

### Definir as definicoes de linguagem por-defeito ###
grep -qxF 'export LC_ALL=C' /root/.bashrc || echo 'export LC_ALL=C' >> /root/.bashrc
source /root/.bashrc

CheckInstalarPacotes "sudo" "screen" "cmake" "jq" "bash-completion" "avahi-daemon" "qrencode" "hwinfo" "usbutils" "htop" "curl" "wget" "git" "hdparm" "dphys-swapfile" "apt-transport-https"

### DETEÇÃO DO SISTEMA DE GESTÃO DE REDE no script DetectSys.sh ###
case "$GESTOR_REDE" in
  "networkmanager")
    info "NetworkManager detectado. A configurar rede estática com nmcli..."
    while true; do
      if [[ -z "$ESTEINTERFACE" ]]; then
        erro "Nenhuma interface de rede ativa encontrada (exceto loopback)."
        break
      fi
      info "Informações da interface ativa $ESTEINTERFACE:"
      info "IP: $ESTEIPINFO"
      info "Netmask: $ESTENETMASK"
      info "Gateway: $ESTEGATEWAY"
      info "DNS: $ESTEDNS"
      read -rp 'Deseja configurar Rede Estatica? (S)im/(N)ao ' REDEESCOLHA
      REDEESCOLHARESP=$(echo "$REDEESCOLHA" | tr '[:upper:]' '[:lower:]')
      if [ "$REDEESCOLHARESP" = "s" ]; then
        read -rp "Insira o IP estático ($ESTEIPINFO): " NOVOIP
        NOVOIP="${NOVOIP:-$ESTEIPINFO}"
        read -rp "Insira a máscara de rede ($ESTENETMASK): " NOVANETMASK
        NOVANETMASK="${NOVANETMASK:-$ESTENETMASK}"
        read -rp "Insira o gateway padrão ($ESTEGATEWAY): " NOVOGATEWAY
        NOVOGATEWAY="${NOVOGATEWAY:-$ESTEGATEWAY}"
        read -rp "Insira os servidores DNS ($ESTEDNS): " NOVODNS
        NOVODNS="${NOVODNS:-$ESTEDNS}"
        if [[ -z "$NOVOIP" || -z "$NOVANETMASK" || -z "$NOVOGATEWAY" || -z "$NOVODNS" ]]; then
          aviso "Todos os campos são obrigatórios. Por favor, insira novamente os dados."
          continue
        fi
        if ! [[ "$NOVOIP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          aviso "IP inválido."
          continue
        fi
        if ! [[ "$NOVANETMASK" =~ ^[0-9]+$ ]]; then
          aviso "Máscara inválida."
          continue
        fi
        if ! [[ "$NOVOGATEWAY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          aviso "Gateway inválido."
          continue
        fi
        info "Aplicando configuração de rede estática com nmcli..."
        nmcli connection modify "$ESTECONEXAO" ipv4.addresses "$NOVOIP/$NOVANETMASK"
        nmcli connection modify "$ESTECONEXAO" ipv4.gateway "$NOVOGATEWAY"
        nmcli connection modify "$ESTECONEXAO" ipv4.dns "$NOVODNS"
        nmcli connection modify "$ESTECONEXAO" ipv4.method manual
        nmcli connection down "$ESTECONEXAO" && nmcli connection up "$ESTECONEXAO"
        info "Rede estática aplicada com sucesso!"
        break
      elif [ "$REDEESCOLHARESP" = "n" ]; then
        aviso "Continuar com DHCP atual ($ESTEIPINFO)."
        break
      else
        aviso "Opcao $REDEESCOLHARESP INVALIDA. Escolha Sim ou Nao."
      fi
    done
    ;;
  "networkd")
    aviso "O sistema usa systemd-networkd. Configuração automática ainda não suportada neste script."
    ;;
  "ifupdown")
   info "ifupdown detectado. A configurar rede estática manualmente no /etc/network/interfaces..."
   while true; do
    if [[ -z "$ESTEINTERFACE" ]]; then
      erro "Nenhuma interface de rede ativa encontrada (exceto loopback)."
      break
    fi
    info "Informações da interface ativa $ESTEINTERFACE:"
    info "IP: $ESTEIPINFO"
    info "Netmask: $ESTENETMASK"
    info "Gateway: $ESTEGATEWAY"
    info "DNS: $ESTEDNS"

    read -rp 'Deseja configurar Rede Estatica? (S)im/(N)ao ' REDEESCOLHA
    REDEESCOLHARESP="$(echo "$REDEESCOLHA" | tr '[:upper:]' '[:lower:]')"

    if [ "$REDEESCOLHARESP" = "s" ]; then
      read -rp "Insira o IP estático ($ESTEIPINFO): " NOVOIP
      NOVOIP="${NOVOIP:-$ESTEIPINFO}"
      read -rp "Insira a máscara de rede ($ESTENETMASK): " NOVANETMASK
      NOVANETMASK="${NOVANETMASK:-$ESTENETMASK}"
      read -rp "Insira o gateway padrão ($ESTEGATEWAY): " NOVOGATEWAY
      NOVOGATEWAY="${NOVOGATEWAY:-$ESTEGATEWAY}"
      read -rp "Insira os servidores DNS ($ESTEDNS): " NOVODNS
      NOVODNS="${NOVODNS:-$ESTEDNS}"
      if [[ -z "$NOVOIP" || -z "$NOVANETMASK" || -z "$NOVOGATEWAY" || -z "$NOVODNS" ]]; then
        aviso "Todos os campos são obrigatórios. Por favor, insira novamente os dados."
        continue
      fi
      if ! [[ "$NOVOIP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        aviso "IP inválido."
        continue
      fi
      if ! [[ "$NOVANETMASK" =~ ^[0-9]+$ ]]; then
        aviso "Máscara inválida."
        continue
      fi
      if ! [[ "$NOVOGATEWAY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        aviso "Gateway inválido."
        continue
      fi
      info "Aplicando configuração de rede estática no /etc/network/interfaces..."
      cat <<EOF > "/etc/network/interfaces.d/$ESTEINTERFACE"
auto $ESTEINTERFACE
iface $ESTEINTERFACE inet static
    address $NOVOIP
    netmask $NOVANETMASK
    gateway $NOVOGATEWAY
    dns-nameservers $NOVODNS
EOF
      ifdown "$ESTEINTERFACE" && ifup "$ESTEINTERFACE"
      info "Rede estática aplicada com sucesso!"
      break

    elif [ "$REDEESCOLHARESP" = "n" ]; then
      aviso "Continuar com DHCP atual ($ESTEIPINFO)."
      break
    else
      aviso "Opcao $REDEESCOLHARESP INVALIDA. Escolha Sim ou Nao."
    fi
  done
  ;;
  "fallback") aviso "Nenhum sistema de rede detectado automaticamente. Aplique manualmente estas definições." ;;
esac

### Detectar Utilizador 'admin' ###
DetectarCriarUtilizadores "${DEFAULT_ADMIN_USER}"

if ! sudo id "${DEFAULT_ADMIN_USER}" > /dev/null 2>&1; then
  DefinirPassword "ADMINPASSWORD" "Senha para o utilizador ${DEFAULT_ADMIN_USER}"
  echo -e "${ADMINPASSWORD}\n${ADMINPASSWORD}" | sudo passwd "${DEFAULT_ADMIN_USER}"
  sudo usermod -aG sudo "${DEFAULT_ADMIN_USER}"
fi

### Detectar se o utilizador 'admin' está no ficheiro sudoers ###
sudo cp -p /etc/sudoers /etc/sudoers.backup
if sudo grep -q "${DEFAULT_ADMIN_USER}" /etc/sudoers ; then
 ok "O utilizador '${DEFAULT_ADMIN_USER}' ja esta incluido no ficheiro sudoers."
else
 echo -e "${DEFAULT_ADMIN_USER}\tALL=NOPASSWD:ALL" | sudo tee -a /etc/sudoers
 ok "O utilizador '${DEFAULT_ADMIN_USER}' foi adicionado ao ficheiro sudoers."
fi


if [ ! -d "$THISBCKPFOLDER" ] ; then
 mkdir -p "$THISBCKPFOLDER"
 chmod 777 -R "$THISBCKPFOLDER"
 chown -R "$DEFAULT_ADMIN_USER":"$DEFAULT_ADMIN_GROUP" "$THISBCKPFOLDER"
fi

#if [ ! -d $PASTADATA ]; then
#  info "A pasta $PASTADATA nao existe. Criando..."
#  sudo mkdir $PASTADATA || erro "Pasta $PASTADATA não criada!"
# else
#  aviso "O diretório $PASTADATA já existe."
# fi
