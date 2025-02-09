#!/bin/bash

# Define colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'  # No Color

# Define RPC related environment variables
export RPC_CHOICE=""  # RPC selection option (1,2,3)
export RPC_URL=""    # Selected RPC endpoint URL

# Provide options to the user
echo "Please select one of the following. Each process should be run on a different screen:"
echo "1) Install and run Storage node"
echo "2) Install and run DA node"
echo -e "${GREEN}Script Author - https://t.me/kjkresearch${NC}"

read -p "Choice (1/2): " NODE_CHOICE

case $NODE_CHOICE in
    1)
        echo "You have selected to install and run the Storage node."
        # 1. Update packages and install essential packages
        echo -e "${GREEN}Updating packages...${NC}"
        sudo apt-get update
        
        echo -e "${GREEN}Installing essential packages...${NC}"
        read -p "Press Enter to grant permission for the packages you want to install..."
        sudo apt-get install -y clang cmake build-essential
        
        echo -e "${GREEN}Installing git...${NC}"
        sudo apt update && sudo apt install git -y
        
        echo -e "${GREEN}Installing stdbuf...${NC}"
        sudo apt-get install coreutils -y
        
        echo -e "${GREEN}Installing rustup...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        # Install Go
        if ! command -v go &> /dev/null; then
            echo -e "${GREEN}Downloading Go...${NC}"
            wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
            
            echo -e "${GREEN}Installing Go and adding to path...${NC}"
            rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
            export PATH=$PATH:/usr/local/go/bin
            echo "PATH=$PATH"
        else
            echo -e "${GREEN}Go is already installed.${NC}"
        fi
        sleep 2

        # Check Rust installation
        echo -e "${YELLOW}Checking Rust installation...${NC}"
        if command -v rustc >/dev/null 2>&1; then
            echo -e "${GREEN}Rust is already installed. Version:${NC}"
            rustc --version
        else
            echo -e "${YELLOW}Installing Rust...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        fi

        # Remove 0g-storage-node directory and clone repository
        if [ -d "$HOME/0g-storage-node" ]; then
            echo -e "${YELLOW}Directory $HOME/0g-storage-node already exists. Removing...${NC}"
            sudo rm -rf $HOME/0g-storage-node
        fi

        echo -e "${GREEN}Cloning 0g-storage-node repository...${NC}"
        git clone -b v0.8.3 https://github.com/0glabs/0g-storage-node.git

        # Move to 0g-storage-node directory
        echo -e "${YELLOW}Attempting to change directory...${NC}"
        cd $HOME/0g-storage-node || { echo -e "${RED}Failed to change directory${NC}"; exit 1; }
        echo -e "${GREEN}Current directory: $(pwd)${NC}"

        # Execute subsequent commands
        echo -e "${YELLOW}Checking out specific commit...${NC}"
        git stash && git fetch --all --tags && git checkout 052d2d7

        echo -e "${GREEN}Initializing git submodules...${NC}"
        git submodule update --init

        # Cargo related tasks
        echo -e "${YELLOW}Removing Cargo...${NC}"
        sudo apt-get remove --purge -y cargo

        echo -e "${GREEN}Installing Cargo...${NC}"
        sudo apt install -y cargo
        
        echo -e "${YELLOW}Installing required packages...${NC}"
        sudo apt update
        sudo apt install pkg-config
        sudo apt install libssl-dev
        
        echo -e "${GREEN}Updating Rust...${NC}"
        sudo rustup update
        
        echo -e "${YELLOW}Cleaning Cargo cache...${NC}"
        sudo cargo clean

        # Cargo build
        if [ "$(pwd)" != "$HOME/0g-storage-node" ]; then
            echo -e "${RED}Error: Current directory is not $HOME/0g-storage-node.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Building Cargo...${RED}(This may take a long time)${NC}"
        sudo cargo build --release
        echo -e "${GREEN}0g-storage-node build complete.${NC}"
        sleep 2

        # Config file related tasks
        echo -e "${YELLOW}Removing config file...${NC}"
        sudo rm -rf $HOME/0g-storage-node/run/config.toml
        
        echo -e "${GREEN}Downloading config file...${NC}"
        sudo curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/z8000kr/0g-storage-node/main/run/config.toml

        # Modify config.toml file
        echo -e "${GREEN}Modifying config file...${NC}"

        # Define config file path
        CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"

        # Set file permissions
        chmod u+rw $CONFIG_FILE

        # Check for existing settings and remove if present
        echo -e "${YELLOW}Removing existing settings...${NC}"
        sed -i '/log_contract_address = /d' $CONFIG_FILE
        sed -i '/log_sync_start_block_number = /d' $CONFIG_FILE
        sed -i '/confirmation_block_count = /d' $CONFIG_FILE
        sed -i '/mine_contract_address = /d' $CONFIG_FILE
        sed -i '/auto_sync_enabled = /d' $CONFIG_FILE
        sed -i '/reward_contract_address = /d' $CONFIG_FILE

        # Add new settings
        echo -e "${GREEN}Adding new settings...${NC}"
        sed -i '/# Flow contract address to sync event logs./a log_contract_address = "0xbD2C3F0E65eDF5582141C35969d66e34629cC768"' $CONFIG_FILE
        sed -i '/# the block number when flow contract deployed./a log_sync_start_block_number = 595059' $CONFIG_FILE
        sed -i '/# Number of blocks to confirm a transaction./a confirmation_block_count = 6' $CONFIG_FILE
        sed -i '/# Mine contract address for incentive./a mine_contract_address = "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f"' $CONFIG_FILE
        sed -i '/# all files, and sufficient disk space is required./a auto_sync_enabled = true' $CONFIG_FILE
        sed -i '/# shard_position = "0\/2"/a reward_contract_address = "0x51998C4d486F406a788B766d93510980ae1f9360"' $CONFIG_FILE

        echo -e "${GREEN}Contract addresses and other settings updated${NC}"

        # Check for existing network boot nodes and remove if present
        sed -i '/network_boot_nodes = \[/d' $CONFIG_FILE
        sed -i '/# configured as well to enable UDP discovery./a network_boot_nodes = ["/ip4/47.251.117.133/udp/1234/p2p/16Uiu2HAmTVDGNhkHD98zDnJxQWu3i1FL1aFYeh9wiQTNu4pDCgps","/ip4/47.76.61.226/udp/1234/p2p/16Uiu2HAm2k6ua2mGgvZ8rTMV8GhpW71aVzkQWy7D37TTDuLCpgmX"]' $CONFIG_FILE

        # Profile settings
        echo -e "${YELLOW}Starting profile settings...${NC}"
        echo -e "${GREEN}Enter your Metamask private key:${NC}"
        read -p ": " MINER_KEY
        sed -i "s|^miner_key = \".*\"|miner_key = \"$MINER_KEY\"|" $CONFIG_FILE

        # Set RPC endpoint
        echo -e "${YELLOW}Setting RPC endpoint...${NC}"
        export RPC_URL="https://evmrpc-testnet.0g.ai/"
        
        # Other RPC options (for reference)
        # RPC option 2: https://rpc.ankr.com/0g_newton/
        # RPC option 3: https://16600.rpc.thirdweb.com/
        
        # Check for existing RPC settings and remove if present
        sed -i '/blockchain_rpc_endpoint = /d' $CONFIG_FILE

        # Update RPC
        sed -i "/# RPC endpoint to sync event logs on EVM compatible blockchain./a blockchain_rpc_endpoint = \"$RPC_URL\"" $CONFIG_FILE

        echo -e "${GREEN}RPC endpoint set to $RPC_URL.${NC}"

        # Create zgs.service file
        echo -e "${YELLOW}Creating zgs.service file...${NC}"
        sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

        # UFW settings
        echo -e "${GREEN}Installing UFW...${NC}"
        sudo apt-get install -y ufw
        
        echo -e "${YELLOW}Enabling UFW... Press Enter if there's no response.${NC}"
        sudo ufw enable
        
        echo -e "${GREEN}Opening necessary ports...${NC}"
        sudo ufw allow ssh
        sudo ufw allow 34000/tcp
        sudo ufw allow 26658/tcp
        sudo ufw allow 26656/tcp
        sudo ufw allow 6060/tcp
        sudo ufw allow 1317/tcp
        sudo ufw allow 9090/tcp
        sudo ufw allow 8545/tcp
        sudo ufw allow 9091/tcp
        sleep 2

        # Systemd service settings
        echo -e "${YELLOW}Reloading systemd services...${NC}"
        sudo systemctl daemon-reload
        
        echo -e "${GREEN}Enabling zgs service...${NC}"
        sudo systemctl enable zgs
        
        echo -e "${YELLOW}Starting zgs service...${NC}"
        sudo systemctl start zgs
        sleep 5

        echo -e "${RED}Please make sure to get the faucet from https://faucet.0g.ai/.${NC}"
        echo -e "${GREEN}1. Check logs${NC}"
        echo -e "${GREEN}tail -f ~/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d)${NC}"
        echo -e "${GREEN}2. Check block sync${NC}"
        echo -e "${GREEN}source <(curl -s https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/zgs_test.sh)${NC}"
        read -p "Please record the above check commands. (Enter): "
        ;;

    2)
        echo "You have selected to install and run the DA node."
        sudo apt-get update && sudo apt-get install clang cmake build-essential pkg-config libssl-dev protobuf-compiler llvm llvm-dev
        cd $HOME && \
        ver="1.23.3" && \
        wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
        sudo rm -rf /usr/local/go && \
        sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
        rm "go$ver.linux-amd64.tar.gz" && \
        echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile && \
        source ~/.bash_profile && \
        go version

        # Install Rust
        execute_with_prompt "Checking Rust installation..." "
        if command -v rustc >/dev/null 2>&1; then
            echo 'Rust is already installed. Version:'
            rustc --version
        else
            echo 'Installing Rust...'
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        fi
        "

        # Install Rust nightly version and set as default
        echo -e "${YELLOW}Installing Rust nightly version...${NC}"
        rustup install nightly
        rustup default nightly
        rustup update

        # Git clone
        git clone -b v1.1.3 https://github.com/0glabs/0g-da-node.git

        # Build project
        cd $HOME/0g-da-node
        git stash
        git fetch --all --tags
        git checkout 9a48827 
        git submodule update --init
        cargo build --release

        # Download parameters
        ./dev_support/download_params.sh

        # Use keygen binary to generate keys
        cargo run --bin key-gen
        read -p "Enter BLS key: " BLS
        read -p "Enter the IP of the current VPS: " DAIP
        read -p "Enter private key: " PRIVATEKEY

        # Edit configuration file
        rm -rf $HOME/0g-da-node/config.toml && curl -o $HOME/0g-da-node/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_da_config.toml

        # Modify config.toml file
        echo -e "${GREEN}Modifying config file...${NC}"

        # Define config file path
        CONFIG_FILE="$HOME/0g-da-node/config.toml"

        # Set file permissions
        chmod u+rw $CONFIG_FILE

        # Update settings
        echo -e "${YELLOW}Updating settings...${NC}"
        sed -i "s|^socket_address = .*|socket_address = \"$DAIP:34000\"|" $CONFIG_FILE
        sed -i "s|^signer_bls_private_key = .*|signer_bls_private_key = \"$BLS\"|" $CONFIG_FILE
        sed -i "s|^signer_eth_private_key = .*|signer_eth_private_key = \"$PRIVATEKEY\"|" $CONFIG_FILE
        sed -i "s|^miner_eth_private_key = .*|miner_eth_private_key = \"$PRIVATEKEY\"|" $CONFIG_FILE

        # Create systemd service file

        sudo tee /etc/systemd/system/0gda.service > /dev/null <<EOF
[Unit]
Description=0G-DA Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-da-node
ExecStart=$HOME/0g-da-node/target/release/server --config $HOME/0g-da-node/config.toml
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

        # Check logs
        echo -e "${GREEN}sudo journalctl -u 0gda -f -o cat${NC}"
        read -p "Please record the above log check command (Enter): "
        
        # Start service
        sudo systemctl daemon-reload && sudo systemctl enable 0gda && sudo systemctl start 0gda
        ;;

    *)
        echo "Invalid choice. Exiting script."
        exit 1
        ;;
esac
