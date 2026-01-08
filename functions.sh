#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

# k3d (k8s is the k8s server image) cluster names
export MGMT CLUSTER1 CLUSTER2 CLUSTER3 CLUSTER4 DEMO DEMO1
DEMO=demo
DEMO1=demo1
MGMT=mgmt
CLUSTER1=cluster1
CLUSTER2=cluster2
CLUSTER3=cluster3
CLUSTER4=cluster4
ARGOCD=argocd

# Docker network and subnet plus IP ranges
export MLB_CIDR1 MLB_CIDR2 MLB_CIDR3 MLB_CIDR4 MLB_CIDR5 MLB_CIDR6 MLB_CIDR7
export MLB_CIDR8 NETWORK SUBNET DOCKER_NETWORK
export CLUSTER_CIDR1 CLUSTER_CIDR2 CLUSTER_CIDR3 CLUSTER_CIDR4
export CLUSTER_CIDR5 CLUSTER_CIDR6 CLUSTER_CIDR7 CLUSTER_CIDR8
export SERVICE_CIDR1 SERVICE_CIDR2 SERVICE_CIDR3 SERVICE_CIDR4
export SERVICE_CIDR5 SERVICE_CIDR6 SERVICE_CIDR7 SERVICE_CIDR8

DOCKER_NETWORK=k3d-cluster-network
NETWORK_SUBNET=10.10.0.0/16
NETWORK_GATEWAY=10.10.0.1
CONTAINER_SUBNET=10.10.97.0/24 # For containers on the docker network

# MLB (external LB) cidrs 14 possible LBs
MLB_CIDR1=10.10.96.16/28  # HostMin: 10.10.96.17
MLB_CIDR2=10.10.96.32/28
MLB_CIDR3=10.10.96.48/28
MLB_CIDR4=10.10.96.64/28
MLB_CIDR5=10.10.96.80/28
MLB_CIDR6=10.10.96.96/28
MLB_CIDR7=10.10.96.112/28 # HostMin: 10.10.96.113
MLB_CIDR8=10.10.96.128/28


# Cluster (Pod) and Service CIDRs 65534 possible addresses per slice
CLUSTER_CIDR1=10.42.0.0/16
SERVICE_CIDR1=10.43.0.0/16
CLUSTER_CIDR2=10.44.0.0/16
SERVICE_CIDR2=10.45.0.0/16
CLUSTER_CIDR3=10.46.0.0/16
SERVICE_CIDR3=10.47.0.0/16
CLUSTER_CIDR4=10.48.0.0/16
SERVICE_CIDR4=10.49.0.0/16
CLUSTER_CIDR5=10.50.0.0/16
SERVICE_CIDR5=10.51.0.0/16
CLUSTER_CIDR6=10.52.0.0/16
SERVICE_CIDR6=10.53.0.0/16
CLUSTER_CIDR7=10.54.0.0/16
SERVICE_CIDR7=10.55.0.0/16
CLUSTER_CIDR8=10.56.0.0/16
SERVICE_CIDR8=10.57.0.0/16

# Docker Compose on DOCKER_NETWORK allows PiHole and Docker Registry Proxy (ligfx)
export KCM_DOCKER_COMPOSE="$K3D_DIR"/docker-compose.yaml
export PIHOLE_IP=10.10.96.10
export REGISTRY_IP=10.10.96.11
export HELLOWORLD_IP0=10.10.96.17
export HELLOWORLD_IP1=10.10.96.18
export HELLOWORLD_IP2=10.10.96.19
export LIGFX_VER=v0.10

# K3D names and places
# Calico is required in lieu of Traefik for Istio Ambient
# MetalLb with docker-mac-net-connect allows directly addressable external IPs
# metallb: https://github.com/metallb/metallb
# docker-mac-net-connect: https://github.com/chipmk/docker-mac-net-connect
export K3D_DIR MLB_ADDY_POOL MLB_ADDY_RANGE CLUSTER_ID CALICO_ADDY_RANGE CALICO_ADDY_POOL
export MLB_TEMP AMBIENT_TEMP KGATEWAY_TEMP CA_CERT_TEMP ISTIO_SYSTEM_NS_TEMP
export EW_GATEWAY_TEMP
K3D_DIR=$SCRIPT_DIR/templates
CALICO_ADDY_POOL="${K3D_DIR}/calico.address-pool.template.yaml"
MLB_ADDY_POOL="${K3D_DIR}/metallb-native.address-pool.template.yaml"

