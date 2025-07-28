# dns-manager-desktop
Desktop DNS Manager

---

# Gerenciador de DNS Interativo para Debian/Ubuntu

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📝 Descrição

Este é um script Bash interativo projetado para simplificar o gerenciamento e a aplicação de configurações de servidores DNS (IPv4 e IPv6) em sistemas Linux baseados em Debian/Ubuntu (como o Debian 11). Ele utiliza o `NetworkManager` (via `nmcli`) para aplicar as alterações e o `systemd-resolved` (via `resolvectl`) para exibir o status atual do DNS no sistema.

O script permite que você mantenha uma lista de servidores DNS favoritos, adicione novos, edite, apague e os aplique facilmente a uma interface de rede específica, garantindo que as alterações sejam efetivadas através da reinicialização da conexão.

## ✨ Funcionalidades

*   **Gerenciamento de Servidores DNS**:
    *   Exibir uma lista de servidores DNS IPv4 e IPv6 salvos em um arquivo `dns_servers.lst`.
    *   Adicionar novas entradas de servidores DNS (com nome, IPv4 e IPv6).
    *   Editar entradas existentes (nome, IPv4, IPv6).
    *   Apagar entradas.
*   **Aplicação de DNS a Interfaces de Rede**:
    *   Selecionar um servidor DNS salvo para aplicar.
    *   Listar perfis de conexão de rede ativos gerenciados pelo `NetworkManager`.
    *   Aplicar os servidores DNS selecionados a um perfil de conexão específico usando `nmcli`.
    *   **Reinicialização da Conexão**: Desliga a interface de rede no início da aplicação para garantir a remoção de DNSs anteriores e a religa no final para efetivar as alterações.
    *   Verificação pós-aplicação para confirmar os novos DNSs na conexão e via `resolvectl`.
*   **Listagem de DNS Atuais do Sistema**:
    *   Exibir os servidores DNS atualmente em uso pelo sistema, detalhados por interface (via `resolvectl status`).
    *   Mostrar as configurações de DNS por perfil de conexão do `NetworkManager` (via `nmcli`).
*   **Interface Amigável**:
    *   Menu interativo e colorido para facilitar a navegação.
    *   Limpeza de tela automática ao retornar ao menu principal.
    *   Validação básica de endereços IP.
    *   Tratamento de erros e dicas de solução de problemas.

## 🚀 Pré-requisitos

Este script foi desenvolvido e testado no **Debian 11**. Ele requer os seguintes pacotes e ferramentas:

*   **`sudo`**: Para executar comandos com privilégios de superusuário.
*   **`network-manager`**: Pacote principal do NetworkManager.
*   **`nmcli`**: Ferramenta de linha de comando do NetworkManager (geralmente incluída com `network-manager`).
*   **`systemd-resolved`**: O resolvedor de DNS padrão do systemd (geralmente incluído).
*   **`resolvectl`**: Ferramenta de linha de comando para interagir com `systemd-resolved` (geralmente incluída com `systemd-resolved`).
*   **Ferramentas Bash padrão**: `grep`, `awk`, `sed`, `cut`, `sort`, `uniq`, `wc`, `head`, `tail`, `touch`, `systemctl`, `clear` (ou `printf`).

Você pode instalar os pacotes essenciais no Debian/Ubuntu com:

```bash
sudo apt update
sudo apt install network-manager systemd-resolved
```
(`network-manager-gnome` e `network-manager-config-connectivity-debian` são componentes do GNOME/desktop que geralmente instalam o `network-manager` como dependência, mas para a funcionalidade do script, o `network-manager` base é o mais importante.)

## 📦 Como Usar

1.  **Clone o Repositório (ou Salve o Script):**
    ```bash
    git clone https://github.com/seu-usuario/seu-repositorio.git
    cd seu-repositorio # Ou para o diretório onde você salvou o script
    ```
    Ou, copie o conteúdo do script e salve-o em um arquivo, por exemplo, `gerenciar_dns.sh`.

2.  **Dê Permissões de Execução:**
    ```bash
    chmod +x gerenciar_dns.sh
    ```

3.  **Execute o Script:**
    ```bash
    ./gerenciar_dns.sh
    ```

    O script iniciará o menu interativo:

    ```
    ========== Menu de Gerenciamento de DNS ==========
    1. Exibir Servidores DNS Registrados
    2. Adicionar Novo Servidor DNS
    3. Editar Servidor DNS Existente
    4. Apagar Servidor DNS
    5. Aplicar Servidor DNS (Mudar no Sistema via NetworkManager)
    6. Listar Servidores DNS Atuais do Sistema
    7. Sair
    ==================================================
    Escolha uma opção:
    ```

    Siga as instruções na tela para gerenciar seus servidores DNS. Para as opções que modificam o sistema (como a opção 5), você será solicitado a fornecer sua senha de `sudo`.

## 📂 Estrutura de Arquivos

*   `gerenciar_dns.sh`: O script principal em Bash.
*   `dns_servers.lst`: Um arquivo de texto que armazena os servidores DNS que você adiciona. Ele é criado automaticamente se não existir. Cada linha no arquivo representa um servidor DNS, com campos separados por ponto e vírgula (`;`): `Nome;IPv4_Endereços;IPv6_Endereços`.

    Exemplo de `dns_servers.lst`:
    ```
    Google DNS;8.8.8.8,8.8.4.4;2001:4860::8888,2001:4860::8844
    Cloudflare DNS;1.1.1.1,1.0.0.1;2606:4700::1111,2606:4700::1001
    Meu DNS Local;;fd00::1
    ```

## ⚠️ Solução de Problemas

*   **`Erro: 'sudo' não encontrado.`**: Certifique-se de que o pacote `sudo` está instalado (`sudo apt install sudo`) e que seu usuário está configurado para usá-lo.
*   **`Erro: 'nmcli' não encontrado.`**: Instale o pacote `network-manager`: `sudo apt update && sudo apt install network-manager`.
*   **`Erro: 'resolvectl' não encontrado.`**: Instale o pacote `systemd-resolved`: `sudo apt update && sudo apt install systemd-resolved`.
*   **`Aviso: O serviço 'NetworkManager' não está ativo.`**: Ative e habilite o serviço: `sudo systemctl enable --now NetworkManager`.
*   **`Falha ao aplicar o DNS!` ou problemas de conectividade após aplicar**:
    *   Verifique a saída de erro do script para mensagens detalhadas.
    *   Confirme se o perfil de conexão selecionado está correto e ativo (`nmcli con show --active`).
    *   Verifique o status do serviço NetworkManager: `systemctl status NetworkManager`.
    *   Pode haver outro gerenciador de rede (como `ifupdown` ou `dhcpcd`) interferindo. No Debian 11, `NetworkManager` é o padrão para a maioria das instalações de desktop.
    *   Sua sessão SSH pode ser interrompida ao reiniciar a interface. Se isso acontecer, você pode precisar acessar o console físico ou uma nova sessão SSH após a interface se recuperar.
*   **Validação de IP IPv6**: A validação de IPv6 no script é básica e não cobre todas as formas de notação IPv6. Se você tiver problemas com um IPv6 que parece válido mas é rejeitado, tente uma forma mais canônica (completa) do endereço.

## 🤝 Contribuições

Contribuições são bem-vindas! Se você tiver sugestões, melhorias ou encontrar bugs, por favor, abra uma issue ou envie um pull request.

## 📄 Licença

Este projeto está licenciado sob a Licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---
