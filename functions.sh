#!/usr/bin/env bash
# k3d (k8s) cluster names
export MGMT CLUSTER1 CLUSTER2 CLUSTER3 CLUSTER4 SOLO SOLO1 SOLO2 DEMO DEMO1
DEMO=demo
DEMO1=demo1
MGMT=mgmt
CLUSTER1=cluster1
CLUSTER2=cluster2
CLUSTER3=cluster3
CLUSTER4=cluster4
SOLO=solo
SOLO1=solo1
SOLO2=solo2

# Docker network and subnet plus IP ranges
# The IP ranges must be in the subnet cidr
export DOCKER_NETWORK DOCKER_SUBNET 
export IP_RANGE_20 IP_RANGE_30 IP_RANGE_40 IP_RANGE_50 IP_RANGE_100
export IP_RANGE_60 IP_RANGE_70 IP_RANGE_80 IP_RANGE_90 IP_RANGE_110
DOCKER_NETWORK=k3d-cluster-network
DOCKER_SUBNET=192.168.96.0/24
IP_RANGE_20=192.168.96.20-192.168.96.29
IP_RANGE_30=192.168.96.30-192.168.96.39
IP_RANGE_40=192.168.96.40-192.168.96.49
IP_RANGE_50=192.168.96.50-192.168.96.59
IP_RANGE_60=192.168.96.60-192.168.96.69
IP_RANGE_70=192.168.96.70-192.168.96.79
IP_RANGE_80=192.168.96.80-192.168.96.89
IP_RANGE_90=192.168.96.90-192.168.96.99
IP_RANGE_100=192.168.96.100-192.168.96.109
IP_RANGE_110=192.168.96.110-192.168.96.119

# K3D names and places
export K3D_DIR MLB_TEMP MLB_IP_ADDRESS_RANGE AMBIENT_TEMP MLB_ADDY_POOL
export CLUSTER_ID K3D_ZONE K3D_REGION KGATEWAY_TEMP
K3D_DIR=$SCRIPT_DIR/templates
MLB_ADDY_POOL="${K3D_DIR}/metallb-native.address-pool.template.yaml"

# k8s cluster versions
export CALICO_VER K3S_VER MLB_VER K3D_REGION K3D_ZONE K3D_TEMPLATE K3D_SERVERS
CALICO_VER="3.29.1"                        # https://github.com/projectcalico/calico/tags
                                           # https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml
K3S_VER="v1.31.5-k3s1"                     # https://hub.docker.com/r/rancher/k3s/tags
MLB_VER="v0.14.9"                          # https://github.com/metallb/metallb/tags
                                           # https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml 
                                           # metallb-native.address-pool.template.yaml

# HELM and ISTIO versions
export KGATEWAY_VER ISTIO_VER ISTIO_REPO HELM_CHART HELM_CHART_VER
KGATEWAY_VER=v1.2.1
ISTIO_VER=1.24.2-solo
ISTIO_REPO=us-docker.pkg.dev/gloo-mesh/istio-4d37697f9711
HELM_CHART=istio
HELM_CHART_VER=1.24.2

# k3d-registry-dockerd, a docker proxy that elimiates anonymous docker login errors in k8s
# Docker Desktop must be running (TBD does this work with Rancher Desktop?)
# https://github.com/ligfx/k3d-registry-dockerd
function dockerproxy {
  local mode
  mode=$1

  if [[ $mode == start ]]; then
    k3d registry create -i ligfx/k3d-registry-dockerd:v0.7                    \
      -v /var/run/docker.sock:/var/run/docker.sock                            \
      dockerproxy
  fi

  if [[ $mode == stop ]]; then
    k3d registry delete k3d-dockerproxy
  fi

  if [[ $mode == status ]]; then
    docker ps -f name=k3d-dockerproxy |
      grep -E '\<k3d-dockerproxy\>' > /dev/null 2>&1
  fi
  return $?
}

