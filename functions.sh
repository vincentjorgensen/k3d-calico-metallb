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
NETWORK_SUBNET=172.172.172.0/24
NETWORK_GATEWAY=172.172.172.1
CONTAINER_SUBNET=172.172.172.0/26 # For containers on the docker network, 62 possible hosts

# MLB (external LB) cidrs 14 possible LBs
MLB_CIDR1=172.172.172.80/28  # Range: 81-94
MLB_CIDR2=172.172.172.96/28  # Range: 96-110
MLB_CIDR3=172.172.172.112/28 # Range: 113-126
MLB_CIDR4=172.172.172.128/28 # Range: 129-142
MLB_CIDR5=172.172.172.144/28 # Range: 145-158
MLB_CIDR7=172.172.172.160/28 # Range: 161-173
MLB_CIDR8=172.172.172.175/28 # Range: 176-180
MLB_CIDR8=172.172.172.182/28 # Range: 182-192


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
# In 172.172.172.64/28 # Range: 64-78 (14)
export PIHOLE_IP REGISTRY_IP HELLOWORLD_IP0 HELLOWORLD_IP1 HELLOWORLD_IP2 LIGFX_VER

PIHOLE_IP=172.172.172.69
REGISTRY_IP=172.172.172.72
HELLOWORLD_IP0=172.172.172.64
HELLOWORLD_IP1=172.172.172.65
HELLOWORLD_IP2=172.172.172.66
NETSHOOT_IP=172.172.172.80
# https://github.com/ligfx/k3d-registry-dockerd
LIGFX_VER=v0.10

# K3D names and places
# Calico is required in lieu of Traefik for Istio Ambient
# MetalLb with docker-mac-net-connect allows directly addressable external IPs
# metallb: https://github.com/metallb/metallb
# docker-mac-net-connect: https://github.com/chipmk/docker-mac-net-connect
export K3D_DIR MLB_ADDY_POOL MLB_ADDY_RANGE CALICO_ADDY_RANGE CALICO_ADDY_POOL
export MLB_TEMP KCM_DOCKER_COMPOSE
K3D_DIR=$SCRIPT_DIR/templates
KCM_DOCKER_COMPOSE="$K3D_DIR"/docker-compose.yaml
CALICO_ADDY_POOL="${K3D_DIR}/calico.address-pool.template.yaml"
MLB_ADDY_POOL="${K3D_DIR}/metallb-native.address-pool.template.yaml"

# k8s cluster versions
export CALICO_VER MLB_VER K3D_TEMPLATE K3S_VER_132 K3S_VER_133
export K3S_VER K3S_VER_132 K3S_VER_133 K3S_VER_134 K3S_VER_135
CALICO_VER="3.31.4"                        # https://github.com/projectcalico/calico/tags # Don't forget to download new manifest and put in $K3D_DIR when upgrading
#CALICO_VER="3.30.6"                        # https://github.com/projectcalico/calico/tags # Don't forget to download new manifest and put in $K3D_DIR when upgrading
                                           # https://raw.githubusercontent.com/projectcalico/calico/v3.30.5/manifests/calico.yaml
K3S_VER_132="v1.32.12-k3s1"                # https://hub.docker.com/r/rancher/k3s/tags?name=v1.32
K3S_VER_133="v1.33.8-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.33
K3S_VER_134="v1.34.4-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.34
K3S_VER_135="v1.35.1-k3s1"                 # https://hub.docker.com/r/rancher/k3s/tags?name=v1.35 1.35.1 is good, testing 1.35.3 now, 1.35.2 was sloow to come up
MLB_VER="v0.15.3"                          # https://github.com/metallb/metallb/tags
                                           # https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml 
                                           # metallb-native.address-pool.template.yaml
K3S_VER=$K3S_VER_135

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
           -D netshoot_ip="$NETSHOOT_IP"                                       \
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
    echo "INFO[S012] KCM: $KCM_DOCKER_COMPOSE already exists"
  fi
}

# k3d-registry-dockerd, a docker proxy that elimiates anonymous docker login errors in k8s
# Docker Desktop must be running
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

