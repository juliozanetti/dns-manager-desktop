#!/bin/bash

# Configurações
DNS_FILE="dns_servers.lst"
# Cores para a saída do terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar pré-requisitos
check_prerequisites() {
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}Erro: 'sudo' não encontrado. Este script requer privilégios de superusuário.${NC}"
        exit 1
    fi
    # Alterado: Verificar nmcli em vez de resolvectl
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}Erro: 'nmcli' não encontrado. Certifique-se de que o pacote 'network-manager' está instalado e ativo.${NC}"
        echo -e "${YELLOW}Tente instalar com: sudo apt update && sudo apt install network-manager${NC}"
        exit 1
    fi
    # Opcional: Verificar se o serviço NetworkManager está ativo
    if ! systemctl is-active --quiet NetworkManager; then
        echo -e "${YELLOW}Aviso: O serviço 'NetworkManager' não está ativo. O script pode não funcionar como esperado.${NC}"
        echo -e "${YELLOW}Tente ativar com: sudo systemctl enable --now NetworkManager${NC}"
        # Não sair, apenas avisar
    fi

    # Criar o arquivo DNS_FILE se não existir
    if [ ! -f "$DNS_FILE" ]; then
        touch "$DNS_FILE"
        echo -e "${YELLOW}Arquivo '$DNS_FILE' criado.${NC}"
    fi
}

# Função para exibir as opções de DNS
show_dns_options() {
    echo -e "\n${BLUE}--- Opções de Servidores DNS Disponíveis ---${NC}"
    if [ ! -s "$DNS_FILE" ]; then
        echo -e "${YELLOW}Nenhum servidor DNS registrado. Use a opção 'Adicionar' para começar.${NC}"
        return 1
    fi

    local i=1
    while IFS=';' read -r name ipv4_addrs ipv6_addrs; do
        echo -e "${GREEN}${i}.${NC} ${name}"
        echo -e "   IPv4: ${ipv4_addrs:-N/A}"
        echo -e "   IPv6: ${ipv6_addrs:-N/A}"
        ((i++))
    done < "$DNS_FILE"
    echo -e "${BLUE}------------------------------------------${NC}"
    return 0
}

