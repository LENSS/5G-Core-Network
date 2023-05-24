#!/bin/bash 

SCRIPT_DIR=$(dirname $(readlink -f $0))
RUN_BG_PROCESS=$SCRIPT_DIR/run-bg-process.sh

# Create virtual IP addresses
sudo ip addr add 192.168.2.170/24 br 192.168.2.255 dev enp0s8 || true # for UPF
sudo ip addr add 192.168.2.179/24 br 192.168.2.255 dev enp0s8 || true # for UPF
sudo ip addr add 192.168.2.171/24 br 192.168.2.255 dev enp0s8 || true # for UE
sudo ip add show dev enp0s8 || true

# IPSec tunnel configuration
# Delete existing tunnel (if any)
sudo ip link del ipsec0 || true
# sudo ip link add ipsec0 type vti local 192.168.2.179 remote 192.168.2.171 key 5 || true
# sudo ip addr add 10.0.0.1/24 dev ipsec0 || true
# sudo ip link set ipsec0 up || true

# Configure routing
sudo sysctl -w net.ipv4.ip_forward=1 || true
sudo iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE || true
sudo systemctl stop ufw || true

# OGS Tun interface configuration
sudo ip tuntap add name ogstun mode tun || true
sudo ip addr add 10.45.0.1/16 dev ogstun || true
sudo ip link set ogstun up
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE


$RUN_BG_PROCESS -k # Kill any existing background processes
$RUN_BG_PROCESS -x # Clean any dead background processes

# Start Open5GS NFs (in background)
nfs=("nrf" "amf" "ausf" "udm" "udr" "pcf" "smf" "nssf" "bsf" "upf" "mme" "scp" "sgwc" "sgwu" "hss" "pcrf")
fivegnfs=("nrf" "amf" "ausf" "udm" "udr" "pcf" "smf" "nssf" "bsf" "upf")

for nf in "${nfs[@]}"
do
    if [[ " ${fivegnfs[@]} " =~ " ${nf} " ]]; then
        echo "Starting Open5GS 5G $nf..."
        $RUN_BG_PROCESS -n ${nf} --c /home/mbroner/open5gs/install/bin/open5gs-${nf}d -c /home/mbroner/open5gs/install/etc/open5gs/${nf}.yaml
    else
        echo "Starting Open5GS 4G $nf..."
        $RUN_BG_PROCESS -n ${nf} --c /home/mbroner/open5gs/install/bin/open5gs-${nf}d -c /home/mbroner/open5gs/install/etc/open5gs/${nf}.yaml
    fi
done

# Run N3IWF
cd /home/mbroner/free5gc
# Remove existing xfrmi-default interface (if any)
sudo ip link del xfrmi-default || true
$RUN_BG_PROCESS -n n3iwf --c ./bin/n3iwf -c ./config/n3iwfcfg.yaml

# Get status of Open5GS 5G NFs
$RUN_BG_PROCESS