# Helloworld container external to the cluster but on DOCKER_NETWORK
function _external_netshoot {
  _external_docker_compose netshoot "$1"
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

# docker network for k3d clusters
function docker-k3d-network {
  local mode=${1:-status}

  if [[ $mode == start ]]; then
    if ! docker-k3d-network status; then
      docker network create "$DOCKER_NETWORK"                                  \
        --subnet "$NETWORK_SUBNET"                                             \
        --gateway "$NETWORK_GATEWAY"                                           \
        --ip-range "$CONTAINER_SUBNET" > /dev/null 2>&1
      if [[ $? -lt 1 ]]; then
        echo "INFO[S004] KCM: docker network $DOCKER_NETWORK created on subnet $NETWORK_SUBNET"
      else
        echo "ERROR[S024] KCM: unable to create docker network $DOCKER_NETWORK"
        echo "ERROR[S024] KCM: command was: docker network create $DOCKER_NETWORK --subnet $NETWORK_SUBNET --gateway $NETWORK_GATEWAY --ip-range $CONTAINER_SUBNET"
      fi
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
  _external_netshoot start

###  cat "$config"
###  return

  k3d cluster create --wait --config "${config}"

  # remove existing ones if they exist
  kubectl config delete-cluster "$name" > /dev/null 2>&1 || true
  kubectl config delete-user    "admin@${name}" > /dev/null 2>&1 || true
  kubectl config delete-context "$name" > /dev/null 2>&1 || true

  kubectl config rename-context "k3d-${name}" "$name"

  _kubeconfig_adjust_server_address "$name"

  _wait_for_pods "$name" metallb-system metallb
}

function _kubeconfig_adjust_server_address {
  local _server_address _server_ip _server_port _temp_kubeconfig

  # Only needed on work laptop, independent of Docker or Rancher
  if ! [[ $(hostname) =~ RIV ]]; then
    return
  fi
  _server_address=$(yq '.clusters[] | select (.name == "k3d-'"$1"'") | .cluster.server' ~/.kube/config)

  if [[ $_server_address =~ 0.0.0.0 ]]; then
    _temp_kubeconfig=$(mktemp)
    _server_ip=$(echo "$_server_address" | sed -e 's;https://\(.*\);\1;'|awk -F: '{print $1}')
    _server_port=$(echo "$_server_address" | sed -e 's;https://\(.*\);\1;'|awk -F: '{print $2}')


    sed -e 's;\(.*server:\) 'https://"$_server_ip"':'"$_server_port"';\1 https://127.0.0.1:'"$_server_port"';' ~/.kube/config > "$_temp_kubeconfig"
    cp "$_temp_kubeconfig" ~/.kube/config
  fi
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

function _fetch_calico_config {
  if ! [[ -e ${K3D_DIR}/calico-${CALICO_VER}.yaml ]]; then
    curl -qfsSL https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/calico.yaml > "${K3D_DIR}/calico-${CALICO_VER}.yaml"
  fi
}

function _fetch_metallb_config {
	if ! [[ -e ${K3D_DIR}/metallb-native-${MLB_VER}.yaml ]]; then
		curl -qfsSL https://raw.githubusercontent.com/metallb/metallb/${MLB_VER}/config/manifests/metallb-native.yaml > "${K3D_DIR}/metallb-native-${MLB_VER}.yaml"
	fi
}


function create-feature-map {
  local _calico _mlb _ew _ip_range _cluster_name _pihole
  local _temp _pod_ip_range

  _temp=$(mktemp)

  _cluster_name=no_name

  _pihole=true
  _calico=true
  _mlb=true
  _ew=false

  while getopts "c:p:r:" opt; do
    # shellcheck disable=SC2220
    case $opt in
      c)
        _cluster_name=$OPTARG ;;
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
    _fetch_calico_config
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
    _fetch_metallb_config
    cat <<EOF >> "$_temp"
  ${K3D_DIR}/metallb-native-${MLB_VER}.yaml: 10-metallb-native.yaml
  $(mlb-template-create "$_ip_range"): 11-metallb-native.address-pool.yaml
EOF
  fi

  (echo zones:; for i in {a..z}; do echo - - "$i"; done) >> "$_temp"

  cp "$_temp" "${_temp}.yaml"
  echo -n "${_temp}.yaml"
}

# k3d cluster -m [create|delete|status] -c [cluster_name] -r <ip_range> -e <region> -s <no_of_servers> <-y disable_dockerproxy>
function k3d-cluster {
  local _ip_range _mode _cluster_name _region _no_servers _dproxy
  local _cluster_cidr _service_cidr
  local _dry_run

  _cluster_name=no_name
  _region=no_region
  _no_servers=1
  _dproxy=enabled
  _dry_run=false

  while getopts "c:de:m:p:q:r:s:y" opt; do
    # shellcheck disable=SC2220
    case $opt in
      c) # Cluster name
        _cluster_name=$OPTARG ;;
      d) # Just print out the k3d config file
        _dry_run=true ;;
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
             "$(create-feature-map -p "$_cluster_cidr" -r "$_ip_range" -c "$_cluster_name")" ) \
    "$_dry_run"
  
  elif [[ $_mode == delete ]]; then
    k3d-cluster-delete "$_cluster_name"

  elif [[ $_mode == status ]]; then
    k3d cluster ls "$_cluster_name" > /dev/null 2>&1
  fi
  return $?
}

function docker-external-services {
  local mode=${1:-status}

  if [[ $mode == start ]]; then
    docker-k3d-network start
    _external_helloworld start
    _external_registry start
    _external_pihole start
  elif [[ $mode == stop ]]; then
    _external_helloworld stop
    _external_registry stop
    _external_pihole stop
  elif [[ $mode == status ]]; then
    _external_helloworld status &&                                             \
    _external_registry status &&                                               \
    _external_pihole status
  fi
  return $?
}

