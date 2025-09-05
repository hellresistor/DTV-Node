#!/bin/bash
#--------------------------------------#
#             Start V0.3.0             #
#--------------------------------------#
. variaveis || { echo "Erro ao carregar o arquivo de variáveis."; exit 1; }

# Função para exibir o menu
menu() {
 clear
 . banner/DontTrustVerify
 printf "%sRede: %s%s %s| %sInstance: %s%s%s\n" "$azul" "$verde" "$MAINORTESTNET" "$final" "$azul" "$verde" "$COREORKNOTS" "$final"
 printf "\n%s=====================================%s\n" "$azul" "$final"
 printf "%s     Menu de Configuração do Servidor\n%s" "$verde" "$final"
 printf "%s=====================================%s\n\n" "$azul" "$final"
 printf "%s1.%s %sDetectar e Preparar o Sistema%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s2.%s %sPreparar DISCOS%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s3.%s %sInstalar Segurança (SSH, UFW, NGINX)%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s4.%s %sInstalar Privacidade (TOR, I2P)%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s5.%s %sInstalar e Configurar Bitcoin Node%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s6.%s %sInstalar Fulcrum Server%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s7.%s %sInstalar Mempool Server%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s8.%s %sInstalar Lightning Node%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s10.%s %sConfigurar Privacidade (TOR)%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s11.%s %sInstalar NOSTR Relay%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s12.%s %sConfigurar CloudFlare%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s13.%s %sInstalar BTCPayServer%s\n" "$amarelo" "$final" "$azul" "$final"
# printf "%s14.%s %sInstalar Public-Pool (Solo miner Pool)%s\n" "$amarelo" "$final" "$azul" "$final"
 printf "%s0.%s %sSair%s\n\n" "$amarelo" "$final" "$vermelho" "$final"
 printf "%s69.%s %sDESINSTALAR%s\n\n" "$amarelo" "$final" "$vermelho" "$final"
}

# Função para verificar a existência de um script antes de executar
function execute_script() {
 local script_name="$1"
 if [[ -x "${script_name}" ]]; then
  info "Executando ${script_name}..."
  bash "${script_name}" || erro "Erro ao executar ${script_name}."
  ok "Execução de ${script_name} concluída."
 else
  erro "O script ${script_name} não foi encontrado ou não tem permissão de execução."
 fi
}

# Função principal
main() {
 while true; do
  menu
  read -rp "Escolha uma opção: " opcao
  case "$opcao" in
   1) execute_script "DetectSys.sh" ;;
   2) execute_script "Disco.sh" ;;
   3) execute_script "Sec.sh" ;;
   4) execute_script "Privacidade.sh" ;;
   5) execute_script "Bitcoin.sh" ;;
   6) execute_script "Fulcrum.sh" ;;
   7) execute_script "Mempool.sh" ;;
   8) execute_script "Lightning.sh" ;;
   10) execute_script "Seguranca.sh" ;;
   11) execute_script "Nostr.sh" ;;
   12) execute_script "CloudFlare.sh" ;;
   13) execute_script "BTCPayServer.sh" ;;
   14) execute_script "PublicPool.sh" ;;
   69) execute_script "Desinstalar.sh" ;;
   0) aviso "Saindo do menu. Até logo!"
      break;;
   *) erro "Opção inválida. Tente novamente." ;;
  esac
  printf "\nPressione ENTER para continuar...\n"
  read -r
 done
}

# Execução da função principal
main
