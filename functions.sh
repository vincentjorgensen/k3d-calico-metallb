#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export K3D_DIR=$SCRIPT_DIR/templates

export MGMT=mgmt
export CLUSTER1=cluster1
export CLUSTER2=cluster2

export CALICO_VER="3.28.1"
export K3S_VER="v1.30.3-k3s1"
export MLB_VER="v0.14.8"
export REGION="us-west-2"

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

function delete-k3d-cluster {
  name=$1

  network=k3d-cluster-network
  k3d cluster delete "$name"

  # because we renamed them we need to delete the names
  kubectl config delete-cluster "$name" > /dev/null 2>&1 || true
  kubectl config delete-user "$name" > /dev/null 2>&1 || true
  kubectl config delete-context "$name" > /dev/null 2>&1 || true

  docker network rm $network > /dev/null 2>&1 || true
}

function k3d-up {
  create-k3d-cluster $MGMT <(
   CLUSTER_ID="$MGMT"                             \
   ZONE="us-west-2a"                              \
   NO_OF_SERVERS=1                                \
   envsubst                                       \
   < "$K3D_DIR"/generic-cluster.template.yaml)
  create-k3d-cluster $CLUSTER1 <(
   CLUSTER_ID="$CLUSTER1"                         \
   ZONE="us-west-2b"                              \
   NO_OF_SERVERS=2                                \
   envsubst                                       \
   < "$K3D_DIR"/generic-cluster.template.yaml)
  create-k3d-cluster $CLUSTER2 <(
   CLUSTER_ID="$CLUSTER2"                         \
   ZONE="us-west-2c"                              \
   NO_OF_SERVERS=2                                \
   envsubst                                       \
   < "$K3D_DIR"/generic-cluster.template.yaml)
}

function k3d-down {
  delete-k3d-cluster $MGMT
  delete-k3d-cluster $CLUSTER1
  delete-k3d-cluster $CLUSTER2
}

function k3d-solo-up {
  create-k3d-cluster $SOLO <(
   CLUSTER_ID="$SOLO"                             \
   ZONE="us-west-2a"                              \
   NO_OF_SERVERS=3                                \
   envsubst                                       \
   < "$K3D_DIR"/generic-cluster.template.yaml)
}

function k3d-solo-down {
  delete-k3d-cluster $SOLO
}
