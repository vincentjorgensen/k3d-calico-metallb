#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

# k3d (k8s) cluster names
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
CALICO_VER="3.30.3"                        # https://github.com/projectcalico/calico/tags # Don't forget to download new manifest and put in $K3D_DIR when upgrading
                                           # https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/calico.yaml
#K3S_VER="v1.32.8-k3s1"                    # https://hub.docker.com/r/rancher/k3s/tags
K3S_VER="v1.33.4-k3s1"                     # https://hub.docker.com/r/rancher/k3s/tags
#MLB_VER="v0.14.9"                          # https://github.com/metallb/metallb/tags
MLB_VER="v0.15.2"                          # https://github.com/metallb/metallb/tags
                                           # https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml 
                                           # metallb-native.address-pool.template.yaml

# HELM and ISTIO versions
export KGATEWAY_VER ISTIO_VER ISTIO_REPO HELM_CHART K8S_TRUST_DOMAIN
KGATEWAY_VER=v1.2.1
ISTIO_VER=1.25.3
HELM_REPO=us-docker.pkg.dev/soloio-img/istio-helm
ISTIO_REPO=us-docker.pkg.dev/soloio-img/istio
#HELM_REPO=istio
#ISTIO_REPO=istio
K8S_TRUST_DOMAIN='k8s.cluster.local'

# k3d-registry-dockerd, a docker proxy that elimiates anonymous docker login errors in k8s
# Docker Desktop must be running (TBD does this work with Rancher Desktop?)
# https://github.com/ligfx/k3d-registry-dockerd
function dockerproxy {
  local modedocker-pihole-dns-server
  mode=$1

  if [[ $mode == start ]]; then
    ###local _create_log; _create_log=$(mktemp)
    ###k3d registry create -i ligfx/k3d-registry-dockerd:v0.10                   \
    ###  --default-network $DOCKER_NETWORK                                       \
    ###  -v /var/run/docker.sock:/var/run/docker.sock                            \
    ###  dockerproxy > "$_create_log" 2>&1

    ###if grep -q "A registry node with that name already exists" "$_create_log"; then
    ###  dockerproxy stop
    ###  dockerproxy start
    ###fi
    docker compose -f <(jinja2 -D registry_ip=192.168.96.3 -D ligfx_ver=v0.10 -D network="$DOCKER_NETWORK" "$K3D_DIR"/registry.docker-compose.yaml.j2) --project-directory "$K3D_DIR" up -d

  elif [[ $mode == stop ]]; then
    ###k3d registry delete k3d-dockerproxy
    docker compose -f <(jinja2 -D registry_ip=192.168.96.3 -D ligfx_ver=v0.10 -D network="$DOCKER_NETWORK" "$K3D_DIR"/registry.docker-compose.yaml.j2) --project-directory "$K3D_DIR" down registry

  elif [[ $mode == status ]]; then
###    docker ps -f name=k3d-dockerproxy |
###      grep -E '\<k3d-dockerproxy\>' > /dev/null 2>&1
    docker compose -f <(jinja2 -D registry_ip=192.168.96.3 -D ligfx_ver=v0.10 -D network="$DOCKER_NETWORK" "$K3D_DIR"/registry.docker-compose.yaml.j2) --project-directory "$K3D_DIR" ps | grep registry | grep -q healthy
  fi
  return $?
}

function docker-pihole-dns-server {
  local _mode
  _mode=$1

  if [[ $_mode == start ]]; then
    docker compose -f <(jinja2 -D network="$DOCKER_NETWORK" "$K3D_DIR"/pihole.docker-compose.yaml.j2) --project-directory "$K3D_DIR" up -d
  elif [[ $_mode == stop ]]; then
    echo 
    docker compose -f <(jinja2 -D network="$DOCKER_NETWORK" "$K3D_DIR"/pihole.docker-compose.yaml.j2) --project-directory "$K3D_DIR" down pihole
  elif [[ $_mode == status ]]; then
    docker compose -f <(jinja2 -D network="$DOCKER_NETWORK" "$K3D_DIR"/pihole.docker-compose.yaml.j2) --project-directory "$K3D_DIR" ps | grep pihole | grep -q healthy
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
  local config name _dry_run
  name=$1
  config=$2
  _dry_run=${3:-false}
  
  if $_dry_run; then
    cat "$config"
    return
  fi
  # create docker network if it does not exist
  if ! docker-k3d-network status "$DOCKER_NETWORK"; then
    docker-k3d-network start "$DOCKER_NETWORK" "$DOCKER_SUBNET"
  fi

  if ! dockerproxy status; then
    dockerproxy start
  fi

  if ! docker-pihole-dns-server status; then
    docker-pihole-dns-server start
  fi

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

function mlb-template-create {
  local temp ip_range
  ip_range=$1
  temp=$(mktemp)

  MLB_ADDY_RANGE=$ip_range
  envsubst < "$MLB_ADDY_POOL" > "$temp"

  echo -n "$temp"
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
  local _temp _argocd_temp

  _temp=$(mktemp)

  _cluster_name=no_name

  _pihole=true
  _calico=true
  _mlb=true
  _istio=false
  _ew=false
  _argocd=false

  while getopts "ac:ir:" opt; do
    # shellcheck disable=SC2220
    case $opt in
      a)
        _argocd=true ;;
      c)
        _cluster_name=$OPTARG ;;
      i)
        _istio=true ;;
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
EOF
  fi
  # Pihole
  if $_pihole; then
    cat <<EOF >> "$_temp"
  ${K3D_DIR}/configmap.coredns.pihole.yaml: 01-pihole.yaml
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
  local _dry_run

  _cluster_name=no_name
  _region=no_region
  _no_servers=1
  _dproxy=enabled
  _istio=""
  _argocd=""
  _dry_run=false

  while getopts "ac:die:m:r:s:y" opt; do
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

  if [[ $_mode == create ]]; then
    
    k3d-cluster-create "$_cluster_name" <(
      jinja2                                                                  \
             -D cluster_id="$_cluster_name"                                   \
             -D docker_network="$DOCKER_NETWORK"                              \
             -D k3d_region="$_region"                                         \
             -D k3s_ver="$K3S_VER"                                            \
             -D num_of_nodes="$_no_servers"                                   \
             -D enable_dockerproxy="$_dproxy"                                 \
             "$K3D_DIR"/k3d-omni-cluster.volumes.template.yaml.j2             \
             "$(create-feature-map -r "$_ip_range" -c "$_cluster_name" $_argocd $_istio)" ) \
    "$_dry_run"
  
  elif [[ $_mode == delete ]]; then
    k3d-cluster-delete "$_cluster_name"

  elif [[ $_mode == status ]]; then
    k3d cluster ls "$_cluster_name" > /dev/null 2>&1
  fi
  return $?
}