# k8s cluster versions
export CALICO_VER MLB_VER K3D_TEMPLATE K3S_VER_132 K3S_VER_133
export K3S_VER K3S_VER_132 K3S_VER_133 K3S_VER_134 K3S_VER_135
CALICO_VER="3.30.5"                        # https://github.com/projectcalico/calico/tags # Don't forget to download new manifest and put in $K3D_DIR when upgrading
                                           # https://raw.githubusercontent.com/projectcalico/calico/v3.30.5/manifests/calico.yaml
K3S_VER_132="v1.32.11-k3s1"                # https://hub.docker.com/r/rancher/k3s/tags?name=v1.32
K3S_VER_133="v1.33.7-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.33
K3S_VER_134="v1.34.3-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.34
K3S_VER_135="v1.35.0-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.35
#MLB_VER="v0.14.9"                          # https://github.com/metallb/metallb/tags
MLB_VER="v0.15.3"                          # https://github.com/metallb/metallb/tags
                                           # https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml 
                                           # metallb-native.address-pool.template.yaml
K3S_VER=$K3S_VER_134

# HELM and ISTIO versions
export KGATEWAY_VER ISTIO_VER ISTIO_REPO HELM_CHART K8S_TRUST_DOMAIN
export DOCKER_COMPOSE
KGATEWAY_VER=v1.2.1
ISTIO_VER=1.25.3
HELM_REPO=us-docker.pkg.dev/soloio-img/istio-helm
ISTIO_REPO=us-docker.pkg.dev/soloio-img/istio
K8S_TRUST_DOMAIN='k8s.cluster.local'


# shellcheck disable=SC2120
function _create_docker_compose {
  if [[ ! -e "$KCM_DOCKER_COMPOSE" || -n "$1" ]]; then
    local _k3d_ver; _k3d_ver=$(k3d version -o json |jq -r '.k3d')
    local _internal_port _external_port 
    _internal_port=5000
    _external_port=$(shuf -i 50100-51000 -n 1)

    jinja2 -D registry_ip="$REGISTRY_IP"                                       \
           -D pihole_ip="$PIHOLE_IP"                                           \
           -D helloworld_ip0="$HELLOWORLD_IP0"                                 \
           -D helloworld_ip1="$HELLOWORLD_IP1"                                 \
           -D helloworld_ip2="$HELLOWORLD_IP2"                                 \
           -D ligfx_ver="$LIGFX_VER"                                           \
           -D network="$DOCKER_NETWORK"                                        \
           -D k3d_ver="$_k3d_ver"                                              \
           -D k3s_registry_port_internal="$_internal_port"                     \
           -D k3s_registry_port_external="$_external_port"                     \
           -D dir="$SCRIPT_DIR"                                                \
           "$K3D_DIR"/docker-compose.yaml.j2                                   \
    > "$KCM_DOCKER_COMPOSE"
    echo "INFO[S002] KCM: $KCM_DOCKER_COMPOSE created"
  else
    echo "INFO[S003] KCM: $KCM_DOCKER_COMPOSE already exists"
  fi
}

# k3d-registry-dockerd, a docker proxy that elimiates anonymous docker login errors in k8s
# Docker Desktop must be running (TBD does this work with Rancher Desktop?)
# https://github.com/ligfx/k3d-registry-dockerd
function _external_registry {
  _external_docker_compose registry "$1"
}

# PiHole local DNS server
function _external_pihole {
  _external_docker_compose pihole "$1"
}

# Helloworld container external to the cluster but on DOCKER_NETWORK
function _external_helloworld {
  _external_docker_compose helloworld "$1"
}

# Generic wrapper for all external docker_compose services
function _external_docker_compose {
  local _service=$1
  local _mode=${2:-status}

  if [[ $_mode == start ]]; then
    if ! _external_docker_compose "$_service" status; then
      docker compose -f "$KCM_DOCKER_COMPOSE"                                  \
                   --project-directory "$K3D_DIR" up "$_service" -d
    fi
  elif [[ $_mode == stop ]]; then
    docker compose -f "$KCM_DOCKER_COMPOSE"                                    \
                   --project-directory "$K3D_DIR" down "$_service"
  elif [[ $_mode == status ]]; then
    docker compose -f "$KCM_DOCKER_COMPOSE"                                    \
                   --project-directory "$K3D_DIR" ps "$_service"              |\
      grep -q healthy
  fi
}

