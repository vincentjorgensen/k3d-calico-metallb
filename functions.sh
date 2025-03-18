#!/usr/bin/env bash
# k3d (k8s) cluster names
export MGMT CLUSTER1 CLUSTER2 CLUSTER3 CLUSTER4 DEMO DEMO1
DEMO=demo
DEMO1=demo1
MGMT=mgmt
CLUSTER1=cluster1
CLUSTER2=cluster2
CLUSTER3=cluster3
CLUSTER4=cluster4

# Docker network and subnet plus IP ranges
# The IP ranges must be in the subnet cidr
export DOCKER_NETWORK DOCKER_SUBNET 
export IP_RANGE_20 IP_RANGE_40 IP_RANGE_60 IP_RANGE_80 IP_RANGE_100
export IP_RANGE_30 IP_RANGE_50 IP_RANGE_70 IP_RANGE_90 IP_RANGE_110
export IP_RANGE_120 IP_RANGE_130 IP_RANGE_140 IP_RANGE_150 IP_RANGE_160
export IP_RANGE_170 IP_RANGE_180 IP_RANGE_190
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
IP_RANGE_120=192.168.96.120-192.168.96.129
IP_RANGE_130=192.168.96.130-192.168.96.139
IP_RANGE_140=192.168.96.140-192.168.96.149
IP_RANGE_150=192.168.96.150-192.168.96.159
IP_RANGE_160=192.168.96.160-192.168.96.169
IP_RANGE_170=192.168.96.170-192.168.96.179
IP_RANGE_180=192.168.96.180-192.168.96.189
IP_RANGE_190=192.168.96.190-192.168.96.199

# K3D names and places
export K3D_DIR MLB_ADDY_POOL MLB_ADDY_RANGE CLUSTER_ID
export MLB_TEMP AMBIENT_TEMP KGATEWAY_TEMP CA_CERT_TEMP ISTIO_SYSTEM_NS_TEMP
export EW_GATEWAY_TEMP
K3D_DIR=$SCRIPT_DIR/templates
MLB_ADDY_POOL="${K3D_DIR}/metallb-native.address-pool.template.yaml"

# k8s cluster versions
export CALICO_VER K3S_VER MLB_VER K3D_TEMPLATE
CALICO_VER="3.29.2"                        # https://github.com/projectcalico/calico/tags
                                           # https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml
K3S_VER="v1.31.6-k3s1"                     # https://hub.docker.com/r/rancher/k3s/tags
MLB_VER="v0.14.9"                          # https://github.com/metallb/metallb/tags
                                           # https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml 
                                           # metallb-native.address-pool.template.yaml

# HELM and ISTIO versions
export KGATEWAY_VER ISTIO_VER ISTIO_REPO HELM_CHART HELM_CHART_VER
KGATEWAY_VER=v1.2.1
ISTIO_VER=1.24.3
ISTIO_REPO=docker.io/istio
HELM_CHART=istio
HELM_CHART_VER=1.24.3

# k3d-registry-dockerd, a docker proxy that elimiates anonymous docker login errors in k8s
# Docker Desktop must be running (TBD does this work with Rancher Desktop?)
# https://github.com/ligfx/k3d-registry-dockerd
function dockerproxy {
  local mode
  mode=$1

  if [[ $mode == start ]]; then
    k3d registry create -i ligfx/k3d-registry-dockerd:v0.8                    \
      --default-network $DOCKER_NETWORK                                       \
      -v /var/run/docker.sock:/var/run/docker.sock                            \
      dockerproxy

  elif [[ $mode == stop ]]; then
    k3d registry delete k3d-dockerproxy

  elif [[ $mode == status ]]; then
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

  # Note: https://github.com/chipmk/docker-mac-net-connect/issues/48
  if [[ $mode == start ]]; then
    docker network create "$network"                                          \
      --subnet "$subnet"                                                      \
      --opt "com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected"     \
    > /dev/null 2>&1

  elif [[ $mode == stop ]]; then
    docker network rm "$network" > /dev/null 2>&1

  elif [[ $mode == status ]]; then
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
  if ! docker-k3d-network status "$DOCKER_NETWORK"; then
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
  local temp ip_range
  ip_range=$1
  temp=$(mktemp)

  MLB_ADDY_RANGE=$ip_range
  envsubst < "$MLB_ADDY_POOL" > "$temp"

  echo -n "$temp"
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
    --set "env.SKIP_VALIDATE_TRUST_DOMAIN=true"                               \
    --set "l7Telemetry.distributedTracing.enabled=true"
  } >> "$temp" 2> /dev/null

  echo -n "$temp"
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

# kgateway crds. Also mounted as a k3d initialization volume
function kgateway-create {
  local temp
  temp=$(mktemp)

  cat "$K3D_DIR"/kgateway.crds.standard-install."$KGATEWAY_VER".yaml > "$temp"

  echo -n "$temp"
}

