#!/bin/bash
set -e
# ── Config ───────────────────────────────────────────────
BASE_DIR="/vagrant/.vagrant/machines"
NEW_KEY="/home/vagrant/.ssh/id_ed25519.pub"

NODES=("k8s-master" "worker1" "worker2" "worker3" "edge-gateway")

node_ip() {
  case "$1" in
    k8s-master)   echo "192.168.56.11" ;;
    worker1)      echo "192.168.56.12" ;;
    worker2)      echo "192.168.56.13" ;;
    worker3)      echo "192.168.56.14" ;;
    edge-gateway) echo "192.168.56.15" ;;
  esac
}

# ── Generar clave ────────────────────────────────────────
echo -e "🔐 Clave SSH de ansible-control"

if [ ! -f "/home/vagrant/.ssh/id_ed25519" ]; then
  echo -e " Generando clave ed25519..."
  ssh-keygen -t ed25519 -f /home/vagrant/.ssh/id_ed25519 -N "" -q
  echo -e "   Clave generada"
else
  echo -e " Clave ya existe — reutilizando"
fi

chmod 600 /home/vagrant/.ssh/id_ed25519
chmod 644 "$NEW_KEY"
PUB_KEY=$(cat "$NEW_KEY")

echo -e "\n🚀 Distribuyendo clave a todos los nodos...\n"

for SRC in "${NODES[@]}"; do

  SRC_KEY="$BASE_DIR/$SRC/virtualbox/private_key"
  SRC_IP=$(node_ip "$SRC")

  ssh -i "$SRC_KEY" \
      -o StrictHostKeyChecking=no \
      -o LogLevel=ERROR \
      vagrant@"$SRC_IP" \
      "grep -qF '${PUB_KEY}' ~/.ssh/authorized_keys 2>/dev/null || \
       echo '${PUB_KEY}' >> ~/.ssh/authorized_keys && \
       chmod 600 ~/.ssh/authorized_keys"
  echo -e "clave autorizada"

  # Registrar host key de cada destino en el known_hosts del nodo origen
  for DST in "${NODES[@]}"; do
    [ "$SRC" != "$DST" ] || continue

    DST_IP=$(node_ip "$DST")

    ssh -i "$SRC_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        vagrant@"$SRC_IP" \
        "ssh-keyscan -H $DST_IP 2>/dev/null >> ~/.ssh/known_hosts && \
         mkdir -p ~/.ssh && chmod 700 ~/.ssh"

    echo -e "known_hosts ← $DST ($DST_IP)"
  done

  echo ""
done

echo -e "✔ Distribución SSH completada\n"