# DOCKER_NETWORK
function docker-k3d-network {
  local mode=${1:-status}

  if [[ $mode == start ]]; then
    if ! docker-k3d-network status; then
      docker network create "$DOCKER_NETWORK"                                  \
        --subnet "$NETWORK_SUBNET"                                             \
        --gateway "$NETWORK_GATEWAY"                                           \
        --ip-range "$CONTAINER_SUBNET"
    fi

#    > /dev/null 2>&1

  # Note: https://github.com/chipmk/docker-mac-net-connect/issues/48
  #    --opt "com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected"     \

  elif [[ $mode == stop ]]; then
    docker network rm "$DOCKER_NETWORK" > /dev/null 2>&1

  elif [[ $mode == status ]]; then
    docker network ls -f name="$DOCKER_NETWORK" |
      grep -E '\<'"$DOCKER_NETWORK"'\>' > /dev/null 2>&1
  fi
  return $?
}

# Create k3d cluster "k3d-create-cluster <name> <config_file>
function k3d-cluster-create  {
  local config name _dry_run
  name=$1
  config=$2
  _dry_run=${3:-false}
  
  if $_dry_run; then
    cat "$config"
    return
  fi
  # create docker network if it does not exist
  docker-k3d-network start

  # Create the docker compose file on the DOCKER_NETWORK if it doesn't exist
  _create_docker_compose

  # Start the external services on the DOCKER_NETWORK
  _external_registry start
  _external_pihole start
  _external_helloworld start

###  cat "$config"
###  return

  k3d cluster create --wait --config "${config}"

  # remove existing ones if they exist
  kubectl config delete-cluster "${name}" > /dev/null 2>&1 || true
  kubectl config delete-user    "admin@${name}" > /dev/null 2>&1 || true
  kubectl config delete-context "${name}" > /dev/null 2>&1 || true

  kubectl config rename-context "k3d-${name}" "${name}"
}

# delete k3d cluster "k3d-cluster-delete <name>"
function k3d-cluster-delete {
  local name
  name=$1

  k3d cluster delete "$name"

  # because we renamed them we need to delete the names
  kubectl config delete-cluster "k3d-$name" > /dev/null 2>&1 || true
  kubectl config delete-user "admin@k3d-${name}" > /dev/null 2>&1 || true
  kubectl config delete-context "$name" > /dev/null 2>&1 || true
}

function calico-ippool-template-create {
  local _temp _pod_ip_range
  _pod_ip_range=$1
  _temp=$(mktemp)

  CALICO_ADDY_RANGE=$_pod_ip_range
  envsubst < "$CALICO_ADDY_POOL" > "$_temp"

  echo -n "$_temp"
}

function mlb-template-create {
  local _temp _ip_range
  _ip_range=$1
  _temp=$(mktemp)

  MLB_ADDY_RANGE=$_ip_range
  envsubst < "$MLB_ADDY_POOL" > "$_temp"

  echo -n "$_temp"
}

function tls-cert-secret-create {
  local _temp

  _temp=$(mktemp)

  while getopts "c:n:s:" opt; do
    # shellcheck disable=SC2220
    case $opt in
      c)
        _cluster_name=$OPTARG ;;
      n)
        _namespace=$OPTARG ;;
      s)
        _secret_name=$OPTARG ;;
    esac
  done

  kubectl create secret tls "$_secret_name"                                   \
    --namespace "$_namespace"                                                 \
    --cert="${K3D_DIR}"/certs/"${_cluster_name}"/ca-cert.pem                  \
    --key="${K3D_DIR}"/certs/"${_cluster_name}"/ca-key.pem                    \
    --dry-run=client                                                          \
    --output=yaml > "$_temp"

  echo -n "$_temp"
}

function ca-cert-template-create {
  local temp cluster
  cluster=$1
  temp=$(mktemp)

  kubectl create secret generic cacerts                                       \
    --namespace istio-system                                                  \
    --from-file="${K3D_DIR}"/certs/"${cluster}"/ca-cert.pem                   \
    --from-file="${K3D_DIR}"/certs/"${cluster}"/ca-key.pem                    \
    --from-file="${K3D_DIR}"/certs/"${cluster}"/root-cert.pem                 \
    --from-file="${K3D_DIR}"/certs/"${cluster}"/cert-chain.pem                \
    --dry-run=client                                                          \
    --output=yaml > "$temp"

  echo -n "$temp"
}

