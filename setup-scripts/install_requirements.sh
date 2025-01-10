# Update the package list
echo "updating package list"
sudo apt update &>/dev/null

# Install the required packages
echo "installing required packages"
sudo apt install -y curl gpg docker-buildx &>/dev/null
curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt install apt-transport-https --yes &>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list &>/dev/null

# Update the package list again
sudo apt update &>/dev/null

# Install Helm
sudo apt install -y helm &>/dev/null

# disable firewall to avoid problems down the road, we don't need security right now
sudo ufw disable &>/dev/null

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker