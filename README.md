# k3d-calico-metallb

K3D clusters on MacOS with Docker Desktop (or Rancher Desktop) for local testing
and development on MacOS.

[Calico](https://github.com/projectcalico/calico) replaces the default K3D
Traefik in order that I can test Istio in Ambient mode.

I use [MetalLB](https://github.com/metallb/metallb) as the ingress controller.
This works so long as works so long as [Docker Mac Net
Connect](https://github.com/chipmk/docker-mac-net-connect) is installed. Once
set up, I can reference the external IP of cluster services via MetalLB's
load-balancer implemenation; no port-forwarding required.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Installation](#installation)
   * [MacOS](#macos)
- [Usage](#usage)
   * [Simple Test](#simple-test)
   * [Usage notes](#usage-notes)
      + [k3d-registry-dockerd](#k3d-registry-dockerd)
         - [Disable k3d-registry-dockerd](#disable-k3d-registry-dockerd)
      + [Pi-hole](#pi-hole)
   * [Technical Notes](#technical-notes)
      + [Docker Network Subnet](#docker-network-subnet)
      + [Docker Network nat-unprotected (obsolete)](#docker-network-nat-unprotected-obsolete)

<!-- TOC end -->

<!-- TOC --><a name="installation"></a>
# Installation

I have developed k3d-calico-metallb (KCM) for MacOS.

<!-- TOC --><a name="macos"></a>
## MacOS

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).

    It also works with [Rancher
    Desktop](https://docs.rancherdesktop.io/getting-started/installation/), but
    I've noticed that it far less performant than Docker. For example, with
    Docker, I can run four, sometimes more, small clusters. With Rancher, even
    with small clusters, I am unable to deploy more than two.

1. Install [K3D](https://k3d.io/stable/#releases).

    ```bash
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    ```

1. Install `jinja2`, which is needed for templates.

    ```bash
    brew install jinja2
    ```

1. Install [Docker Mac Net Connect](https://github.com/chipmk/docker-mac-net-connect).

    ```bash
    brew install chipmk/tap/docker-mac-net-connect
    sudo brew services start chipmk/tap/docker-mac-net-connect
    ```

<!-- TOC --><a name="usage"></a>
# Usage

First, source `functions.sh` in the top-level of the repo.

```bash
source ./functions.sh
```

In order to create K3D clusters, I've created several convient aliases,
all available for perusal toward the bottom of `functions.sh`.

For example, to start up a management cluster and two workload clusters, all
sized at one node, do:

```bash
m0up
c1up
c2up
```

The three clusters' contexts are `mgmt`, `cluster1`, and `cluster2`.

Finally, Destroy the clusters with: 

```bash
m0down
c1down
c2down
```

<!-- TOC --><a name="simple-test"></a>
## Simple Test

Bring up a single cluster:
```bash
c1up
```

The cluster's context is `cluster1`.

Create a simple httpbin service of type `LoadBalancer`:

```bash
kubectl --context cluster1 apply -f templates/service_mockup.yaml
```

When it's up, this curl command should return 200, proving that it hit the  
httpbin service:

```sh
curl -I $(kubectl get svc/httpbin                                             \
          --context solo                                                      \
          --namespace httpbin                                                 \
          -o=jsonpath='{.status.loadBalancer.ingress[0].ip}{":"}{.spec.ports[0].port}')
```

Destroy the single cluster when you're finished:

```sh
c1down
```

<!-- TOC --><a name="usage-notes"></a>
## Usage notes

The `functions.sh` file has a bash function called `k3d-cluster` that wraps
around all the important cluster creation and deletion logic. It's usage syntax
is:

```text
k3d-cluster -m [create|delte] -c [cluster_name] -r [mlb_cidr_range] -p [k8s_container_cidr] -q [k8s_service_cidr] -e [region_tag] <-s [no. of nodes]>
```

In the samples above, I'll explain two of the convience aliases that I use:

```bash
alias c1up="k3d-cluster -m create -c \$CLUSTER1 -r \$MLB_CIDR1 -p \$CLUSTER_CIDR1 -q \$SERVICE_CIDR1 -e us-west-2"
alias c1down="k3d-cluster -m delete -c \$CLUSTER1"
```

I create a cluster with 1 server node with local MetalLB IPs allocated in
172.172.172.80/28 (14 available IPs). The container IPs are 10.42.0.0/16 and
the service IPs are 0.43.0.0/16.

You can change these values to what fit your needs, or add your own aliases for
the specifics of your development.

<!-- TOC --><a name="k3d-registry-dockerd"></a>
### k3d-registry-dockerd

In order to speed up deployments and to avoid the dreaded docker.io anonymous
pull limit inside a local k8s cluster, I implement
[k3d-registry-dockerd](https://github.com/ligfx/k3d-registry-dockerd). This
proxies the k3d registry through the Docker Desktop (or Rancher Desktop)
registry. If the images are already present, pod instantiation is significantly
faster. For example, on my laptop, I can bring up a three-server ambient-enabled
cluster in under 60 seconds. If to measure how long it takes to bring up cluster
`cluster1`, here is the command line I used to measure the start-up time:

```bash

time (c1up; time kubectl --context cluster1 wait pods -A --for=jsonpath='{.status.phase}'=Running -l topology.kubernetes.io/region=us-west-2)
```

For Docker Desktop v4.62.0, it took 74 seconds the first time. However, the
next time, since the images are now local, it only took 42 seconds.

For Rancher Desktop v1.22.0, it took 82 seconds the first time. However, the
next time, since the images are now local, it only took 44 seconds.

<!-- TOC --><a name="disable-k3d-registry-dockerd"></a>
#### Disable k3d-registry-dockerd

Add the `-y` to `k3d-cluster` command.

<!-- TOC --><a name="pi-hole"></a>
### Pi-hole

KCM also deploys [Pi-hole](https://github.com/pi-hole/docker-pi-hole/) on the
Docker network. If external-dns is deployed correctly on your clusters, you can
use programmable DNS outside your cluster to test URLs that would otherwise
require burdensome curl-hacking, like some SSL setups.

For example, I frequently use `helloworld.example.com` to test whether I've
configured my gateway correctly. Being able to test it from outside the
cluster, with a FQDN, in conjunction with MetalLB, makes my local mock-up feel
more like an actual cloud deploy.

The companion projection, [Kubernetes
Askēma](https://github.com/vincentjorgensen/kubernetes-askema/) (K8SA), makes frequent
use of this.

<!-- TOC --><a name="technical-notes"></a>
## Technical Notes

<!-- TOC --><a name="docker-network-subnet"></a>
### Docker Network Subnet
It is important to start the docker network with the a subnet cidr that
includes the metallb subnets. I got bit by this. For example, the snippet
below (similar to what is used in [functions.sh](./functions.sh#L167) creates
docker network resource.

```bash
# Create a docker network on a defined subnet
docker network create "$DOCKER_NETWORK"                                        \
    --subnet "$NETWORK_SUBNET"                                                 \
    --gateway "$NETWORK_GATEWAY"                                               \
    --ip-range "$CONTAINER_SUBNET"
```

The IP range specifies what containers on the network should use. So nodes of
your k8s clusters or anything in a docker-compose file that doesn't explicitly
set its external IPv4 will be in this range.

Then, the [k3d cluster
template](./templates/k3d-omni-cluster.template.yaml#L7), we specify:

```yaml
network: ${DOCKER_NETWORK}
```

Where `DOCKER_NETWORK` is defined in [functions.sh](./functions.sh#L24).

Finally, in the [metallb address
pool](./templates/metallb-native.address-pool.template.yaml#L9), we chose an ip
range in this cidr.

```yaml
spec:
  addresses:
  - ${MLB_ADDY_RANGE}
```

The ranges in the docker network can be found [here](./functions.sh#L30-L37)

<!-- TOC --><a name="docker-network-nat-unprotected-obsolete"></a>
### Docker Network nat-unprotected (obsolete)

For Docker Desktop greater than `v4.39.0` the network used to need an extra
option:

```bash
docker network create k3d-cluster-network                                      \
  --subnet 10.10.0.0/16                                                        \
  --gateway 10.10.0.1                                                          \
  --ip-range 10.10.97.0/24                                                     \
  --opt "com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected"
```

However, the issue has since been resolved.  [See
this](https://github.com/chipmk/docker-mac-net-connect/issues/48) for details.
I am leaving this here for historical purposes, and because it's likely that
this--or something similar--will happen again.