# Create an ambient template from helm. This will be mounted as a k3d volume in
# the directory that k3d sources at initialization
function ambient-template-create {
  local temp cluster
  cluster=$1
  temp=$(mktemp)

  { helm template istio-base "$HELM_REPO"/base                                \
    --version "${ISTIO_VER}-solo"                                             \
    --namespace istio-system

  helm template istiod "$HELM_REPO"/istiod                                    \
    --version "${ISTIO_VER}-solo"                                             \
    --namespace istio-system                                                  \
    --set profile=ambient                                                     \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}-solo"                                             \
    --set "global.multiCluster.clusterName=${cluster}"                        \
    --set "global.multiCluster.enabled=true"                                  \
    --set "global.network=${cluster}"                                         \
    --set "global.meshID=mesh"                                                \
    --set "env.PILOT_ENABLE_IP_AUTOALLOCATE=true"                             \
    --set "env.PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES=false"                \
    --set "env.PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION=true"             \
    --set "env.PILOT_ENABLE_WORKLOAD_ENTRY_HEALTHCHECKS=true"                 \
    --set "env.PILOT_SKIP_VALIDATE_TRUST_DOMAIN=true"                         \
    --set "license.value=${GLOO_MESH_LICENSE_KEY}"                            \
    --set "meshConfig.trustDomain=$K8S_TRUST_DOMAIN"                          \
    --set "meshConfig.defaultHttpRetryPolicy.attempts=2"                      \
    --set "meshConfig.defaultHttpRetryPolicy.retryOn=connect-failure\,refused-stream\,unavailable\,cancelled\,reset\,503" \
    --set "platforms.peering.enabled=true"

  helm template istio-cni "$HELM_REPO"/cni                                    \
    --version "${ISTIO_VER}-solo"                                             \
    --namespace istio-system                                                  \
    --set profile=ambient                                                     \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}-solo"                                             \
    --set "ambient.dnsCapture=true"

  helm template ztunnel "$HELM_REPO"/ztunnel                                  \
    --version "${ISTIO_VER}-solo"                                             \
    --namespace istio-system                                                  \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}-solo"                                             \
    --set "multiCluster.clusterName=${cluster}"                               \
    --set "network=${cluster}"                                                \
    --set "env.ISTIO_META_ENABLE_HBONE=true"                                  \
    --set "env.ISTIO_META_DNS_CAPTURE=true"                                   \
    --set "env.SKIP_VALIDATE_TRUST_DOMAIN=true"                               \
    --set "l7Telemetry.distributedTracing.enabled=true"
  } >> "$temp" 2> /dev/null

  echo -n "$temp"
}

function namespace-create {
  local _temp _namespace _cluster_name

  _temp=$(mktemp)
  _cluster_name=no_name

  while getopts "c:n:" opt; do
    # shellcheck disable=SC2220
    case $opt in
      c)
        _cluster_name=$OPTARG ;;
      n)
        _namespace=$OPTARG ;;
    esac
  done

  cat <<EOF > "$_temp"
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: "${_namespace}"
  name: "${_namespace}"
...
EOF

  echo -n "$_temp"
}

function istio-system-namespace-create {
  local temp name
  temp=$(mktemp)
  name=$1

  (
    CLUSTER_ID="$name"                                                      \
    envsubst < "$K3D_DIR"/namespace.istio-system.template.yaml
  ) > "$temp"

  echo -n "$temp"
}

function ew-gateway-create {
  local temp name
  temp=$(mktemp)
  name=$1

  (
    CLUSTER_ID="$name"                                                      \
    envsubst < "$K3D_DIR"/ew-gateway.template.yaml
  ) > "$temp"

  echo -n "$temp"

}

function create-feature-map {
  local _calico _mlb _istio _ew _ip_range _argocd _cluster_name _pihole
  local _temp _argocd_temp _pod_ip_range

  _temp=$(mktemp)

  _cluster_name=no_name

  _pihole=true
  _calico=true
  _mlb=true
  _istio=false
  _ew=false
  _argocd=false

  while getopts "ac:ip:r:" opt; do
    # shellcheck disable=SC2220
    case $opt in
      a)
        _argocd=true ;;
      c)
        _cluster_name=$OPTARG ;;
      i)
        _istio=true ;;
      p)
        _pod_ip_range=$OPTARG ;;
      r)
        _ip_range=$OPTARG ;;
    esac
  done

  cat <<EOF > "$_temp"
