#!/bin/bash

# Color variables for design
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Function to check and install git
check_git() {
    if command -v git &> /dev/null; then
        git_version=$(git --version | head -n 1)
        echo -e "${GREEN}git is installed: $git_version${RESET}"
    else
        echo -e "${YELLOW}git is not installed. Installing...${RESET}"
        install_git
    fi
}

install_git() {
    echo "Installing git..."
    sudo apt-get install git -y
}

# Function to check and install wget
check_wget() {
    if command -v wget &> /dev/null; then
        wget_version=$(wget --version | head -n 1)
        echo -e "${GREEN}wget is installed: $wget_version${RESET}"
    else
        echo -e "${YELLOW}wget is not installed. Installing...${RESET}"
        install_wget
    fi
}

install_wget() {
    echo "Installing wget..."
    sudo apt-get install wget -y
}

# Function to check and install curl
check_curl() {
    if command -v curl &> /dev/null; then
        curl_version=$(curl --version | head -n 1)
        echo -e "${GREEN}curl is installed: $curl_version${RESET}"
    else
        echo -e "${YELLOW}curl is not installed. Installing...${RESET}"
        install_curl
    fi
}

install_curl() {
    echo "Installing curl..."
    sudo apt-get install curl -y
}

# Function to check and install rust
check_rustc() {
    if command -v rustc &> /dev/null; then
        rustc_version=$(rustc --version | head -n 1)
        echo -e "${GREEN}rustc is installed: $rustc_version${RESET}"
    else
        echo -e "${YELLOW}rustc is not installed. Installing...${RESET}"
        install_rustc
    fi
}

install_rustc() {
    echo "Installing rustc..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs/ | sh -s -- -y
    source $HOME/.cargo/env
}

# Function to check and install tmux
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

# Install necessary packages
check_git
check_wget
check_curl
check_rustc
check_tmux

# Install Fuel
echo -e "${YELLOW}Installing Fuel...${RESET}"
curl https://install.fuel.network | sh

# Function to restart the current shell
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
}

# Clone Fuel chain configuration repository
echo -e "${YELLOW}Cloning Fuel chain configuration...${RESET}"
git clone https://github.com/FuelLabs/chain-configuration.git

# Move everything from the cloned directory to the current directory
echo -e "${YELLOW}Moving files from 'chain-configuration' to current directory...${RESET}"
mv chain-configuration/* ./
rm -rf chain-configuration  # Clean up by removing the empty directory

# Function to get peer_id
get_peer_id() {
    read -p "Do you already have a peer_id? (yes/no): " has_peer_id

    if [ "$has_peer_id" = "no" ]; then
        echo -e "${YELLOW}Generating new peer_id...${RESET}"
        # Generate peer ID and extract it from the output
        peer_id_output=$(fuel-core-keygen new --key-type peering)
        # Extract peer_id using grep, assuming it's in the output as 'PeerId: ...'
        secret=$(echo "$peer_id_output" | grep -oP '(?<=PeerId: )[A-Za-z0-9]+')
        echo -e "${GREEN}Your new peer_id is: $secret${RESET}"
        echo "Please write down your peer_id."
        sleep 5
    elif [ "$has_peer_id" = "yes" ]; then
        read -p "Please enter your peer_id: " secret
        echo -e "${GREEN}Your peer_id has been stored in the variable 'secret'.${RESET}"
    else
        echo -e "${RED}Invalid input. Please type 'yes' or 'no'.${RESET}"
    fi
}

# Run the function to get peer_id
get_peer_id

# Set ulimit
ulimit -S -n 32768

# Get user input for node name and Sepolia RPC
read -p "Enter node name: " nodeName
read -p "Enter Sepolia RPC: " RPC

# Create and save the fuel core command
cat <<EOT > /tmp/fuel_core_command.sh
#!/bin/bash
fuel-core run \
--enable-relayer \
--service-name=${nodeName}  \
--keypair $secret \
--relayer  $RPC  \
--ip=0.0.0.0 --port 4000 --peering-port 30333 \
--db-path ~/.fuel-mainnet \
--snapshot ignition/ \
--utxo-validation --poa-instant false --enable-p2p \
--bootstrap-nodes /dnsaddr/mainnet.fuel.network \
--sync-header-batch-size 100 \
--relayer-v2-listening-contracts=0xAEB0c00D0125A8a788956ade4f4F12Ead9f65DDf \
--relayer-da-deploy-height=20620434 \
--relayer-log-page-size=100 \
--sync-block-stream-buffer-size 30
EOT

# Make the script executable
chmod +x /tmp/fuel_core_command.sh

# Start a new tmux session and run the script
SESSION_NAME="my_tmux_session"
tmux new-session -d -s $SESSION_NAME "/tmp/fuel_core_command.sh"

# Attach to the tmux session
echo -e "${YELLOW}Attaching to tmux session...${RESET}"
tmux attach-session -t $SESSION_NAME

