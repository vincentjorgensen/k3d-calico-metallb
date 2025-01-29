#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
K3D_DIR=$SCRIPT_DIR/templates

MGMT=mgmt
CLUSTER1=cluster1
CLUSTER2=cluster2
SOLO=solo

CALICO_VER="3.29.1"
K3S_VER="v1.31.4-k3s1"
MLB_VER="v0.14.9"
REGION="us-west-2"

K8S_GATEWAY_API_VER=v1.2.1
ISTIO_VER=1.24.2-solo
ISTIO_REPO=us-docker.pkg.dev/gloo-mesh/istio-4d37697f9711
HELM_CHART=istio
HELM_CHART_VER=1.24.2

export K3D_DIR MGMT CLUSTER1 CLUSTER2 SOLO
export CALICO_VER K3S_VER MLB_VER REGION
export K8S_GATEWAY_API_VER ISTIO_VER ISTIO_REPO HELM_CHART HELM_CHART_VER
export MLB_IP_ADDRESS_RANGE AMBIENT_TEMP MLB_TEMP


# Metal LB template with localhost IP range
function mlb_template {
  local temp
  local ip_range=$1
  temp=$(mktemp)

  MLB_IP_ADDRESS_RANGE=$ip_range
  envsubst < "$K3D_DIR"/metallb-native.address-pool.template.yaml > "$temp"

  echo "$temp"
}

# Istio Ambient Template from Helm Charts
function ambient_template {
  local temp
  local cluster=$1
  local variant=distroless
  temp=$(mktemp)

  { helm template istio-base ${HELM_CHART}/base                               \
    --version ${HELM_CHART_VER}                                               \
    --namespace istio-system

  helm template istiod ${HELM_CHART}/istiod                                   \
    --version ${HELM_CHART_VER}                                               \
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

  helm template istio-cni ${HELM_CHART}/cni                                   \
    --version ${HELM_CHART_VER}                                               \
    --namespace istio-system                                                  \
    --set profile=ambient                                                     \
    --set "hub=${ISTIO_REPO}"                                                 \
    --set "tag=${ISTIO_VER}"                                                  \
    --set "variant=${variant}"                                                \
    --set "ambient.dnsCapture=true"

  helm template ztunnel ${HELM_CHART}/ztunnel                                 \
    --version ${HELM_CHART_VER}                                               \
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

  echo "$temp"
}

# Create a k3d cluster
function create-k3d-cluster  {

  name=$1
  config=$2

  # docker network
  network=k3d-cluster-network
  if [[ -n $DOCKER_NETWORK ]]; then
    network=$DOCKER_NETWORK
  fi

  # create docker network if it does not exist
  docker network create "$network" > /dev/null 2>&1 || true

  # k3d registry create k3d-registry

  k3d cluster create --wait --config "${config}"

  # remove existing ones if they exist
  kubectl config delete-cluster "${name}" > /dev/null 2>&1 || true
  kubectl config delete-user    "${name}" > /dev/null 2>&1 || true
  kubectl config delete-context "${name}" > /dev/null 2>&1 || true

  kubectl config rename-context "k3d-${name}" "${name}"
}

# Delete a k3d cluster
function delete-k3d-cluster {
  name=$1

  # DO NOT DELETE NETWORK
  #network=k3d-cluster-network
  #k3d cluster delete "$name"

  # because we renamed them we need to delete the names
  kubectl config delete-cluster "$name" > /dev/null 2>&1 || true
  kubectl config delete-user "$name" > /dev/null 2>&1 || true
  kubectl config delete-context "$name" > /dev/null 2>&1 || true

  #docker network rm $network > /dev/null 2>&1 || true
}

function k3d-mgmt-up {
  MLB_TEMP=$(mlb_template 192.168.96.20-192.168.96.29)
  AMBIENT_TEMP=$(ambient_template $MGMT)

  create-k3d-cluster $MGMT <(
   CLUSTER_ID="$MGMT"                                                         \
   ZONE="us-west-2a"                                                          \
   NO_OF_SERVERS=1                                                            \
   envsubst                                                                   \
   < "$K3D_DIR"/ambient-cluster.template.yaml)
}

function k3d-cluster1-up {
  MLB_TEMP=$(mlb_template 192.168.96.30-192.168.96.39)
  AMBIENT_TEMP=$(ambient_template $CLUSTER1)

  create-k3d-cluster $CLUSTER1 <(
   CLUSTER_ID="$CLUSTER1"                                                     \
   ZONE="us-west-2b"                                                          \
   NO_OF_SERVERS=2                                                            \
   envsubst                                                                   \
   < "$K3D_DIR"/ambient-cluster.template.yaml)
}

function k3d-cluster2-up {
  MLB_TEMP=$(mlb_template 192.168.96.40-192.168.96.49)
  AMBIENT_TEMP=$(ambient_template $CLUSTER2)

  create-k3d-cluster $CLUSTER2 <(
   CLUSTER_ID="$CLUSTER2"                                                     \
   ZONE="us-west-2c"                                                          \
   NO_OF_SERVERS=2                                                            \
   envsubst                                                                   \
   < "$K3D_DIR"/ambient-cluster.template.yaml)
}

function k3d-mgmt-down {
  delete-k3d-cluster "$MGMT"
}

function k3d-cluster1-down {
  delete-k3d-cluster "$CLUSTER1"
}

function k3d-cluster2-down {
  delete-k3d-cluster "$CLUSTER2"
}

function k3d-solo-up {
  MLB_TEMP=$(mlb_template 192.168.96.50-192.168.96.59)
  AMBIENT_TEMP=$(ambient_template $SOLO)

  create-k3d-cluster "$SOLO" <(
   CLUSTER_ID="$SOLO"                                                         \
   ZONE="us-west-2d"                                                          \
   NO_OF_SERVERS=3                                                            \
   envsubst                                                                   \
   < "$K3D_DIR"/ambient-cluster.template.yaml)
}

function k3d-solo-down {
  delete-k3d-cluster "$SOLO"
}