volume_list:
EOF
  # Calico
  if $_calico; then
    cat <<EOF >> "$_temp"
  ${K3D_DIR}/calico-${CALICO_VER}.yaml: 00-calico.yaml
  $(calico-ippool-template-create "$_pod_ip_range"): 01-calico.yaml
EOF
  fi
  # Pihole
  if $_pihole; then
    cat <<EOF >> "$_temp"
  ${K3D_DIR}/configmap.coredns.pihole.yaml: 05-pihole.yaml
EOF
  fi
  # Metal LB
  if $_mlb; then
    cat <<EOF >> "$_temp"
  ${K3D_DIR}/metallb-native-${MLB_VER}.yaml: 10-metallb-native.yaml
  $(mlb-template-create "$_ip_range"): 11-metallb-native.address-pool.yaml
EOF
  fi
  # Istio
  if $_istio; then
    cat <<EOF >> "$_temp"
  $(istio-system-namespace-create "$_cluster_name"): 40-namespace.istio-system.yaml
  $(namespace-create -n istio-gateways): 41-namespace.istio-gateways.yaml
  $(ca-cert-template-create "$_cluster_name"): 42-secret.cacerts.${_cluster_name}.yaml
  $(ambient-template-create "$_cluster_name"): 43-ambient.yaml
  $K3D_DIR/kgateway.crds.standard-install.${KGATEWAY_VER}.yaml: 44-kgateway.crds.yaml
EOF
  fi
  if $_argocd; then
    _argocd_temp=$(mktemp)
#    curl -qfsSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | yq e '.metadata += {"namespace": "argocd"}' > "$_argocd_temp"
    cat <<EOF >> "$_temp"
  $(namespace-create -n argocd): 50-namespace.argocd.yaml
  $(tls-cert-secret-create -n argocd -c "$_cluster_name" -s argocd-server-tls): 51-argocd.tls-secret.yaml
  ${K3D_DIR}/argo-cd.v3.0.2.manifest.yaml: 52-argocd.v3.0.2.yaml
EOF
  fi

  cat "$K3D_DIR"/zone-map.yaml >> "$_temp"

  cp "$_temp" "${_temp}.yaml"
  echo -n "${_temp}.yaml"
}

# k3d cluster -m [create|delete|status] -c [cluster_name] -r <ip_range> -e <region> -s <no_of_servers> <-i enable_ambient> <-y disable_dockerproxy> <-a enable_argocd>
function k3d-cluster {
  local _argocd _istio _ip_range _mode _cluster_name _region _no_servers _dproxy
  local _cluster_cidr _service_cidr
  local _dry_run

  _cluster_name=no_name
  _region=no_region
  _no_servers=1
  _dproxy=enabled
  _istio=""
  _argocd=""
  _dry_run=false

  while getopts "ac:die:m:p:q:r:s:y" opt; do
    # shellcheck disable=SC2220
    case $opt in
      a) # Deploy argoCD
        _argocd='-a' ;;
      c) # Cluster name
        _cluster_name=$OPTARG ;;
      d) # Just print out the k3d config file
        _dry_run=true ;;
      i) # Enable istio in ambient mode
        _istio='-i' ;;
      e) # region (arbitrary)
        _region=$OPTARG ;;
      p) # Cluster Cidr for the pods
        _cluster_cidr=$OPTARG ;;
      q) # Cluster Cidr for the services
        _service_cidr=$OPTARG ;;
      r) # IP range for MLB
        _ip_range=$OPTARG ;;
      m) # Create, delete, status
        _mode=$OPTARG ;;
      s) # Number of nodes in the cluster
        _no_servers=$OPTARG ;;
      y) # Disable dockerproxy
        _dproxy="" ;;
    esac
  done

  local _d_network=$DOCKER_NETWORK
  local _registry=k3d-dockerproxy

  if [[ $_mode == create ]]; then
    
    k3d-cluster-create "$_cluster_name" <(
      jinja2                                                                  \
             -D cluster_id="$_cluster_name"                                   \
             -D docker_network="$_d_network"                                  \
             -D k3d_region="$_region"                                         \
             -D k3s_ver="$K3S_VER"                                            \
             -D num_of_nodes="$_no_servers"                                   \
             -D enable_dockerproxy="$_dproxy"                                 \
             -D cluster_cidr="$_cluster_cidr"                                 \
             -D service_cidr="$_service_cidr"                                 \
             -D registry="$_registry"                                         \
             "$K3D_DIR"/k3d-omni-cluster.volumes.template.yaml.j2             \
             "$(create-feature-map -p "$_cluster_cidr" -r "$_ip_range" -c "$_cluster_name" $_argocd $_istio)" ) \
    "$_dry_run"
  
  elif [[ $_mode == delete ]]; then
    k3d-cluster-delete "$_cluster_name"

  elif [[ $_mode == status ]]; then
    k3d cluster ls "$_cluster_name" > /dev/null 2>&1
  fi
  return $?
}

