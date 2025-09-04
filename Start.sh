#!/bin/bash
#--------------------------------------#
#             Start V0.3.0             #
#--------------------------------------#
. variaveis || { echo "Erro ao carregar o arquivo de variáveis."; exit 1; }

# Função para exibir o menu
menu() {
 clear
 . banner/DontTrustVerify
 printf "${azul}Rede: ${verde}$MAINORTESTNET ${final}| ${azul}Instance: ${verde}$COREORKNOTS"
 printf "\n${azul}=====================================${final}\n"
 printf "${verde}     Menu de Configuração do Servidor\n${final}"
 printf "${azul}=====================================${final}\n\n"
 printf "${amarelo}1.${final} ${azul}Detectar e Preparar o Sistema${final}\n"
 printf "${amarelo}2.${final} ${azul}Preparar DISCOS${final}\n"
 printf "${amarelo}3.${final} ${azul}Instalar Segurança (SSH, UFW, NGINX)${final}\n"
 printf "${amarelo}4.${final} ${azul}Instalar Privacidade (TOR, I2P)${final}\n"
 printf "${amarelo}5.${final} ${azul}Instalar e Configurar Bitcoin Node${final}\n"
 printf "${amarelo}6.${final} ${azul}Instalar Fulcrum Server${final}\n"
 printf "${amarelo}7.${final} ${azul}Instalar Mempool Server${final}\n"
#echo
# printf "${amarelo}8.${final} ${azul}Instalar Lightning Node${final}\n"
# printf "${amarelo}10.${final} ${azul}Configurar Privacidade (TOR)${final}\n"
# printf "${amarelo}11.${final} ${azul}Instalar NOSTR Relay${final}\n"
# printf "${amarelo}12.${final} ${azul}Configurar CloudFlare${final}\n"
# printf "${amarelo}13.${final} ${azul}Instalar BTCPayServer${final}\n"
# printf "${amarelo}14.${final} ${azul}Instalar Public-Pool (Solo miner Pool)${final}\n"
 printf "${amarelo}0.${final} ${vermelho}Sair${final}\n\n"
 printf "${amarelo}69.${final} ${vermelho}DESINSTALAR${final}\n\n"
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