# DEMO clusters. No istio
alias d0up3="k3d-cluster -m create -c \$DEMO -r \$IP_RANGE_100 -e us-west-1 -s 3"
alias d0down="k3d-cluster -m delete -c \$DEMO"
alias d1up="k3d-cluster -m create -c \$DEMO1 -r \$IP_RANGE_110 -e us-west-1"
alias d1down="k3d-cluster -m delete -c \$DEMO1"

# MGMT cluster. No istio
alias m0up="k3d-cluster -m create -c \$MGMT -r \$IP_RANGE_120 -e us-west-2"
alias m0down="k3d-cluster -m delete -c \$MGMT"

# CLUSTER clusters. Ambient enabled with 'a' otherwise, vanilla
# _np is without dockerproxy
alias c1up3a="k3d-cluster -m create -c \$CLUSTER1 -r \$IP_RANGE_30 -e us-west-2 -s 3 -i"
alias c1up="k3d-cluster -m create -c \$CLUSTER1 -r \$IP_RANGE_30 -e us-west-2"
alias c1up3="k3d-cluster -m create -c \$CLUSTER1 -r \$IP_RANGE_30 -e us-west-2 -s 3"
alias c1up_np="k3d-cluster -m create -c \$CLUSTER1 -r \$IP_RANGE_30 -e us-west-2 -y"
alias c1down="k3d-cluster -m delete -c \$CLUSTER1"
alias c2upa="k3d-cluster -m create -c \$CLUSTER2 -r \$IP_RANGE_40 -e us-east-2 -i"
alias c2up="k3d-cluster -m create -c \$CLUSTER2 -r \$IP_RANGE_40 -e us-east-2"
alias c2up3="k3d-cluster -m create -c \$CLUSTER2 -r \$IP_RANGE_40 -e us-east-2 -s 3"
alias c2up_np="k3d-cluster -m create -c \$CLUSTER2 -r \$IP_RANGE_40 -e us-east-2 -y"
alias c2down="k3d-cluster -m delete -c \$CLUSTER2"
alias c3upa="k3d-cluster -m create -c \$CLUSTER3 -r \$IP_RANGE_50 -e us-west-1 -i"
alias c3up="k3d-cluster -m create -c \$CLUSTER3 -r \$IP_RANGE_50 -e us-west-1"
alias c3up_np="k3d-cluster -m create -c \$CLUSTER3 -r \$IP_RANGE_50 -e us-west-1 -y"
alias c3down="k3d-cluster -m delete -c \$CLUSTER3"
alias c4upa="k3d-cluster -m create -c \$CLUSTER4 -r \$IP_RANGE_60 -e us-east-1 -i"
alias c4up="k3d-cluster -m create -c \$CLUSTER4 -r \$IP_RANGE_60 -e us-east-1"
alias c4up_np="k3d-cluster -m create -c \$CLUSTER4 -r \$IP_RANGE_60 -e us-east-1 -y"
alias c4down="k3d-cluster -m delete -c \$CLUSTER4"

# ArgoCD
alias a0up="k3d-cluster -m create -c \$ARGOCD -r \$IP_RANGE_100 -e us-west-2 -a"
alias a0down="k3d-cluster -m delete -c \$ARGOCD"

# Cluster resets
function c1j { c1down;c1up; }
function c2j { c2down;c2up; }
function c3j { c3down;c3up; }
function c4j { c4down;c4up; }
function m0j { m0down;m0up; }

# End
