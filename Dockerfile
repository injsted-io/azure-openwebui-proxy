# Dockerfile
FROM ghcr.io/open-webui/open-webui:main

# Install ripgrep via the distro’s package manager
USER root
RUN apt-get update \
 && apt-get install -y ripgrep \
 && rm -rf /var/lib/apt/lists/*

