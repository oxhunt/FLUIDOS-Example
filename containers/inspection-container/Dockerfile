# Use the official Ubuntu 22.04 image as the base image
FROM ubuntu:24.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install utilities
RUN apt-get update -y && dpkg --configure -a && apt upgrade -y 
RUN apt-get update && apt-get install -y \
    mosquitto-clients \
    curl \
    bash-completion \
    iputils-ping \
    net-tools 

# Installing helm
RUN curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null && \
    sudo apt install apt-transport-https --yes &>/dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list &>/dev/null && \
    sudo apt update &>/dev/null && \
    sudo apt install -y helm &>/dev/null
    
RUN apt-get update && apt-get install -y \
    iproute2 \
    dnsutils \
    jq \
    nano
    
# Install kubectl based on the architecture of the container
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install k9s based on the architecture of the container
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -LO "https://github.com/derailed/k9s/releases/download/v0.40.10/k9s_linux_amd64.deb" && \
        dpkg -i k9s_linux_amd64.deb && \
        rm k9s_linux_amd64.deb; \
    elif [ "$ARCH" = "arm64" ]; then \
        curl -LO "https://github.com/derailed/k9s/releases/download/v0.40.10/k9s_linux_arm64.deb" && \
        dpkg -i k9s_linux_arm64.deb && \
        rm -rf k9s_linux_arm64.deb; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi


# setup .bashrc
RUN echo "source /usr/share/bash-completion/bash_completion" >> /root/.bashrc
RUN echo "source <(kubectl completion bash)" >> /root/.bashrc
RUN echo "source <(k9s completion bash)" >> /root/.bashrc; \
    echo 'alias k=kubectl' >> "/root/.bashrc"; \
    echo 'complete -F __start_kubectl k' >> "/root/.bashrc"

# customize the shell prompt to make the container more identifiable, it should contain the name of the container, colored in red
RUN echo 'export PS1="\[\033[01;31m\]inspection-container\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

#RUN echo "source <(helm completion bash)" >> /root/.bashrc

# set the container to run indeterminately
CMD ["tail", "-f", "/dev/null"]


