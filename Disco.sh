#!/bin/bash
#------------------------------------------#
#               DISCOS V0.3.0              #
#------------------------------------------#
. variaveis
. funcbasic

TMP_MOUNTS=()

function cleanup() {
 local m
 for m in "${TMP_MOUNTS[@]}"; do
  if [[ -n "$m" && -d "$m" ]]; then
   sudo umount "$m" &>/dev/null || true
   rmdir "$m" &>/dev/null || true
  fi
 done
}
trap cleanup EXIT

function listar_discos() {
 local disks
 if ! disks=$(lsblk -dno NAME,MODEL,SIZE 2>/dev/null | grep -v loop); then
  aviso "Problema ao obter lista de discos.\n" >&2
  return 1
 fi
 if [[ -z "${disks// }" ]]; then
  aviso "Nenhum disco detectado."
  return 1
 fi
 DISKS="$disks"
 info "Discos disponíveis:"
 printf "${amarelo}7.${final} ${azul}Atualizar Lista ${final}\n"
 local i=1
 local line
 while IFS= read -r line; do
  local name model size
  name=$(awk '{print $1}' <<<"$line")
  size=$(awk '{print $NF}' <<<"$line")
  model=$(awk '{$1=""; $NF=""; print $0}' <<<"$line" | xargs)
  printf "${amarelo}%s - /dev/%s -${final} ${azul}%s (%s)${final}\n" "$i" "$name" "$model" "$size"
  ((i++))
 done <<<"$DISKS"
}

function selecionar_disco() {
 while true; do
  read -rp "Escolha um disco pelo número: " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
   if [[ "$CHOICE" -eq 0 ]]; then
    listar_discos || return 1
    continue
   fi
   DISK_SELECTED=$(echo "$DISKS" | sed -n "${CHOICE}p" | awk '{print $1}')
   if [[ -n "$DISK_SELECTED" ]]; then
    lsblk -d -o NAME,SIZE,MODEL "/dev/$DISK_SELECTED"
    if confirmar "Tem a certeza que quer continuar com este disco? (S/N): "; then
     info "Disco escolhido: /dev/$DISK_SELECTED"
     return 0
    else
     aviso "Cancelado."
     return 1
    fi
   fi
  fi
  aviso "Escolha inválida. Tente novamente."
 done
}

function listar_particoes() {
 local parts
 if ! parts=$(lsblk -ln -o NAME,TYPE "/dev/$DISK_SELECTED" 2>/dev/null | awk '$2 == "part" {print $1}'); then
  aviso "Erro ao listar partições do disco /dev/$DISK_SELECTED."
  return 1
 fi
 if [[ -z "${parts// }" ]]; then
  aviso "Nenhuma partição encontrada no disco /dev/$DISK_SELECTED."
  return 1
 fi
 PARTICOES="$parts"
 info "Partições disponíveis em /dev/$DISK_SELECTED:"
 local i=1
 while IFS= read -r part; do
  printf "%s - /dev/%s\n" "$i" "$part"
  ((i++))
 done <<<"$PARTICOES"
}

function selecionar_particao() {
 while true; do
  read -rp "Escolha uma partição pelo número: " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
   PARTICAO_SELECIONADA=$(echo "$PARTICOES" | sed -n "${CHOICE}p")
   if [[ -n "$PARTICAO_SELECIONADA" ]]; then
    ok "Partição selecionada: /dev/$PARTICAO_SELECIONADA"
    return 0
   fi
  fi
  aviso "Opção inválida. Tente novamente."
 done
}

function verificar_pastadata() {
 local tmpmnt
 tmpmnt=$(mktemp -d) || { aviso "Falha a criar diretório temporário."; return 1; }
 TMP_MOUNTS+=("$tmpmnt")
 if ! sudo mount "/dev/$PARTICAO_SELECIONADA" "$tmpmnt" &>/dev/null; then
  aviso "Não foi possível montar /dev/$PARTICAO_SELECIONADA temporariamente."
  return 1
 fi
 if [[ -e "$tmpmnt/bitcoin" ]]; then
  aviso "Pasta/ficheiro 'bitcoin' encontrado na partição."
  return 2
 fi
 return 0
}

function run_partprobe_or_fallback() {
 local dev="/dev/$1"
 if [[ ! -b "$dev" ]]; then
  erro "Dispositivo $dev não existe."
  return 1
 fi
 if command -v partprobe >/dev/null 2>&1; then
  sudo partprobe "$dev" || aviso "partprobe falhou para $dev"
 elif command -v partx >/dev/null 2>&1; then
  sudo partx -a "$dev" || aviso "partx -a falhou para $dev"
 else
  aviso "partprobe/partx não disponíveis. Aguardar udev..."
 fi
 command -v udevadm >/dev/null 2>&1 && sudo udevadm settle &>/dev/null || true
 local -i i=0 max=12
 while (( i < max )); do
  sleep 1
  if lsblk -ln -o NAME,TYPE "$dev" 2>/dev/null | awk '$2=="part" {exit 0} END{exit 1}'; then
   return 0
  fi
  ((i++))
 done
 aviso "Timeout: partições de $dev não apareceram após ${max}s."
 return 1
}