# k3d cluster [create|delete] [cluster_name] <ip_range> <region> <zone> <no_of_servers> <enable_ambient>
function k3d-cluster {
  local mode name ip_range region no_of_servers enable_ambient

  mode=$1
  name=$2
  ip_range=$3
  region=$4
  no_of_servers=$5
  enable_ambient=$6

#  echo "mode=$mode; name=$name; ip_range=$ip_range; region=$region; no_of_servers=$no_of_servers; enable_ambient=$enable_ambient"

  if [[ $mode == create ]]; then
    if $enable_ambient; then
      AMBIENT_TEMP=$(ambient-template-create "$name")
      CA_CERT_TEMP=$(ca-cert-template-create "$name")
      KGATEWAY_TEMP=$(kgateway-create)
      ISTIO_SYSTEM_NS_TEMP=$(istio-system-namespace-create "$name")
#      EW_GATEWAY_TEMP=$(ew-gateway-create "$name")
      EW_GATEWAY_TEMP=$(mktemp)
    else
      AMBIENT_TEMP=$(mktemp)
      CA_CERT_TEMP=$(mktemp)
      KGATEWAY_TEMP=$(mktemp)
      ISTIO_SYSTEM_NS_TEMP=$(mktemp)
      EW_GATEWAY_TEMP=$(mktemp)
    fi

    MLB_TEMP=$(mlb-template-create "$ip_range")

#  echo "AMBIENT_TEMP=$AMBIENT_TEMP; CA_CERT_TEMP=$CA_CERT_TEMP; CALICO_VER=$CALICO_VER; name=$name; DOCKER_NETWORK=$DOCKER_NETWORK; EW_GATEWAY_TEMP=$EW_GATEWAY_TEMP; ISTIO_SYSTEM_NS_TEMP=$ISTIO_SYSTEM_NS_TEMP; K3D_DIR=$K3D_DIR; KGATEWAY_TEMP=$KGATEWAY_TEMP; KGATEWAY_TEMP=$KGATEWAY_TEMP; MLB_TEMP=$MLB_TEMP; MLB_VER=$MLB_VER; no_of_servers=$no_of_servers"

  k3d-cluster-create "$name" <(
      jinja2                                                                  \
             -D ambient_temp="$AMBIENT_TEMP"                                  \
             -D ca_cert_temp="$CA_CERT_TEMP"                                  \
             -D calico_ver="$CALICO_VER"                                      \
             -D cluster_id="$name"                                            \
             -D docker_network="$DOCKER_NETWORK"                              \
             -D ew_gateway_temp="$EW_GATEWAY_TEMP"                            \
             -D istio_system_ns_temp="$ISTIO_SYSTEM_NS_TEMP"                  \
             -D k3d_dir="$K3D_DIR"                                            \
             -D k3d_region="$region"                                          \
             -D k3s_ver="$K3S_VER"                                            \
             -D kgateway_temp="$KGATEWAY_TEMP"                                \
             -D mlb_temp="$MLB_TEMP"                                          \
             -D mlb_ver="$MLB_VER"                                            \
             -D num_of_nodes="$no_of_servers"                                 \
             "$K3D_DIR"/k3d-omni-cluster.template.yaml.j2                     \
             "$K3D_DIR"/zone-map.yaml)
  
  elif [[ $mode == delete ]]; then
    k3d-cluster-delete "$name"

  elif [[ $mode == status ]]; then
    k3d cluster ls "$name" > /dev/null 2>&1
  fi
  return $?
}

# DEMO clusters. No istio
alias d0up="k3d-cluster create \$DEMO \$IP_RANGE_100 us-west-1 3 false"
alias d0down="k3d-cluster delete \$DEMO"
alias d1up="k3d-cluster create \$DEMO1 \$IP_RANGE_110 us-west-2 1 false"
alias d1down="k3d-cluster delete \$DEMO1"

# MGMT cluster. No istio
alias m0up="k3d-cluster create \$MGMT \$IP_RANGE_20 us-west-1 2 false"
alias m0down="k3d-cluster delete \$MGMT"

# CLUSTER clusters. Ambient enabled with 'a' otherwise, vanilla
alias c1upa="k3d-cluster create \$CLUSTER1 \$IP_RANGE_30 us-west-1 3 true"
alias c1up="k3d-cluster create \$CLUSTER1 \$IP_RANGE_30 us-west-1 3 false"
alias c1down="k3d-cluster delete \$CLUSTER1"
alias c2upa="k3d-cluster create \$CLUSTER2 \$IP_RANGE_40 us-east-1 2 true"
alias c2up="k3d-cluster create \$CLUSTER2 \$IP_RANGE_40 us-east-1 2 false"
alias c2down="k3d-cluster delete \$CLUSTER2"
alias c3upa="k3d-cluster create \$CLUSTER3 \$IP_RANGE_50 us-west-2 2 true"
alias c3up="k3d-cluster create \$CLUSTER3 \$IP_RANGE_50 us-west-2 2 false"
alias c3down="k3d-cluster delete \$CLUSTER3"
alias c4upa="k3d-cluster create \$CLUSTER4 \$IP_RANGE_60 us-east-2 2 true"
alias c4up="k3d-cluster create \$CLUSTER4 \$IP_RANGE_60 us-east-2 2 false"
alias c4down="k3d-cluster delete \$CLUSTER4"

# END
