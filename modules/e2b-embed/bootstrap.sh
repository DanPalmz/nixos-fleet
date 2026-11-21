#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# This runs inside Ubuntu, never in the NixOS host namespace.
if ! docker compose version >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl gnupg iptables rsync e2fsprogs iproute2
  install -m 0755 -d /etc/apt/keyrings
  curl --fail --location --retry 5 https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker.sources <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

install -d -m 0700 /opt/e2b
cd /opt/e2b
# Download the pair together. Never replace an existing deployment on reboot.
if [ ! -f .download-complete ]; then
  for file in compose.yaml .env; do
    curl --fail --location --retry 5 \
      "https://raw.githubusercontent.com/e2b-dev/runtime/@runtimeRevision@/embed/compose/$file" \
      -o "$file.tmp"
  done
  mv compose.yaml.tmp compose.yaml
  mv .env.tmp .env
  touch .download-complete
fi
# This also restores transient host setup after every guest reboot.
docker compose config --quiet
exec docker compose up -d --wait --wait-timeout 1800