# DEMO clusters. No istio
alias d0up3="k3d-cluster -m create -c \$DEMO -r \$MLB_CIDR7 -p \$CLUSTER_CIDR7 -q \$SERVICE_CIDR7 -e us-west-1 -s 3"
alias d0down="k3d-cluster -m delete -c \$DEMO"
alias d1up="k3d-cluster -m create -c \$DEMO1 -r \$MLB_CIDR8 -p \$CLUSTER_CIDR8 -q \$SERVICE_CIDR8 -e us-west-1"
alias d1down="k3d-cluster -m delete -c \$DEMO1"

# MGMT cluster. No istio
alias m0up="k3d-cluster -m create -c \$MGMT -r \$MLB_CIDR6 -p \$CLUSTER_CIDR6 -q \$SERVICE_CIDR6 -e us-west-2"
alias m0down="k3d-cluster -m delete -c \$MGMT"

# CLUSTER clusters. Ambient enabled with 'a' otherwise, vanilla
# _np is without dockerproxy
alias c1up="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2"
alias c1up3a="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2 -s 3 -i"
alias c1up3="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2 -s 3"
alias c1up_np="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2 -y"
alias c1down="k3d-cluster -m delete -c \$CLUSTER1"
alias c1u=c1up
alias c1d=c1down

alias c2up="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2"
alias c2upa="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2 -i"
alias c2up3="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2 -s 3"
alias c2up_np="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2 -y"
alias c2down="k3d-cluster -m delete -c \$CLUSTER2"
alias c2u=c2up
alias c2d=c2down

alias c3up="k3d-cluster -m create -c \$CLUSTER3 -r \$MLB_CIDR3 -p \$CLUSTER_CIDR3 -q \$SERVICE_CIDR3 -e us-west-1"
alias c3upa="k3d-cluster -m create -c \$CLUSTER3 -r \$MLB_CIDR3 -p \$CLUSTER_CIDR3 -q \$SERVICE_CIDR3 -e us-west-1 -i"
alias c3up_np="k3d-cluster -m create -c \$CLUSTER3 -r \$MLB_CIDR3 -p \$CLUSTER_CIDR3 -q \$SERVICE_CIDR3 -e us-west-1 -y"
alias c3down="k3d-cluster -m delete -c \$CLUSTER3"
alias c3u=c3up
alias c3d=c3down

alias c4up="k3d-cluster -m create -c \$CLUSTER4 -r \$MLB_CIDR4 -p \$CLUSTER_CIDR4 -q \$SERVICE_CIDR4 -e us-east-1"
alias c4upa="k3d-cluster -m create -c \$CLUSTER4 -r \$MLB_CIDR4 -p \$CLUSTER_CIDR4 -q \$SERVICE_CIDR4 -e us-east-1 -i"
alias c4up_np="k3d-cluster -m create -c \$CLUSTER4 -r \$MLB_CIDR4 -p \$CLUSTER_CIDR4 -q \$SERVICE_CIDR4 -e us-east-1 -y"
alias c4down="k3d-cluster -m delete -c \$CLUSTER4"
alias c4u=c4up
alias c4d=c4down

# ArgoCD
alias a0up=    "k3d-cluster -m create -c \$ARGOCD -r \$MLB_CIDR5 -p \$CLUSTER_CIDR5 -q \$SERVICE_CIDR5 -e us-west-2 -a"
alias a0down=  "k3d-cluster -m delete -c \$ARGOCD"

# Cluster resets
function c1j { c1down;c1up; }
function c2j { c2down;c2up; }
function c3j { c3down;c3up; }
function c4j { c4down;c4up; }
function m0j { m0down;m0up; }

# End