# Função para validar um endereço IP (básico)
# Nota: A validação de IPv6 é simplificada e pode não cobrir todas as formas válidas.
validate_ip() {
    local ip=$1
    # Permite vazio
    if [ -z "$ip" ]; then
        return 0
    fi
    # IPv4 básico
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    fi
    # IPv6 básico (simplificado)
    if [[ "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}$ || "$ip" =~ ^::([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || "$ip" =~ ^([0-9a-fA-F]{1,4}:){1}(:[0-9a-fA-F]{1,4}){1,6}$ || "$ip" =~ ^::[0-9a-fA-F]{1,4}$ || "$ip" =~ ^[0-9a-fA-F]{1,4}::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}$ ]]; then
        return 0
    fi
    return 1
}

# Função para adicionar um novo servidor DNS
add_dns_entry() {
    echo -e "\n${BLUE}--- Adicionar Novo Servidor DNS ---${NC}"
    local name ipv4_addrs ipv6_addrs

    read -rp "Nome do DNS (ex: Google DNS): " name
    if [ -z "$name" ]; then
        echo -e "${RED}Nome não pode ser vazio. Cancelando.${NC}"
        return
    fi

    read -rp "Endereços IPv4 (separados por vírgula, ex: 8.8.8.8,8.8.4.4 - deixe em branco para nenhum): " ipv4_input
    local valid_ipv4s=""
    IFS=',' read -ra ADDRS <<< "$ipv4_input"
    for ip in "${ADDRS[@]}"; do
        ip=$(echo "$ip" | xargs) # Remove espaços em branco
        if validate_ip "$ip"; then
            valid_ipv4s+="${ip},"
        else
            echo -e "${RED}Aviso: IPv4 inválido '$ip' será ignorado.${NC}"
        fi
    done
    ipv4_addrs=$(echo "$valid_ipv4s" | sed 's/,$//') # Remove vírgula final

    read -rp "Endereços IPv6 (separados por vírgula, ex: 2001:4860::8888,2001:4860::8844 - deixe em branco para nenhum): " ipv6_input
    local valid_ipv6s=""
    IFS=',' read -ra ADDRS <<< "$ipv6_input"
    for ip in "${ADDRS[@]}"; do
        ip=$(echo "$ip" | xargs) # Remove espaços em branco
        if validate_ip "$ip"; then
            valid_ipv6s+="${ip},"
        else
            echo -e "${RED}Aviso: IPv6 inválido '$ip' será ignorado.${NC}"
        fi
    done
    ipv6_addrs=$(echo "$valid_ipv6s" | sed 's/,$//') # Remove vírgula final

    echo "${name};${ipv4_addrs};${ipv6_addrs}" >> "$DNS_FILE"
    echo -e "${GREEN}Servidor DNS '$name' adicionado com sucesso!${NC}"
    sleep 1
}

# Função para editar um servidor DNS existente
edit_dns_entry() {
    echo -e "\n${BLUE}--- Editar Servidor DNS ---${NC}"
    if ! show_dns_options; then
        echo -e "${YELLOW}Não há DNS para editar.${NC}"
        sleep 1
        return
    fi

    local choice
    read -rp "Digite o número do DNS para editar: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $(wc -l < "$DNS_FILE") ]; then
        echo -e "${RED}Escolha inválida. Cancelando.${NC}"
        sleep 1
        return
    fi

    local line_num="$choice"
    local old_entry=$(sed -n "${line_num}p" "$DNS_FILE")
    IFS=';' read -r old_name old_ipv4_addrs old_ipv6_addrs <<< "$old_entry"

    echo -e "\n${YELLOW}Editando: ${old_name}${NC}"
    echo "  IPv4 atual: ${old_ipv4_addrs}"
    echo "  IPv6 atual: ${old_ipv6_addrs}"

    local new_name new_ipv4_addrs new_ipv6_addrs

    read -rp "Novo nome do DNS (atual: ${old_name}) - deixe em branco para manter: " new_name
    new_name=${new_name:-$old_name}

    read -rp "Novos endereços IPv4 (atual: ${old_ipv4_addrs}) - separados por vírgula, deixe em branco para manter: " new_ipv4_input
    local updated_ipv4s=""
    if [ -z "$new_ipv4_input" ]; then
        new_ipv4_addrs="$old_ipv4_addrs"
    else
        IFS=',' read -ra ADDRS <<< "$new_ipv4_input"
        for ip in "${ADDRS[@]}"; do
            ip=$(echo "$ip" | xargs)
            if validate_ip "$ip"; then
                updated_ipv4s+="${ip},"
            else
                echo -e "${RED}Aviso: IPv4 inválido '$ip' será ignorado.${NC}"
            fi
        done
        new_ipv4_addrs=$(echo "$updated_ipv4s" | sed 's/,$//')
    fi

    read -rp "Novos endereços IPv6 (atual: ${old_ipv6_addrs}) - separados por vírgula, deixe em branco para manter: " new_ipv6_input
    local updated_ipv6s=""
    if [ -z "$new_ipv6_input" ]; then
        new_ipv6_addrs="$old_ipv6_addrs"
    else
        IFS=',' read -ra ADDRS <<< "$new_ipv6_input"
        for ip in "${ADDRS[@]}"; do
            ip=$(echo "$ip" | xargs)
            if validate_ip "$ip"; then
                updated_ipv6s+="${ip},"
            else
                echo -e "${RED}Aviso: IPv6 inválido '$ip' será ignorado.${NC}"
            fi
        done
        new_ipv6_addrs=$(echo "$updated_ipv6s" | sed 's/,$//')
    fi

    local new_entry="${new_name};${new_ipv4_addrs};${new_ipv6_addrs}"
    # O caracter '|' é usado como delimitador no sed, evite-o nos dados da linha.
    # O sed -i substitui a linha inteira pelo novo_entry.
    sed -i "${line_num}s|.*|${new_entry}|" "$DNS_FILE"
    echo -e "${GREEN}Servidor DNS '${new_name}' atualizado com sucesso!${NC}"
    sleep 1
}

# Função para apagar um servidor DNS
delete_dns_entry() {
    echo -e "\n${BLUE}--- Apagar Servidor DNS ---${NC}"
    if ! show_dns_options; then
        echo -e "${YELLOW}Não há DNS para apagar.${NC}"
        sleep 1
        return
    fi

    local choice
    read -rp "Digite o número do DNS para apagar: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $(wc -l < "$DNS_FILE") ]; then
        echo -e "${RED}Escolha inválida. Cancelando.${NC}"
        sleep 1
        return
    fi

    local line_num="$choice"
    local entry_to_delete=$(sed -n "${line_num}p" "$DNS_FILE")
    IFS=';' read -r name_to_delete <<< "$entry_to_delete"

    read -rp "Tem certeza que deseja apagar '${name_to_delete}'? (s/N): " confirm
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        sed -i "${line_num}d" "$DNS_FILE"
        echo -e "${GREEN}Servidor DNS '${name_to_delete}' apagado com sucesso!${NC}"
    else
        echo -e "${YELLOW}Operação cancelada.${NC}"
    fi
    sleep 1
}

# Função para aplicar as alterações de DNS usando NetworkManager (nmcli)
apply_dns_changes() {
    echo -e "\n${BLUE}--- Aplicar Servidor DNS (via NetworkManager) ---${NC}"
    if ! show_dns_options; then
        echo -e "${YELLOW}Nenhum servidor DNS para aplicar.${NC}"
        sleep 1
        return
    fi

    local choice
    read -rp "Digite o número do DNS que deseja aplicar: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $(wc -l < "$DNS_FILE") ]; then
        echo -e "${RED}Escolha inválida. Cancelando.${NC}"
        sleep 1
        return
    fi

    local selected_entry=$(sed -n "${choice}p" "$DNS_FILE")
    IFS=';' read -r selected_name selected_ipv4_addrs selected_ipv6_addrs <<< "$selected_entry"

    echo -e "${YELLOW}Você selecionou: ${selected_name}${NC}"
    echo "  IPv4: ${selected_ipv4_addrs}"
    echo "  IPv6: ${selected_ipv6_addrs}"

    echo -e "\n${BLUE}--- Selecione o Perfil de Conexão de Rede ---${NC}"
    local connections=()
    local i=1
    echo "Perfis de conexão ativos (obtidos via nmcli):"
    
    while IFS= read -r line; do
        local conn_name=$(echo "$line" | cut -d':' -f1)
        local conn_type=$(echo "$line" | cut -d':' -f2)
        local conn_device=$(echo "$line" | cut -d':' -f3)

        if [ -n "$conn_name" ]; then
            connections+=("$conn_name")
            echo -e "${GREEN}${i}.${NC} ${conn_name} (Tipo: ${conn_type}, Dispositivo: ${conn_device:-N/A})"
            ((i++))
        fi
    done < <(nmcli -t -f NAME,TYPE,DEVICE con show --active)

    if [ ${#connections[@]} -eq 0 ]; then
        echo -e "${RED}Nenhum perfil de conexão ativo encontrado gerenciado pelo NetworkManager.${NC}"
        echo -e "${YELLOW}Verifique suas conexões de rede ou o status do NetworkManager.${NC}"
        sleep 3
        return
    fi

    local conn_choice
    read -rp "Digite o número do perfil de conexão para aplicar o DNS: " conn_choice

    if ! [[ "$conn_choice" =~ ^[0-9]+$ ]] || [ "$conn_choice" -lt 1 ] || [ "$conn_choice" -gt ${#connections[@]} ]; then
        echo -e "${RED}Escolha de perfil de conexão inválida. Cancelando.${NC}"
        sleep 1
        return
    fi

    local selected_connection="${connections[$((conn_choice-1))]}"
    
    # Desligar a interface como primeira rotina
    echo -e "${YELLOW}Desligando a conexão '${selected_connection}' para garantir a remoção de DNSs anteriores...${NC}"
    local error_output=""
    if ! error_output=$(sudo nmcli con down "${selected_connection}" 2>&1); then
        echo -e "${RED}Falha ao desativar a conexão: ${error_output}${NC}"
        echo -e "${RED}Não foi possível preparar a interface. As alterações podem não ser aplicadas corretamente.${NC}"
        sleep 5
        return
    fi
    sleep 2 # Pequena pausa para garantir que a interface desça

    echo -e "${YELLOW}Aplicando DNS para o perfil: '${selected_connection}'${NC}"

    local nmcli_ipv4_dns_arg=""
    if [ -n "$selected_ipv4_addrs" ]; then
        nmcli_ipv4_dns_arg="${selected_ipv4_addrs}"
    else
        nmcli_ipv4_dns_arg=""
    fi

    local nmcli_ipv6_dns_arg=""
    if [ -n "$selected_ipv6_addrs" ]; then
        nmcli_ipv6_dns_arg="${selected_ipv6_addrs}"
    else
        nmcli_ipv6_dns_arg=""
    fi

    local success=true
    
    echo -e "${YELLOW}Definindo DNS IPv4: sudo nmcli con mod \"${selected_connection}\" ipv4.dns \"${nmcli_ipv4_dns_arg}\"${NC}"
    if ! error_output=$(sudo nmcli con mod "${selected_connection}" ipv4.dns "${nmcli_ipv4_dns_arg}" 2>&1); then
        echo -e "${RED}Falha ao definir DNS IPv4: ${error_output}${NC}"
        success=false
    fi

    echo -e "${YELLOW}Definindo DNS IPv6: sudo nmcli con mod \"${selected_connection}\" ipv6.dns \"${nmcli_ipv6_dns_arg}\"${NC}"
    if ! error_output=$(sudo nmcli con mod "${selected_connection}" ipv6.dns "${nmcli_ipv6_dns_arg}" 2>&1); then
        echo -e "${RED}Falha ao definir DNS IPv6: ${error_output}${NC}"
        success=false
    fi

    if ! $success; then
        echo -e "${RED}As configurações de DNS não foram aplicadas completamente. Verifique as mensagens de erro acima.${NC}"
        echo -e "${YELLOW}--- Dicas de Solução de Problemas ---${NC}"
        echo -e "${YELLOW}1. Verifique se o perfil de conexão '${selected_connection}' existe e está ativo: ${BLUE}nmcli con show${NC}"
        echo -e "${YELLOW}2. Verifique o status do serviço NetworkManager: ${BLUE}systemctl status NetworkManager${NC}"
        echo -e "${YELLOW}3. Verifique se você tem permissões de sudo para executar 'nmcli'.${NC}"
        echo -e "${YELLOW}------------------------------------${NC}"
        sleep 5
        return
    fi

    echo -e "${YELLOW}Ativando a conexão '${selected_connection}' para aplicar as alterações...${NC}"
    if ! error_output=$(sudo nmcli con up "${selected_connection}" 2>&1); then
        echo -e "${RED}Falha ao ativar a conexão: ${error_output}${NC}"
        echo -e "${RED}As alterações de DNS podem não ter sido aplicadas. Tente reiniciar manualmente.${NC}"
        sleep 5
        return
    fi

    echo -e "${GREEN}DNS aplicado e conexão ativada com sucesso para '${selected_connection}'!${NC}"
    
    # Verificar se apenas as alterações realizadas estão ativas
    echo -e "\n${BLUE}--- Verificando DNSs Ativos para '${selected_connection}' ---${NC}"
    
    # 1. Verificar via nmcli (configuração do perfil)
    echo -e "${YELLOW}Configuração de DNS no perfil '${selected_connection}' (via nmcli):${NC}"
    sudo nmcli con show "${selected_connection}" | grep -E 'ipv4.dns|ipv6.dns'
    echo -e "${BLUE}------------------------------------${NC}"

    # 2. Verificar via resolvectl (o que o sistema está realmente usando)
    # Primeiro, obtenha o nome da interface de rede física associada a esta conexão
    local device_name=$(nmcli -t -f DEVICE con show "${selected_connection}" --active 2>/dev/null | head -n 1)
    
    if [ -n "$device_name" ] && command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved; then
        echo -e "${YELLOW}Status de DNS para a interface '${device_name}' (via resolvectl):${NC}"
        # Exibe apenas as linhas relevantes de DNS para a interface específica
        resolvectl status "${device_name}" | grep -E 'DNS Servers|DNSSEC|Current DNS Server|DNS Domain'
    else
        echo -e "${YELLOW}Não foi possível verificar o status de DNS via resolvectl para a interface associada (${device_name:-N/A}) ou systemd-resolved não está ativo.${NC}"
    fi
    echo -e "${BLUE}------------------------------------${NC}"

    echo -e "${GREEN}Verifique a conectividade: ping google.com${NC}"
    sleep 3
}

# Função para listar servidores DNS atuais do sistema
list_current_dns() {
    echo -e "\n${BLUE}--- Servidores DNS Atuais do Sistema ---${NC}"
    local has_resolvectl=false
    if command -v resolvectl &> /dev/null; then
        has_resolvectl=true
        echo -e "${BLUE}>>> Configurações de DNS via systemd-resolved (resolvectl status):${NC}"
        local current_link_info=""
        local link_count=0
        local regex_link_pattern="^[[:space:]]*Link[[:space:]]+([0-9]+)[[:space:]]+\(([^)]+)\)$"

        # Read resolvectl status line by line
        while IFS= read -r line; do
            # Check for a new Link section
            if [[ "$line" =~ $regex_link_pattern ]]; then
                # If we've collected info for a previous link, print it first
                if [ -n "$current_link_info" ]; then
                    echo -e "$current_link_info"
                    echo -e "${BLUE}------------------------------------${NC}"
                fi
                link_count=$((link_count + 1))
                local link_number="${BASH_REMATCH[1]}"
                local interface_name="${BASH_REMATCH[2]}"
                current_link_info="${YELLOW}${link_count}. Link ${link_number} (${interface_name})${NC}\n"
            elif [ -n "$current_link_info" ]; then
                # Collect relevant DNS lines for the current link
                if [[ "$line" =~ ^[[:space:]]*(Current DNS Server|DNS Servers|DNS Domain|DNSSEC NTA|DNSSEC|LLMNR|mDNS):[[:space:]]*(.*)$ ]]; then
                    current_link_info+="  ${GREEN}${BASH_REMATCH[1]}:${NC} ${BASH_REMATCH[2]}\n"
                fi
            fi
        done < <(resolvectl status)

        # Print the last collected link info
        if [ -n "$current_link_info" ]; then
            echo -e "$current_link_info"
            echo -e "${BLUE}------------------------------------${NC}"
        fi

        if [ "$link_count" -eq 0 ]; then
            echo -e "${YELLOW}Nenhum servidor DNS ativo gerenciado por systemd-resolved encontrado.${NC}"
            echo -e "${YELLOW}Isso pode indicar que o systemd-resolved não está em uso ou não há interfaces configuradas para usar DNS.${NC}"
        fi
    else
        echo -e "${YELLOW}'resolvectl' não encontrado. Não é possível listar DNS via systemd-resolved.${NC}"
    fi

    echo -e "\n${BLUE}>>> Configurações de DNS via NetworkManager (nmcli):${NC}"
    if command -v nmcli &> /dev/null; then
        local active_connections=$(nmcli -t -f NAME,TYPE,DEVICE con show --active)
        if [ -n "$active_connections" ]; then
            local nm_conn_count=0
            while IFS= read -r line; do
                local conn_name=$(echo "$line" | cut -d':' -f1)
                local conn_type=$(echo "$line" | cut -d':' -f2)
                local conn_device=$(echo "$line" | cut -d':' -f3)

                nm_conn_count=$((nm_conn_count + 1))
                echo -e "${YELLOW}${nm_conn_count}. Perfil de Conexão: ${conn_name} (Tipo: ${conn_type}, Dispositivo: ${conn_device:-N/A})${NC}"
                # Usar 'sudo' para nmcli con show geralmente não é necessário apenas para visualizar DNS,
                # mas é boa prática para consistência se houver restrições.
                local dns_info=$(sudo nmcli -g ipv4.dns,ipv6.dns con show "$conn_name" 2>/dev/null)
                if [ -n "$dns_info" ]; then
                    # Adiciona uma tabulação para cada linha de DNS para melhor formatação
                    echo "$dns_info" | sed -E 's/^(ipv4.dns|ipv6.dns):/\t\t\1:/g'
                else
                    echo -e "\t\tNenhum DNS configurado diretamente neste perfil."
                fi
                echo -e "${BLUE}------------------------------------${NC}"
            done < <(echo "$active_connections")
        else
            echo -e "${YELLOW}Nenhum perfil de conexão ativo encontrado via nmcli.${NC}"
        fi
    else
        echo -e "${YELLOW}'nmcli' não encontrado. Não é possível verificar DNS via NetworkManager.${NC}"
    fi
    echo -e "${BLUE}------------------------------------------${NC}"
    sleep 3
}

# Função principal do menu
main_menu() {
    # Garante que o script sairá em caso de erro, variável não definida ou falha em pipeline
    set -euo pipefail

    check_prerequisites
    while true; do
        # NOVA LINHA: Limpa a tela ao retornar ao menu principal
        clear || printf "\033c"

        echo -e "\n${BLUE}========== Menu de Gerenciamento de DNS ==========${NC}"
        echo -e "${GREEN}1.${NC} Exibir Servidores DNS Registrados"
        echo -e "${GREEN}2.${NC} Adicionar Novo Servidor DNS"
        echo -e "${GREEN}3.${NC} Editar Servidor DNS Existente"
        echo -e "${GREEN}4.${NC} Apagar Servidor DNS"
        echo -e "${GREEN}5.${NC} Aplicar Servidor DNS (Mudar no Sistema via NetworkManager)"
        echo -e "${GREEN}6.${NC} Listar Servidores DNS Atuais do Sistema"
        echo -e "${RED}7.${NC} Sair"
        echo -e "${BLUE}==================================================${NC}"

        read -rp "Escolha uma opção: " option

        case $option in
            1) show_dns_options ;;
            2) add_dns_entry ;;
            3) edit_dns_entry ;;
            4) delete_dns_entry ;;
            5) apply_dns_changes ;;
            6) list_current_dns ;;
            7) echo -e "${YELLOW}Saindo... Adeus!${NC}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida. Por favor, tente novamente.${NC}" ;;
        esac
        echo ""
        read -rp "Pressione Enter para continuar..."
    done
}

# Iniciar o script
main_menu
