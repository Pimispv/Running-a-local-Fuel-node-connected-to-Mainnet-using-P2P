#!/bin/bash

# Color variables for design
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

check_tmux() {
    if command -v tmux &> /dev/null; then
        tmux_version=$(tmux --version | head -n 1)
        echo -e "${GREEN}tmux is installed: $tmux_version${RESET}"
    else
        echo -e "${YELLOW}tmux is not installed. Installing...${RESET}"
        install_tmux
    fi
}

install_tmux() {
    echo "Installing tmux..."
    sudo apt-get install tmux -y
}

echo -e "${YELLOW}Installing Fuel...${RESET}"
curl https://install.fuel.network | shell

restart_shell() {
    shell_name=$(basename "$SHELL")
    if [ "$shell_name" = "zsh" ]; then
        echo -e "${YELLOW}Restarting Zsh...${RESET}"
        source "$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
        echo -e "${YELLOW}Restarting Bash...${RESET}"
        source "$HOME/.bashrc"
    else
        echo -e "${RED}Unknown shell: $shell_name${RESET}"
    fi


    get_peer_id() {
  read -p "Do you have 'peer_id'? (yes/no):  " has_peer_id 
  if [ "$has_peer_id" = "no" ]; then 
    echo -e "${YELLOW}Generating new peer id....${RESET}"
    fuel-core-keygen new --key-type peering > temp.txt
    sleep 2
    peer_id=$(cat temp.txt | grep -o '16Uiu2HAm[^\"]*')
    echo "{\"peer_id\":\"$peer_id\"}" > wallet.txt
    echo -e "${GREEN}New peer_id saved in wallet.txt${RESET}"
    rm temp.txt
  elif [ "$has_peer_id" = "yes" ]; then 
    read -p "Please enter your peer_id: " secret
    echo "{\"peer_id\":\"$secret\"}" > wallet.txt
    echo -e "${GREEN}Provided peer_id saved in wallet.txt${RESET}"
  else
    echo -e "${RED}Invalid input. Please type 'yes' or 'no'.${RESET}"
  fi
}

get_peer_id

sleep 5  
peer_id=$(grep -o '"peer_id":"[^"]*' wallet.txt | sed 's/"peer_id":"//')
echo "The peer_id is: $peer_id"

sleep 5 

ulimit -S -n 32768


read -p "main-net node name:  " nodename 
reade -p "ETH main-net RPC: " RPC 

tmux new-session -d -s fuel-node

tmux send-keys -t fuel-node "
fuel-core run \
--enable-relayer \
--service-name ${nodename} \
--keypair ${peer_id} \
--relayer ${RPC} \
--ip=0.0.0.0 --port 4000 --peering-port 30333 \
--db-path ~/.fuel-mainnet \
--snapshot ./your/path/to/chain_config_folder \
--utxo-validation --poa-instant false --enable-p2p \
--bootstrap-nodes /dnsaddr/mainnet.fuel.network \
--sync-header-batch-size 100 \
--relayer-v2-listening-contracts=0xAEB0c00D0125A8a788956ade4f4F12Ead9f65DDf \
--relayer-da-deploy-height=20620434 \
--relayer-log-page-size=100 \
--sync-block-stream-buffer-size 30" C-m 

echo "check logs : tmux attach-session -t fuel-node "