function docker-k3d-network {
  local mode network subnet
  mode=$1
  network=$2
  subnet=$3

  if [[ $mode == start ]]; then
    docker network create --subnet "$subnet" "$network" > /dev/null 2>&1
  fi

  if [[ $mode == stop ]]; then
    docker network rm "$network" > /dev/null 2>&1
  fi
  if [[ $mode == running ]]; then
    docker network ls -f name="$network" |
      grep -E '\<'"$network"'\>' > /dev/null 2>&1
  fi
  return $?
}

# Create k3d cluster "k3d-create-cluster <name> <config_file>
function k3d-cluster-create  {
  local config name
  name=$1
  config=$2

  # create docker network if it does not exist
  if ! docker-k3d-network status; then
    docker-k3d-network start "$DOCKER_NETWORK" "$DOCKER_SUBNET"
  fi

  if ! dockerproxy status; then
    dockerproxy start
  fi

  k3d cluster create --wait --config "${config}"

  # remove existing ones if they exist
  kubectl config delete-cluster "${name}" > /dev/null 2>&1 || true
  kubectl config delete-user    "${name}" > /dev/null 2>&1 || true
  kubectl config delete-context "${name}" > /dev/null 2>&1 || true

  kubectl config rename-context "k3d-${name}" "${name}"
}

# delete k3d cluster "k3d-cluster-delete <name>"
function k3d-cluster-delete {
  local name
  name=$1

  k3d cluster delete "$name"

  # because we renamed them we need to delete the names
  kubectl config delete-cluster "$name" > /dev/null 2>&1 || true
  kubectl config delete-user "$name" > /dev/null 2>&1 || true
  kubectl config delete-context "$name" > /dev/null 2>&1 || true
}

function mlb-template-create {
  local temp
  local ip_range=$1
  temp=$(mktemp)

  MLB_IP_ADDRESS_RANGE=$ip_range
  envsubst < "$MLB_ADDY_POOL" > "$temp"

  echo -n "$temp"
}

# Create an ambient template from helm. This will be mounted as a k3d volume in
# the directory that k3d sources at initialization
function ambient-template-create {
  local temp cluster variant
  cluster=$1
  variant=distroless
  temp=$(mktemp)

  { helm template istio-base "$HELM_CHART"/base                               \
    --version "$HELM_CHART_VER"                                               \
    --namespace istio-system

  helm template istiod "$HELM_CHART"/istiod                                   \
    --version "$HELM_CHART_VER"                                               \
    --namespace istio-system                                                  \
    --set profile=ambient                                                     \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}"                                                  \
    --set "variant=${variant}"                                                \
    --set "global.multiCluster.clusterName=${cluster}"                        \
    --set "global.multiCluster.enabled=true"                                  \
    --set "global.network=${cluster}"                                         \
    --set "env.PILOT_ENABLE_IP_AUTOALLOCATE=true"                             \
    --set "env.PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES=false"                \
    --set "env.PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION=true"             \
    --set "env.PILOT_ENABLE_WORKLOAD_ENTRY_HEALTHCHECKS=true"                 \
    --set "env.PILOT_SKIP_VALIDATE_TRUST_DOMAIN=true"                         \
    --set "meshConfig.trustDomain=${cluster}.local"                           \
    --set "platforms.peering.enabled=true"

  helm template istio-cni "$HELM_CHART"/cni                                   \
    --version "$HELM_CHART_VER"                                               \
    --namespace istio-system                                                  \
    --set profile=ambient                                                     \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}"                                                  \
    --set "variant=${variant}"                                                \
    --set "ambient.dnsCapture=true"

  helm template ztunnel "$HELM_CHART"/ztunnel                                 \
    --version "$HELM_CHART_VER"                                               \
    --namespace istio-system                                                  \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}"                                                  \
    --set "variant=${variant}"                                                \
    --set "multiCluster.clusterName=${cluster}"                               \
    --set "network=${cluster}"                                                \
    --set "env.ISTIO_META_ENABLE_HBONE=true"                                  \
    --set "env.ISTIO_META_DNS_CAPTURE=true"                                   \
    --set "env.L7_ENABLED=true"                                               \
    --set "env.SKIP_VALIDATE_TRUST_DOMAIN=true"
  } >> "$temp" 2> /dev/null

  echo -n "$temp"
}

