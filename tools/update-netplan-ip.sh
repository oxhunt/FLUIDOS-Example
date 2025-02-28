#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <integer>"
  exit 1
fi

# Check if the argument is an integer in the range 0-255
if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 0 ] || [ "$1" -gt 255 ]; then
  echo "Error: Argument must be an integer in the range 0-255"
  exit 1
fi

# Set the integer
INTEGER=$1

# Define the file path
FILE="/etc/netplan/50-cloud-init.yaml"

# Use sed to replace the line containing the IP address
sudo sed -i "s/        - 192.168.11\.[0-9]\{1,3\}\/26/        - 192.168.11.$INTEGER\/26/" "$FILE"

echo "Updated IP address to 192.168.11.$INTEGER/26 in $FILE"
sudo netplan generate
sudo netplan apply