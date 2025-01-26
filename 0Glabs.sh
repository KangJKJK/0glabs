#!/bin/bash

# 컬러 정의
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'  # No Color

# RPC 관련 환경변수 정의
export RPC_CHOICE=""  # RPC 선택 옵션 (1,2,3)
export RPC_URL=""    # 선택된 RPC 엔드포인트 URL

# 사용자에게 선택지를 제공
echo "다음 중 하나를 선택하세요. 각 과정은 서로 다른 스크린에서 실행시키세요:"
echo "1) Storage 노드 설치 및 구동"
echo "2) DA 노드 설치 및 구동"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${NC}"

read -p "선택 (1/2): " NODE_CHOICE

case $NODE_CHOICE in
    1)
        echo "Storage 노드 설치 및 구동을 선택하셨습니다."
        # 1. 패키지 업데이트 및 필수 패키지 설치
        echo -e "${GREEN}패키지 업데이트 중...${NC}"
        sudo apt-get update
        
        echo -e "${GREEN}필수 패키지 설치 중...${NC}"
        read -p "설치하려는 패키지들에 대한 권한을 부여하려면 Enter를 누르세요..."
        sudo apt-get install -y clang cmake build-essential
        
        echo -e "${GREEN}git 설치 중...${NC}"
        sudo apt update && sudo apt install git -y
        
        echo -e "${GREEN}stdbuf 설치 중...${NC}"
        sudo apt-get install coreutils -y
        
        echo -e "${GREEN}rustup 설치 중...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        # Go 설치
        if ! command -v go &> /dev/null; then
            echo -e "${GREEN}Go 다운로드 중...${NC}"
            wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
            
            echo -e "${GREEN}Go 설치 후, 경로 추가 중...${NC}"
            rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
            export PATH=$PATH:/usr/local/go/bin
            echo "PATH=$PATH"
        else
            echo -e "${GREEN}Go가 이미 설치되어 있습니다.${NC}"
        fi
        sleep 2

        # Rust 설치 확인
        echo -e "${YELLOW}Rust 설치 확인 중...${NC}"
        if command -v rustc >/dev/null 2>&1; then
            echo -e "${GREEN}Rust가 이미 설치되어 있습니다. 버전:${NC}"
            rustc --version
        else
            echo -e "${YELLOW}Rust를 설치합니다...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        fi

        # 0g-storage-node 디렉토리 제거 및 리포지토리 클론
        if [ -d "$HOME/0g-storage-node" ]; then
            echo -e "${YELLOW}디렉토리 $HOME/0g-storage-node 가 이미 존재합니다. 삭제 중...${NC}"
            sudo rm -rf $HOME/0g-storage-node
        fi

        echo -e "${GREEN}0g-storage-node 리포지토리 클론 중...${NC}"
        git clone -b v0.8.3 https://github.com/0glabs/0g-storage-node.git

        # 0g-storage-node 디렉토리로 이동
        echo -e "${YELLOW}디렉토리 이동 시도 중...${NC}"
        cd $HOME/0g-storage-node || { echo -e "${RED}디렉토리 이동 실패${NC}"; exit 1; }
        echo -e "${GREEN}현재 디렉토리: $(pwd)${NC}"

        # 이후 명령어 실행
        echo -e "${YELLOW}특정 커밋 체크아웃 중...${NC}"
        git stash && git fetch --all --tags && git checkout 052d2d7

        echo -e "${GREEN}git 서브모듈 초기화 중...${NC}"
        git submodule update --init

        # Cargo 관련 작업
        echo -e "${YELLOW}Cargo 삭제 중...${NC}"
        sudo apt-get remove --purge -y cargo

        echo -e "${GREEN}Cargo 설치 중...${NC}"
        sudo apt install -y cargo
        
        echo -e "${YELLOW}필요한 패키지 설치 중...${NC}"
        sudo apt update
        sudo apt install pkg-config
        sudo apt install libssl-dev
        
        echo -e "${GREEN}Rust 업데이트 중...${NC}"
        sudo rustup update
        
        echo -e "${YELLOW}Cargo 캐시 정리 중...${NC}"
        sudo cargo clean

        # Cargo 빌드
        if [ "$(pwd)" != "$HOME/0g-storage-node" ]; then
            echo -e "${RED}오류: 현재 디렉토리가 $HOME/0g-storage-node가 아닙니다.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Cargo 빌드 중...${RED}(시간이 오래 걸립니다)${NC}"
        sudo cargo build --release
        echo -e "${GREEN}0g-storage-node 빌드 완료.${NC}"
        sleep 2

        # config 파일 관련 작업
        echo -e "${YELLOW}config파일 삭제 중...${NC}"
        sudo rm -rf $HOME/0g-storage-node/run/config.toml
        
        echo -e "${GREEN}config파일 다운로드 중...${NC}"
        sudo curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/z8000kr/0g-storage-node/main/run/config.toml

        # config.toml 파일 수정
        echo -e "${GREEN}config파일 수정 중...${NC}"

        # config 파일 경로 정의
        CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"

        # 파일 권한 설정
        chmod u+rw $CONFIG_FILE

        # 기존 설정이 있는지 확인하고, 있으면 제거
        echo -e "${YELLOW}기존 설정 제거 중...${NC}"
        sed -i '/log_contract_address = /d' $CONFIG_FILE
        sed -i '/log_sync_start_block_number = /d' $CONFIG_FILE
        sed -i '/confirmation_block_count = /d' $CONFIG_FILE
        sed -i '/mine_contract_address = /d' $CONFIG_FILE
        sed -i '/auto_sync_enabled = /d' $CONFIG_FILE
        sed -i '/reward_contract_address = /d' $CONFIG_FILE

        # 새로운 설정 추가
        echo -e "${GREEN}새로운 설정 추가 중...${NC}"
        sed -i '/# Flow contract address to sync event logs./a log_contract_address = "0xbD2C3F0E65eDF5582141C35969d66e34629cC768"' $CONFIG_FILE
        sed -i '/# the block number when flow contract deployed./a log_sync_start_block_number = 595059' $CONFIG_FILE
        sed -i '/# Number of blocks to confirm a transaction./a confirmation_block_count = 6' $CONFIG_FILE
        sed -i '/# Mine contract address for incentive./a mine_contract_address = "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f"' $CONFIG_FILE
        sed -i '/# all files, and sufficient disk space is required./a auto_sync_enabled = true' $CONFIG_FILE
        sed -i '/# shard_position = "0\/2"/a reward_contract_address = "0x51998C4d486F406a788B766d93510980ae1f9360"' $CONFIG_FILE

        echo -e "${GREEN}계약 주소 및 기타 설정 업데이트 완료${NC}"

        # 기존 네트워크 부트 노드가 있는지 확인하고, 있으면 제거
        sed -i '/network_boot_nodes = \[/d' $CONFIG_FILE
        sed -i '/# configured as well to enable UDP discovery./a network_boot_nodes = ["/ip4/54.219.26.22/udp/1234/p2p/16Uiu2HAmTVDGNhkHD98zDnJxQWu3i1FL1aFYeh9"]' $CONFIG_FILE

        # 프로필 설정
        echo -e "${YELLOW}프로필 설정을 시작합니다...${NC}"
        echo -e "${GREEN}메타마스크 프라이빗키를 입력하세요:${NC}"
        read -p ": " MINER_KEY
        sed -i "s|^miner_key = \".*\"|miner_key = \"$MINER_KEY\"|" $CONFIG_FILE

        # RPC 엔드포인트 선택
        echo -e "${YELLOW}다음 중 하나의 RPC 엔드포인트를 선택하세요:${NC}"
        echo "1) https://evmrpc-testnet.0g.ai/"
        echo "2) https://rpc.ankr.com/0g_newton/"
        echo "3) https://16600.rpc.thirdweb.com/"

        read -p "선택 (1/2/3): " RPC_CHOICE

        case $RPC_CHOICE in
            1) export RPC_URL="https://evmrpc-testnet.0g.ai/" ;;
            2) export RPC_URL="https://rpc.ankr.com/0g_newton/" ;;
            3) export RPC_URL="https://16600.rpc.thirdweb.com/" ;;
            *) echo -e "${RED}잘못된 선택입니다. 다시 시도하세요.${NC}" && exit 1 ;;
        esac

        # 기존 RPC 설정이 있는지 확인하고, 있으면 제거
        sed -i '/blockchain_rpc_endpoint = /d' $CONFIG_FILE

        # RPC 업데이트
        sed -i "/# RPC endpoint to sync event logs on EVM compatible blockchain./a blockchain_rpc_endpoint = \"$RPC_URL\"" $CONFIG_FILE

        echo -e "${GREEN}RPC 엔드포인트가 $RPC_URL으로 설정되었습니다.${NC}"

        # zgs.service 파일 생성
        echo -e "${YELLOW}zgs.service 파일 생성 중...${NC}"
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

        # UFW 설정
        echo -e "${GREEN}UFW 설치 중...${NC}"
        sudo apt-get install -y ufw
        
        echo -e "${YELLOW}UFW 활성화 중...반응이 없으면 엔터를 누르세요.${NC}"
        sudo ufw enable
        
        echo -e "${GREEN}필요한 포트 개방 중...${NC}"
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

        # Systemd 서비스 설정
        echo -e "${YELLOW}Systemd 서비스 재로드 중...${NC}"
        sudo systemctl daemon-reload
        
        echo -e "${GREEN}zgs 서비스 활성화 중...${NC}"
        sudo systemctl enable zgs
        
        echo -e "${YELLOW}zgs 서비스 시작 중...${NC}"
        sudo systemctl start zgs
        sleep 5

        echo -e "${RED}https://faucet.0g.ai/ 에서 반드시 포셋을 받아주세요.${NC}"
        echo -e "${GREEN}1.로그 체크${NC}"
        echo -e "${GREEN}tail -f ~/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d)${NC}"
        echo -e "${GREEN}2.블록싱크 체크${NC}"
        echo -e "${GREEN}source <(curl -s https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/zgs_test.sh)${NC}"
        read -p "위 체크 명령어들을 기록해두세요.(엔터): "
        ;;

    2)
        echo "DA 노드 설치 및 구동을 선택하셨습니다."
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

        # Rust 설치
        execute_with_prompt "Rust 설치 확인 중..." "
        if command -v rustc >/dev/null 2>&1; then
            echo 'Rust가 이미 설치되어 있습니다. 버전:'
            rustc --version
        else
            echo 'Rust를 설치합니다...'
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        fi
        "

        # Git 클론
        git clone -b v1.1.3 https://github.com/0glabs/0g-da-node.git

        # 프로잭트 빌드
        cd $HOME/0g-da-node
        git stash
        git fetch --all --tags
        git checkout 9a48827 
        git submodule update --init
        cargo build --release

        # 매개변수 다운로드
        ./dev_support/download_params.sh

        # 키젠 바이너리를 사용하여 키생성
        cargo run --bin key-gen
        read -p "BLS 키를 입력하세요: " BLS
        read -p "현재 VPS의 IP를 입력하세요: " DAIP
        read -p "개인키를 입력하세요: " PRIVATEKEY

        # 구성파일 편집
        rm -rf $HOME/0g-da-node/config.toml && curl -o $HOME/0g-da-node/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_da_config.toml && nano $HOME/0g-da-node/config.toml

        # config.toml 파일 수정
        echo -e "${GREEN}config파일 수정 중...${NC}"

        # config 파일 경로 정의
        CONFIG_FILE="$HOME/0g-da-node/config.toml"

        # 파일 권한 설정
        chmod u+rw $CONFIG_FILE

        # 설정 업데이트
        echo -e "${YELLOW}설정 업데이트 중...${NC}"
        sed -i "s|^socket_address = .*|socket_address = \"$DAIP:34000\"|" $CONFIG_FILE
        sed -i "s|^signer_bls_private_key = .*|signer_bls_private_key = \"$BLS\"|" $CONFIG_FILE
        sed -i "s|^signer_eth_private_key = .*|signer_eth_private_key = \"$PRIVATEKEY\"|" $CONFIG_FILE
        sed -i "s|^miner_eth_private_key = .*|miner_eth_private_key = \"$PRIVATEKEY\"|" $CONFIG_FILE

        # systemd 서비스 파일 생성

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

        # 로그 확인
        echo -e "${GREEN}sudo journalctl -u 0gda -f -o cat${NC}"
        read -p "위 로그 체크 명령어를 기록해두세요(엔터): "
        
        # 서비스 시작
        sudo systemctl daemon-reload && sudo systemctl enable 0gda && sudo systemctl start 0gda
        ;;

    *)
        echo "잘못된 선택입니다. 스크립트를 종료합니다."
        exit 1
        ;;
esac