# kgateway crds. Also mounted as a k3d initialization volume
function kgateway-create {
  local temp
  temp=$(mktemp)

  cat "$K3D_DIR"/kgateway.crds.standard-install."$KGATEWAY_VER".yaml > "$temp"

  echo -n "$temp"
}

# k3d cluster [create|delete] [cluster_name] <ip_range> <region> <zone> <no_of_servers> <enable_ambient>
function k3d-cluster {
  local mode name ip_range zone region no_of_servers enable_ambient

  mode=$1
  name=$2
  ip_range=$3
  region=$4
  zone=$5
  no_of_servers=$6
  enable_ambient=$7

  if [[ $mode == create ]]; then
    if $enable_ambient; then
      AMBIENT_TEMP=$(ambient-template-create "$name")
      KGATEWAY_TEMP=$(kgateway-create)
    else
      AMBIENT_TEMP=$(mktemp)
      KGATEWAY_TEMP=$(mktemp)
    fi

    MLB_TEMP=$(mlb-template-create "$ip_range")

    k3d-cluster-create "$name" <(
      CLUSTER_ID="$name"                                                      \
      K3D_ZONE="$zone"                                                        \
      K3D_REGION="$region"                                                    \
      K3D_SERVERS="$no_of_servers"                                            \
      envsubst                                                                \
      < "$K3D_DIR"/k3d-omni-cluster.template.yaml)
  fi

  if [[ $mode == delete ]]; then
    k3d-cluster-delete "$name"
  fi
  return $?
}

# DEMO clusters. No istio
alias d0up="k3d-cluster create \$DEMO \$IP_RANGE_100 us-west-1 us-west-1a 3 false"
alias d0down="k3d-cluster delete \$DEMO"
alias d1up="k3d-cluster create \$DEMO1 \$IP_RANGE_110 us-west-1 us-west-1b 1 false"
alias d1down="k3d-cluster delete \$DEMO1"

# MGMT cluster. No istio
alias m0up="k3d-cluster create \$MGMT \$IP_RANGE_20 us-west-2 us-west-2a 2 false"
alias m0down="k3d-cluster delete \$MGMT"

# CLUSTER clusters. Ambient enabled
alias c1up="k3d-cluster create \$CLUSTER1 \$IP_RANGE_30 us-west-2 us-west-2a 2 true"
alias c1down="k3d-cluster delete \$CLUSTER1"
alias c2up="k3d-cluster create \$CLUSTER2 \$IP_RANGE_40 us-west-2 us-west-2b 2 true"
alias c2down="k3d-cluster delete \$CLUSTER2"
alias c3up="k3d-cluster create \$CLUSTER3 \$IP_RANGE_50 us-west-2 us-west-2c 2 true"
alias c3down="k3d-cluster delete \$CLUSTER3"
alias c4up="k3d-cluster create \$CLUSTER4 \$IP_RANGE_60 us-west-2 us-west-2d 2 true"
alias c4down="k3d-cluster delete \$CLUSTER4"

# SOLO clusters. Ambient enabled
alias s0up="k3d-cluster create \$SOLO \$IP_RANGE_70 us-east-2 us-east-1a 3 true"
alias s0down="k3d-cluster delete \$SOLO"
alias s1up="k3d-cluster create \$SOLO1 \$IP_RANGE_80 us-east-2 us-east-1b 1 true"
alias s1down="k3d-cluster delete \$SOLO1"
alias s2up="k3d-cluster create \$SOLO2 \$IP_RANGE_90 us-east-2 us-east-1c 2 true"
alias s2down="k3d-cluster delete \$SOLO2"

# END
