
# LENSS 5G-Core-Network

## What is the LENSS 5G-Core-Network?
This project presents the first widely available open-source 5G core network to combine the capabilities of [Open5GS](https://open5gs.org) and [Free5GC](https://free5gc.org). 

### Why combine both cores?
Open5GS allows the usage of both 4G-LTE and 5G-NSA network stacks, while Free5GC allows the usage of 5G-SA with non-3GPP access network based sessions (ie. MA-PDU sessions over multiple access networks concurrently). Our goal is to provide a solution that allows researchers complete flexibility when developing solutions for current and upcoming 3GPP deployments.

## Installation
1. Clone the repository at `https://github.com/LENSS/5G-Core-Network` being sure to clone recursively in order to clone both sub-projects for each core network.
``` 
git clone --recurse-submodules https://github.com/LENSS/5G-Core-Network.git
```
2.  Initialize the repository (ie. build and setup)
```
make validate
make init-mongodb
make init
```
* `make validate` ensures you have the correct versions of the various requirements of both core networks.
* `make init-mongodb` installs and starts the MongoDB daemon on your system.
* `make init` clones and builds both core networks and installs the correct configurations files we have prepared.

Note: You will need to update the configurations files for Open5GS and the Free5GC N3IWF with the IP addresses of your network interfaces.

## Running
Run `make start` to run both core networks, using our custom script `run-bg-process.sh` to use have them run in the background while storing their individual log files.

Note: update `/script/run-open5gs.sh` with the correct IP addresses of your network interfaces prior to starting the core network. The section that is important to update is for the creation of virtual IP addresses for your main network interface (ie. can reach the internet):
``` 
sudo ip addr add 192.168.2.170/24 br 192.168.2.255 dev ens160 || true # for UPF
sudo ip addr add 192.168.2.179/24 br 192.168.2.255 dev ens160 || true # for UPF
sudo ip addr add 192.168.2.171/24 br 192.168.2.255 dev ens160 || true # for UE
sudo ip add show dev ens160 || true
```

## Stopping the Core
Run `make stop` to terminate the core network.

## Network Function Logs
Use the `/script/run-bg-process.sh` to tail the logs of each network function. For example, to see all running processes, run:
``` 
run-bg-process.sh 
```
To see the logs of a given running process by name, run:
``` 
run-bg-process.sh -l -n [PROCESS_NAME]
```
