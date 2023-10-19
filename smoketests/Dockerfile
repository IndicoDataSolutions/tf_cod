# set base image (host OS)
FROM ubuntu:22.04

WORKDIR /app
ADD . /app

#RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Installing prerequisite packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends tzdata && \
    apt-get -yqq --no-install-recommends install wget curl unzip groff gpg sudo less openssl python3 python3-pip postgresql jq && ln -sf python3 /usr/bin/python && pip3 install --no-cache --upgrade pip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && \
    curl -LO https://dl.k8s.io/release/v1.25.14/bin/linux/amd64/kubectl && \
    chmod +x kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    wget https://aka.ms/downloadazcopy-v10-linux -O - | tar -xz --strip-components=1 && chmod 755 ./azcopy && \
    cp ./azcopy /usr/local/bin && \
    pip3 install azure-cli && \
    sudo -v ; curl https://rclone.org/install.sh | sudo bash && \
    rm -rf /var/lib/apt/lists/*

RUN pip install -r requirements.txt



