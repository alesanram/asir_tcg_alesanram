# TCG — Infraestructura Kubernetes Automatizada

Infraestructura virtual distribuida y automatizada que simula un entorno datacenter on-premise con Kubernetes, monitorización centralizada y exposición controlada a internet mediante una zona DMZ.

---

## Índice

- [Arquitectura](#arquitectura)
- [Tecnologías](#tecnologías)
- [Requisitos previos](#requisitos-previos)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Despliegue](#despliegue)
  - [Fase 1 — Infraestructura base](#fase-1--infraestructura-base)
  - [Fase 2 — Kubernetes](#fase-2--kubernetes)
  - [Fase 3 — Aplicaciones](#fase-3--aplicaciones)
  - [Fase 4 — Monitorización](#fase-4--monitorización)
  - [Fase 5 — Edge DMZ](#fase-5--edge-dmz)
- [Acceso a los servicios](#acceso-a-los-servicios)
- [Credenciales](#credenciales)

---

## Arquitectura

```
                        INTERNET
                            │
                    ┌───────▼────────┐
                    │  edge-gateway  │  192.168.56.15
                    │   DMZ / nftables│  DNAT 80/443 → worker3
                    │   dnsmasq DNS  │
                    └───────┬────────┘
                            │ Red privada 192.168.56.0/24
          ┌─────────────────┼──────────────────────┐
          │                 │                      │
  ┌───────▼──────┐  ┌───────▼──────┐      ┌───────▼──────┐
  │  k8s-master  │  │   worker1    │      │   worker3    │
  │  192.168.56.11│  │ 192.168.56.12│      │ 192.168.56.14│
  │  Control Plane│  │  Workloads  │      │ NGINX Ingress│
  └──────────────┘  └──────────────┘      └──────────────┘
                            │
                    ┌───────▼──────┐
                    │ansible-control│  192.168.56.10
                    │  Ansible +    │
                    │  kubeadm      │
                    └──────────────┘
```

### Red privada

| Nodo            | IP              | Rol                          | RAM    |
|-----------------|-----------------|------------------------------|--------|
| ansible-control | 192.168.56.10   | Automatización y despliegue  | 2048MB |
| k8s-master      | 192.168.56.11   | Control plane Kubernetes     | 4096MB |
| worker1         | 192.168.56.12   | Workloads generales          | 3072MB |
| worker2         | 192.168.56.13   | Workloads generales          | 3072MB |
| worker3         | 192.168.56.14   | NGINX Ingress (entrada HTTP) | 3072MB |
| edge-gateway    | 192.168.56.15   | DMZ — único punto a internet | 1024MB |

### Flujo de tráfico

```
Internet :80/:443
    → edge-gateway (DNAT)
    → worker3 :30080/:30443 (NodePort)
    → NGINX Ingress Controller
    → wordpress.tcg.local / grafana.tcg.local
```

---

## Tecnologías

| Tecnología              | Versión   | Función                              |
|-------------------------|-----------|--------------------------------------|
| Vagrant                 | —         | Gestión de VMs                       |
| VirtualBox              | —         | Hipervisor                           |
| Ubuntu                  | 22.04 LTS | Sistema operativo base               |
| Ansible                 | 2.15+     | Automatización y configuración       |
| kubeadm                 | v1.28     | Despliegue de Kubernetes             |
| Kubernetes              | v1.28.6   | Orquestación de contenedores         |
| containerd              | —         | Runtime de contenedores              |
| Calico                  | —         | Red del clúster (CNI)                |
| MetalLB                 | —         | Balanceador de carga (L2)            |
| NGINX Ingress           | —         | Entrada HTTP/HTTPS al clúster        |
| cert-manager            | —         | Gestión de certificados TLS          |
| MariaDB (Bitnami)       | —         | Base de datos master + slave         |
| WordPress (Bitnami)     | —         | Aplicación web                       |
| kube-prometheus-stack   | —         | Prometheus + Grafana + Alertmanager  |
| nftables                | —         | Firewall DMZ en edge-gateway         |
| dnsmasq                 | —         | DNS interno para la red privada      |

---

## Requisitos previos

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)
- 20GB RAM disponibles en el host (recomendado 32GB)
- 6 CPUs disponibles en el host

---

## Estructura del proyecto

```
TCG/
├── Vagrantfile                        ← Definición de las 6 VMs
├── scripts/
│   ├── bootstrap-ansible.sh           ← Provisión inicial de ansible-control
│   └── setup-ssh.sh                   ← Distribución de claves SSH entre nodos
├── ansible/
│   ├── ansible.cfg                    ← Configuración Ansible (usar ~/.ansible.cfg)
│   ├── inventory/
│   │   └── hosts.ini                  ← Inventario principal
│   ├── group_vars/
│   │   └── all.yml                    ← Variables globales
│   ├── roles/
│   │   ├── users/                     ← Crear usuario devops
│   │   ├── ssh/                       ← Configurar claves SSH
│   │   ├── common/                    ← Paquetes base + desactivar swap
│   │   ├── dmz/                       ← nftables + dnsmasq en edge-gateway
│   │   └── isolate-nat/               ← Aislar acceso NAT en nodos del clúster
│   └── playbooks/
│       ├── fase1/fase1.yml            ← Infraestructura base
│       ├── fase2/fase2-0.yml          ← Verificaciones pre-Kubernetes
│       ├── fase2/fase2-1.yml          ← Instalación Kubernetes (kubeadm)
│       ├── fase3/fase3.yml            ← Aplicaciones
│       ├── fase4/fase4.yml            ← Monitorización
│       └── fase5/fase5.yml            ← Edge DMZ (última)
└── k8s/
    ├── metallb/                       ← Pool IPs 192.168.56.200-220
    ├── cert-manager/                  ← ClusterIssuer self-signed
    ├── ingress-nginx/                 ← NodePort 30080/30443 en worker3
    ├── mariadb/                       ← Master + 1 slave (replicación)
    ├── wordpress/                     ← App + Ingress TLS
    └── monitoring/                    ← kube-prometheus-stack
```

---

## Despliegue

### Configuración previa (host Windows)

Añade al fichero `C:\Windows\System32\drivers\etc\hosts`:

```
192.168.56.15  wordpress.tcg.local
192.168.56.15  grafana.tcg.local
```

Crea el fichero `~/.ansible.cfg` en ansible-control:

```bash
cat > ~/.ansible.cfg << 'EOF'
[defaults]
inventory         = /vagrant/ansible/inventory/hosts.ini
roles_path        = /vagrant/ansible/roles
host_key_checking = False
remote_user       = vagrant
private_key_file  = ~/.ssh/id_ed25519
retry_files_enabled = False

[privilege_escalation]
become        = True
become_method = sudo
become_user   = root
EOF
```

---

### Fase 1 — Infraestructura base

Levanta las VMs y configura los nodos (usuario devops, SSH, paquetes base, swap off).

```bash
# Desde el host Windows
vagrant up

# Desde ansible-control
bash /vagrant/scripts/setup-ssh.sh
ansible-playbook /vagrant/ansible/playbooks/fase1/fase1.yml
```

**Qué hace:**
- Crea 6 VMs con Ubuntu 22.04
- Instala Ansible y dependencias en ansible-control
- Crea usuario `devops` en todos los nodos
- Configura claves SSH
- Desactiva swap (requisito Kubernetes)

---

### Fase 2 — Kubernetes

Despliega el clúster Kubernetes con kubeadm.

```bash
ansible-playbook /vagrant/ansible/playbooks/fase2/fase2-0.yml
ansible-playbook /vagrant/ansible/playbooks/fase2/fase2-1.yml
```

**Qué hace:**
- Verifica prerequisitos (swap, conectividad, containerd)
- Instala kubelet, kubeadm y kubectl v1.28.6 en todos los nodos
- Inicializa el control plane con kubeadm en k8s-master
- Despliega Calico CNI y une los workers al clúster
- Configura kubectl en ansible-control

**Tiempo estimado:** 8-12 minutos

---

### Fase 3 — Aplicaciones

Despliega MetalLB, cert-manager, NGINX Ingress, MariaDB y WordPress.

```bash
ansible-playbook /vagrant/ansible/playbooks/fase3/fase3.yml
```

**Qué despliega:**

| Componente     | Namespace    | Detalles                              |
|----------------|--------------|---------------------------------------|
| MetalLB        | metallb-system | Pool L2: 192.168.56.200-220          |
| cert-manager   | cert-manager | ClusterIssuer self-signed (tcg-ca-issuer) |
| NGINX Ingress  | ingress-nginx | NodePort 30080/30443 en worker3      |
| MariaDB        | apps         | 1 master + 1 slave (replicación)     |
| WordPress      | apps         | https://wordpress.tcg.local          |

---

### Fase 4 — Monitorización

Despliega Prometheus, Grafana y Alertmanager.

```bash
ansible-playbook /vagrant/ansible/playbooks/fase4/fase4.yml
```

**Qué despliega:**

| Componente       | Detalles                                        |
|------------------|-------------------------------------------------|
| Prometheus       | Retención 7 días, scraping de todo el clúster   |
| Grafana          | https://grafana.tcg.local, dashboards K8s       |
| Alertmanager     | Gestión de alertas                              |
| Node Exporter    | Métricas de sistema en cada nodo                |
| kube-state-metrics | Métricas de recursos Kubernetes              |

---

### Fase 5 — Edge DMZ

Configura el firewall y expone los servicios a internet. **Ejecutar siempre al final.**

```bash
ansible-playbook /vagrant/ansible/playbooks/fase5/fase5.yml
```

**Qué hace:**
- Instala y configura nftables en edge-gateway
- DNAT: `internet:80/443` → `worker3:30080/30443`
- MASQUERADE: los nodos internos salen a internet vía edge
- dnsmasq: DNS interno para la red privada
- Aísla el acceso NAT directo en todos los nodos del clúster

**Reglas de firewall (edge-gateway):**

```
INPUT:   22 (SSH gestión), 80/443 desde internet → ACCEPT | resto → DROP
FORWARD: internet → worker3:30080/30443 → ACCEPT
FORWARD: red interna → internet → ACCEPT (MASQUERADE)
```

---

## Acceso a los servicios

| Servicio   | URL                          | Descripción                  |
|------------|------------------------------|------------------------------|
| WordPress  | https://wordpress.tcg.local  | Aplicación web               |
| Grafana    | https://grafana.tcg.local    | Monitorización del clúster   |

> Los certificados son self-signed — el navegador mostrará una advertencia la primera vez.

---

## Credenciales

| Servicio   | Usuario     | Contraseña       |
|------------|-------------|------------------|
| WordPress  | admin       | AdminTCG2024!    |
| Grafana    | admin       | GrafanaTCG2024!  |
| MariaDB root | root      | R00tTCG2024!     |
| MariaDB WP | wordpress  | WpTCG2024!       |
