# Makefile to run integrated 5G core network
# Commands are validate, init, init-mongodb, start, stop

# Set the shell to bash always
SHELL := /bin/bash

# Set the default target to init
.DEFAULT_GOAL := init

# Get OS
OS := $(shell grep  -oP '^ID=\K\w+' /etc/os-release)

OPEN5GS_REQS_UBUNTU := python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libidn11-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson
OPEN5GS_REQS_ARCH := python-pip python-setuptools python-wheel ninja base-devel flex bison git cmake lksctp-tools libgcrypt openssl libidn mongo-c-driver libyaml libnghttp2 libmicrohttpd curl libnghttp2 talloc meson 

# Install MongoDB
init-mongodb:
	@if [ $(OS) == "ubuntu" ]; then \
			sudo apt install gnupg; \
			curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor; \
			sudo apt-get install -y mongodb && sudo apt-get update && sudo systemctl start mongodb && sudo systemctl enable mongodb; \
	elif [ $(OS) == "arch" ]; then \
		sudo pacman -S gnupg; \
		curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor; \
		sudo pacman -S mongodb-bin && sudo pacman -Syu && sudo systemctl start mongod && sudo systemctl enable mongod; \
	else \
		echo "Unsupported OS. Please install the MongoDB PGP key manually and try again." \
		exit 1; \
	fi

# Validate Command
validate:
	@echo "Validating system requirements"
	@which go > /dev/null || (echo "Go is not installed. Please install Go and try again" && exit 1)
	@systemctl is-active --quiet mongodb || (echo "MongoDB is not running. Please start MongoDB and try again" && exit 1)
	@which python3 > /dev/null || (echo "Python3 is not installed. Please install Python3 and try again" && exit 1)
	@which node > /dev/null || (echo "NodeJS is not installed. Please install NodeJS (preferrably with NVM) and try again" && exit 1)
	@echo "System requirements validated"
	

# Init Command
init:
	@echo "Initializing 5G core network"
	@echo "Installing Open5GS requirements"
	@if [ $(OS) == "ubuntu" ]; then \
			sudo apt-get update && sudo apt-get install -y $(OPEN5GS_REQS_UBUNTU); \
		elif [ $(OS) == "arch" ]; then \
			sudo pacman -Syu --overwrite "*" && sudo pacman -S $(OPEN5GS_REQS_ARCH); \
		else \
			echo "Unsupported OS. Please install the requirements manually and try again"; \
			exit 1; \
		fi
	@echo "Cloning submodules"
	@git submodule update --init --recursive
	@echo "Building Free5GC N3IWF"
	@cd free5gc && cd NFs/n3iwf && git pull origin main && cd .. && make n3iwf
	@echo "Building Open5GS"
	@cd open5gs && git pull origin main && git checkout free5gc-n3iwf-cc && git pull origin free5gc-n3iwf-cc && meson build --prefix=`pwd`/install && ninja -C build && cd build && ninja install
	@cd open5gs && cp configs/stable-configs/* install/etc/open5gs/

# Start Command
start:
	@echo "Starting 5G core network"
	$(SHELL) ./script/run-open5gs.sh

stop:
	@echo "Stopping 5G core network"
	$(SHELL) ./script/run-bg-process.sh -k && $(SHELL) ./script/run-bg-process.sh -x



	