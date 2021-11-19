#!/bin/bash
#
# Create AWS Site-ti-Site VPN verification environment

########################################
# Create verification environment
########################################

# Supported Regions
# - us-east-1
# - ap-northeast-1
# - ap-northeast-3

# CloudFormation Parameters
CFN_TEMPLATE_FILE="test-s2svpn.yml"
CFN_STACK_NAME="test-s2svpn"
PREFIX="test-s2svpn"
SSH_CLIENT_IP="$(curl -s checkip.amazonaws.com)/32"
KEY_PAIR_NAME="TestMyKeyPair"

# Create a stack
echo "create-stack"
aws cloudformation create-stack \
--template-body file://$(pwd)/${CFN_TEMPLATE_FILE} \
--stack-name ${CFN_STACK_NAME} \
--parameters \
ParameterKey=Prefix,ParameterValue=${PREFIX} \
ParameterKey=TestMyClientIp,ParameterValue=${SSH_CLIENT_IP} \
ParameterKey=TestMyKeyPairName,ParameterValue=${KEY_PAIR_NAME}

echo "wait stack-create-complete"
aws cloudformation wait stack-create-complete \
--stack-name ${CFN_STACK_NAME} 


########################################
# Generate a customer gateway config file
########################################

CGW_NAME=cgw-"${PREFIX}"
VPN_CONNECTION_NAME=vpn-"${PREFIX}"
# device-id-type required for the customer gateway configuration template
# - b556dcd1 ASA 5500 ASA9.7+ VTI
# - 7b754310 CSRv AMI IOS 12.4+ <<
# - b0adb196 ISR IOS 12.4+
VPN_CONNECTION_DEVICE_TYPE_ID="7b754310"

VPN_CONNECTION_ID=$(aws ec2 describe-vpn-connections \
--filters "Name=tag:Name,Values=${VPN_CONNECTION_NAME}" \
          "Name=state,Values=available" \
--query 'VpnConnections[].VpnConnectionId' \
--output text)

aws ec2 get-vpn-connection-device-sample-configuration \
--vpn-connection-id ${VPN_CONNECTION_ID} \
--vpn-connection-device-type-id ${VPN_CONNECTION_DEVICE_TYPE_ID} \
--output text > cgw.conf.org

# Generate Cisco IOS configuration
echo "conf t" > cgw.conf

CGW_PRIVATE_IP=$(aws ec2 describe-instances \
--filters "Name=tag:Name,Values=${CGW_NAME}" \
          "Name=instance-state-name,Values=running" \
--query 'Reservations[].Instances[].PrivateIpAddress' --output text)

cat cgw.conf.org |
sed "s/\<interface_name\/private_IP_on_outside_interface\>/${CGW_PRIVATE_IP}/" |
grep -v '[!|]' |
grep -v ^$ >> cgw.conf

aws ec2 describe-vpn-connections \
--filters "Name=tag:Name,Values=${VPN_CONNECTION_NAME}" \
          "Name=state,Values=available" \
--query 'VpnConnections[].CustomerGatewayConfiguration' \
--output text |
grep 169.254 |
xargs -n 2 |
sed 's/<\/*ip_address>//g' |
awk '{print $2}' > bgp-neigh-ip.tmp

BGP_NEIGH_IP1=$(awk 'NR==1' bgp-neigh-ip.tmp)
BGP_NEIGH_IP2=$(awk 'NR==2' bgp-neigh-ip.tmp)

cat << EOS >> cgw.conf
clock timezone JST 9
hostname ${CGW_NAME}
ip route 10.1.0.0 255.255.0.0 null0 200
ip prefix-list CGW_LOCAL seq 10 permit 10.1.0.0/16
router bgp 65000
  address-family ipv4 unicast
    no network 192.168.100.0 mask 255.255.255.0
    no neighbor ${BGP_NEIGH_IP1} ebgp-multihop 255
    no neighbor ${BGP_NEIGH_IP2} ebgp-multihop 255
    network 10.1.0.0 mask 255.255.0.0
    neighbor ${BGP_NEIGH_IP1} prefix-list CGW_LOCAL out
    neighbor ${BGP_NEIGH_IP1} soft-reconfiguration inbound
    neighbor ${BGP_NEIGH_IP2} prefix-list CGW_LOCAL out
    neighbor ${BGP_NEIGH_IP2} soft-reconfiguration inbound
    exit-address-family
  exit
exit

# Get logs
terminal length 0
show crypto session
show crypto ikev2 sa | in ^[12]|^Tunnel-id
show crypto ipsec sa | in ^interface|esp sas|Status
show ip route | in ^Gateway|/
show ip bgp summary | in ^Neighbor|^${BGP_NEIGH_IP1}|^${BGP_NEIGH_IP2}
show ip bgp neighbors ${BGP_NEIGH_IP1} advertised-routes | in Network|/
show ip bgp neighbors ${BGP_NEIGH_IP1} received-routes | in Network|/
show ip bgp neighbors ${BGP_NEIGH_IP2} advertised-routes | in Network|/
show ip bgp neighbors ${BGP_NEIGH_IP2} received-routes | in Network|/
terminal no length

# Send a ping from CSR1000V to Amazon Linux 2 via Site-to-Site VPN
ping 10.0.0.10 source 10.1.0.10

EOS


# How to set up the customer gateway

echo "Public IP address of the customer gateway"
aws ec2 describe-instances \
--filters "Name=instance-state-name,Values=running" \
--query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value,PublicIpAddress]' \
--output text |
xargs -n 2 | grep ${CGW_NAME}

echo "1. SSH login to the customer gateway as ec2-user."
echo "2. Copy the commands from cgw.conf and paste them into the terminal of the customer gateway."
