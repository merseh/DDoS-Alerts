#!/bin/bash

# Make sure script is run as root user
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 
  exit 1
fi

# Prompt user to enter network interface name
read -p "Enter network interface name: " interface

# Check if interface exists
if ! ip link show $interface >/dev/null 2>&1; then
  echo "Invalid interface name"
  exit 1
fi

# Prompt user to enter Discord webhook URL and store it in a file
read -p "Enter Discord webhook URL: " webhook_url
echo "$webhook_url" > /root/.discord_webhook

# Set permissions for the file
chmod 600 /root/.discord_webhook

# Set directory for packet dumps
dumpdir=/tmp/

while true; do
  # Get number of packets transmitted in the last second
  pkt_old=$(awk '/'$interface':/ {print $2}' /proc/net/dev)
  sleep 1
  pkt_new=$(awk '/'$interface':/ {print $2}' /proc/net/dev)
  pkt=$((pkt_new-pkt_old))

  # Clear the screen
  clear

  # Print number of packets per second
  echo -ne "$pkt packets/s\033[0K"

  # If more than 15000 packets per second are being transmitted, alert Discord webhook
  if [[ $pkt -gt 15000 ]]; then
    echo -e "\n$(date) Under attack, dumping packets."

    # Dump packets and store in a file
    tcpdump -n -s0 -c 2000 -w $dumpdir/dump_$(date +"%Y%m%d-%H%M%S").cap host not $interface >/dev/null 2>&1

    # Send message to Discord webhook
    msg_content="Dumping $pkt packets/s"
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$msg_content\"}" "$(cat /root/.discord_webhook)"
    
    # Wait for 5 minutes before checking packets again
    echo "$(date) Just got hit. Sleeping for 5 minutes."
    sleep 300
  fi
done
