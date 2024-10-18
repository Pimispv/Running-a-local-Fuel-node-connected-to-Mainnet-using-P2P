
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
curl -s https://install.fuel.network | sh


get_peer_id() {
    read -p "Do you have 'secret'? (yes/no): " has_peer_id
    if [ "$has_peer_id" = "no" ]; then
      fuel-core-keygen new --key-type peering > wallet.txt 
    elif [ "$has_peer_id" = "yes" ]; then
        read -p "Please enter your peer_id and secre: " secret
        secret > wallet.txt 
     else
        echo -e "${RED}Invalid input. Please type 'yes' or 'no'.${RESET}"
    fi
}
get_peer_id

sleep 5
secret=$(grep -o '"secret":"[^"]*' wallet.txt | sed 's/"secret":"//')
echo "The secret: $secret"

sleep 5

# Set open file limit
ulimit -S -n 32768

read -p "main-net node name: " nodename
read -p "ETH main-net RPC: " RPC

tmux new-session -d -s fuel-node

tmux send-keys -t fuel-node "
fuel-core run \
--enable-relayer \
--service-name ${nodename} \
--keypair ${secret} \
--relayer ${RPC} \
--ip=0.0.0.0 --port 4000 --peering-port 30333 \
--db-path ~/.fuel-mainnet \
--snapshot ignition/ \
--utxo-validation --poa-instant false --enable-p2p \
--bootstrap-nodes /dnsaddr/mainnet.fuel.network \
--sync-header-batch-size 100 \
--relayer-v2-listening-contracts=0xAEB0c00D0125A8a788956ade4f4F12Ead9f65DDf \
--relayer-da-deploy-height=20620434 \
--relayer-log-page-size=100 \
--sync-block-stream-buffer-size 30" C-m

echo -e "${YELLOW}Check logs: tmux attach-session -t fuel-node${RESET}"