function _wait_for_pods {
  local _context=$1
  local _namespace=$2
  local _app=$3

  echo "INFO[S005] KCM: waiting for app=$_app to be ready"
  kubectl wait pods                                                            \
  --context "$_context"                                                        \
  --namespace "$_namespace"                                                    \
  --for=condition=Ready -l app="$_app" --timeout=60s
}

# DEMO clusters
alias d0up3="k3d-cluster -m create -c \$DEMO -r \$MLB_CIDR7 -p \$CLUSTER_CIDR7 -q \$SERVICE_CIDR7 -e us-west-1 -s 3"
alias d0down="k3d-cluster -m delete -c \$DEMO"
alias d1up="k3d-cluster -m create -c \$DEMO1 -r \$MLB_CIDR8 -p \$CLUSTER_CIDR8 -q \$SERVICE_CIDR8 -e us-west-1"
alias d1down="k3d-cluster -m delete -c \$DEMO1"

# MGMT cluster
alias m0up="k3d-cluster -m create -c \$MGMT -r \$MLB_CIDR6 -p \$CLUSTER_CIDR6 -q \$SERVICE_CIDR6 -e us-west-2"
alias m0down="k3d-cluster -m delete -c \$MGMT"
alias m0u=m0up
alias m0d=m0down

# CLUSTER clusters. Ambient enabled with 'a' otherwise, vanilla
# _np is without dockerproxy
alias c1up="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2"
alias c1up3="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2 -s 3"
alias c1up_np="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2 -y"
alias c1down="k3d-cluster -m delete -c \$CLUSTER1"
alias c1u=c1up
alias c1d=c1down

alias c2up="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2"
alias c2up3="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2 -s 3"
alias c2up_np="k3d-cluster -m create -c \$CLUSTER2 -r \$MLB_CIDR2 -p \$CLUSTER_CIDR2 -q \$SERVICE_CIDR2 -e us-east-2 -y"
alias c2down="k3d-cluster -m delete -c \$CLUSTER2"
alias c2u=c2up
alias c2d=c2down

alias c3up="k3d-cluster -m create -c \$CLUSTER3 -r \$MLB_CIDR3 -p \$CLUSTER_CIDR3 -q \$SERVICE_CIDR3 -e us-west-1"
alias c3up_np="k3d-cluster -m create -c \$CLUSTER3 -r \$MLB_CIDR3 -p \$CLUSTER_CIDR3 -q \$SERVICE_CIDR3 -e us-west-1 -y"
alias c3down="k3d-cluster -m delete -c \$CLUSTER3"
alias c3u=c3up
alias c3d=c3down

alias c4up="k3d-cluster -m create -c \$CLUSTER4 -r \$MLB_CIDR4 -p \$CLUSTER_CIDR4 -q \$SERVICE_CIDR4 -e us-east-1"
alias c4up_np="k3d-cluster -m create -c \$CLUSTER4 -r \$MLB_CIDR4 -p \$CLUSTER_CIDR4 -q \$SERVICE_CIDR4 -e us-east-1 -y"
alias c4down="k3d-cluster -m delete -c \$CLUSTER4"
alias c4u=c4up
alias c4d=c4down

# ArgoCD
alias a0up=    "k3d-cluster -m create -c \$ARGOCD -r \$MLB_CIDR5 -p \$CLUSTER_CIDR5 -q \$SERVICE_CIDR5 -e us-west-2"
alias a0down=  "k3d-cluster -m delete -c \$ARGOCD"

# Cluster resets
function c1j { c1down;c1up; }
function c2j { c2down;c2up; }
function c3j { c3down;c3up; }
function c4j { c4down;c4up; }
function m0j { m0down;m0up; }
function d0j { d0down;d0up; }

#------------------------------------------------------------------------------
# Non KCM helper functions
#------------------------------------------------------------------------------
# view running docker compose helper containers
alias kdcps='docker compose --project-directory '"\$K3D_DIR"' ps'

# bring up a KCM service
function kdcu {
  docker compose --project-directory "$K3D_DIR" up "$1" -d
}

# bring down a KCM service
function kdcd {
  docker compose --project-directory "$K3D_DIR" down "$1"
}

function knets {
  docker compose --project-directory "$K3D_DIR" exec -it netshoot zsh
}

# Docker Mac Connect
# https://github.com/chipmk/docker-mac-net-connect
function start_docker_mac_connect {
  if [[ -z $1 ]]; then 
    sudo brew services start chipmk/tap/docker-mac-net-connect
  else
    sudo brew services stop chipmk/tap/docker-mac-net-connect
  fi
}

# Rancher Desktop destroys the network between restarts (Docker Desktop retains it)
# Creating a cluster will always perform these steps, but somethings I want to 
# test functions prior to initializing a cluster.
function kcm_init {
  docker-k3d-network create

  _external_registry start
  _external_pihole start
  _external_helloworld start
  _external_netshoot start
}

# End
