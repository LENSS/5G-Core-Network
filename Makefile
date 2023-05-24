# Makefile to run integrated 5G core network
# Commands are validate, init, start, stop, clean

# Set the shell to bash always
SHELL := /bin/bash

# Set the default target to init
.DEFAULT_GOAL := init

OPEN5GS_REQS_UBUNTU_INSTALL := $(shell sudo apt install python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libidn11-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson)

# Validate Command
validate:
	@echo "Validating system requirements"
	@which go > /dev/null || (echo "Go is not installed. Please install Go and try again" && exit 1)
	@systemctl is-active --quiet mongodb || (echo "MongoDB is not running. Please start Docker and try again" && exit 1)
	@which python3 > /dev/null || (echo "Python3 is not installed. Please install Python3 and try again" && exit 1)
	

# Init Command
init:
	@echo "Initializing 5G core network"
	@echo "Installing Open5GS requirements"
	@which apt > /dev/null && $(OPEN5GS_REQS_UBUNTU_INSTALL)
	@echo "Cloning submodules"
	@git submodule update --init --recursive
	@echo "Building Free5GC N3IWF"
	@cd free5gc && make n3iwf
	@echo "Building Open5GS"
	@cd open5gs && meson build --prefix=`pwd`/install && ninja -C build
	@echo "Building Open5GS WebUI"
	@cd open5gs/webui && npm install && npm run dev

# Start Command
start:
	@echo "Starting 5G core network"
	$SHELL ./script/run-open5gs.sh


	