function criar_tabela_discos() {
 if confirmar "Criar nova tabela GPT em /dev/$DISK_SELECTED? Isto apagará TODOS os dados! (S/N): "; then
  lsblk -d -o NAME,SIZE,MODEL "/dev/$DISK_SELECTED"
  if confirmar "Confirmar criação da tabela GPT? (S/N): "; then
   printf 'g\nw\n' | sudo fdisk "/dev/$DISK_SELECTED" &>/dev/null || {
    erro "Falha ao criar tabela de partições."
    return 1
   }
   sleep 1
   return 0
  else
   aviso "Operação cancelada."
   return 1
  fi
 else
  aviso "Operação cancelada."
  return 1
 fi
}

function criar_particao() {
 aviso "Criando nova partição em /dev/$DISK_SELECTED..."
 printf 'n\n\n\n\nw\n' | sudo fdisk "/dev/$DISK_SELECTED" &>/dev/null || {
  erro "Falha ao criar partição."
  return 1
 }
 run_partprobe_or_fallback "$DISK_SELECTED" || aviso "Tentativa inicial falhou."
 PARTICAO_SELECIONADA=$(lsblk -ln -o NAME,TYPE "/dev/$DISK_SELECTED" | awk '$2=="part"{print $1; exit}')
 if [[ -z "${PARTICAO_SELECIONADA// }" ]]; then
  erro "Partição não encontrada."
  return 1
 fi
 ok "Partição detectada: /dev/$PARTICAO_SELECIONADA"
}

function format_particao() {
 aviso "Formatando partição /dev/$PARTICAO_SELECIONADA..."
 sudo mkfs.ext4 -F "/dev/$PARTICAO_SELECIONADA" &>/dev/null || {
  erro "Falha na formatação."
  return 1
 }
 ok "Partição formatada com sucesso!"
}

function montar_particao() {
 sudo mkdir -p "$PASTADATA" || aviso "pasta existente: $PASTADATA"
 AdicionarUuidAoFstab "$PARTICAO_SELECIONADA"
 sudo chown "${DEFAULT_ADMIN_USER}:${DEFAULT_ADMIN_GROUP}" "$PASTADATA" || aviso "Falha ao ajustar permissões"
 command -v systemctl >/dev/null 2>&1 && sudo systemctl daemon-reexec || aviso "Falha no daemon-reexec."
 ok "Partição montada em $PASTADATA"
}

function configurar_swap() {
 CheckInstalarPacotes "dphys-swapfile"
 if [[ ! -f /etc/dphys-swapfile.bak ]]; then
  sudo cp -p /etc/dphys-swapfile /etc/dphys-swapfile.bak
  ok "Backup do dphys-swapfile criado em /etc/dphys-swapfile.bak"
 else
  aviso "Backup /etc/dphys-swapfile.bak já existe. Pulando cópia."
 fi
 awk -v size="2048" -v path="${PASTADATA}/swapfile" '
  BEGIN {conf_swap=0; conf_file=0}
  {
   if ($0 ~ /^CONF_SWAPSIZE=/) { print "CONF_SWAPSIZE=" size; conf_swap=1 }
   else if ($0 ~ /^CONF_SWAPFILE=/) { print "CONF_SWAPFILE=" path; conf_file=1 }
   else { print $0 }
  }
  END {
   if (conf_swap == 0) print "CONF_SWAPSIZE=" size
   if (conf_file == 0) print "CONF_SWAPFILE=" path
 }' /etc/dphys-swapfile | sudo tee /etc/dphys-swapfile >/dev/null
 sudo dphys-swapfile install
 ReiniciarServico "dphys-swapfile"
}

function main() {
 listar_discos || return 1
 selecionar_disco || return 1
 if listar_particoes; then
  selecionar_particao || return 1
  if verificar_pastadata; then
   if confirmar "Deseja formatar esta partição? (S/N): "; then
    format_particao && montar_particao || aviso "Operação interrompida."
   else
    aviso "Operação interrompida."
   fi
  else
   local rc=$?
   if [[ $rc -eq 2 ]]; then
    if confirmar "Pasta 'bitcoin' encontrada. Deseja formatar? (S/N): "; then
     format_particao && montar_particao || aviso "Operação abortada."
    else
     aviso "Operação abortada. Adicionando e montando particao existente"
     montar_particao || return 1
    fi
   else
    aviso "Não foi possível verificar a partição."
    return 1
   fi
  fi
 else
  criar_tabela_discos || return 1
  criar_particao || return 1
  format_particao || return 1
  montar_particao || return 1
 fi
 configurar_swap
 ok "Operação concluída."
}

#sudo cfdisk
main "$@"

