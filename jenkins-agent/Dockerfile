# Image Jenkins agent dynamique : Docker + Python + Java + Git
FROM jenkins/inbound-agent:latest-jdk17

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker jenkins 2>/dev/null || true

USER jenkins
