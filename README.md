[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
![Shellcheck](https://github.com/hellresistor/DTV-Node/workflows/Shellcheck/badge.svg)
[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)

# DTV-Node - Don't Trust, Verify!

Projecto para Preparar um Nó(Node) de Bitcoin e Lightning em Bash Script em PC ou Raspberry usando Debian 12 Server.

- [Funcionalidades](#funcionalidades)
- [Instalação](#instalacao)
- [Contribuição](#contribuicao)

---

## 📖 **Sobre o Projeto**
Este projecto é dedicado a todos entre os que estão para nascer e os que já foram enterrados.
Visa a automação e instalação de um servidor completo para Bitcoin e Lightning em sistema limpo em Debian.
Usando linguagem de mais fácil entendimento e sem 'Addons' deixo uma alternativa ao projecto Umbrell.

---

## ⚙️ **Funcionalidades**
- [x] Verificação de compatibilidade do Sistema
- [x] Detecção de Discos
- [x] Instalar Segurança (SSH, UFW firewall, fail2ban, Nginx)
- [x] Detecção de Discos
- [x] Instalar Privacidade (TOR e I2P)
- [x] Configurar Privacidade nos Nodes (TOR e I2P)
- [x] Instalar Bitcoin Node (Knots ou Core)
- [x] Instalar Fulcrum
- [x] Instalar Mempool
- [ ] Instalar Lighting - dev..
- [ ] Instalar Nostr Relay - dev..
- [ ] Configurar CloudFlare
- [ ] Instalar BTCPayServer
- [ ] Instalar Public-Pool (Solo miner Pool)
- [x] Desinstalar

---

## 💻 **Instalação**

### Pré-requisitos de hardware
- Debian 12 Bookworm Server
- CPU: >=2x Cores
- RAM: >=4GB
- DISCO SSD/Nvme: >=2TB

### Extras para Raspberry 4/5
- USB Pen Drive com >=32GB com Raspbian (Debian Bookworm)

### Como Usar
```bash
# Entrar como utilizador 'root'
su -
git clone https://github.com/hellresistor/DTV-Node.git
chmod -R 777 DTV-Node
cd DTV-Node
# Edita o ficheiro variaveis
nano variaveis
# LETS GO!
. Start.sh
```

---

## ⚡ **Contribuição**
Bitcoin Lightning: hellresistor@medusa.bz

