# k3d-calico-metallb

K3D clusters on MacOS with Docker Desktop for local testing and development.

Calico replaces the default K3D Traefik in order that I can test Istio Ambient.

MetalLB works so long as Docker Mac Net Connect is installed. That is, one can
reference the external IP of cluster services via MetalLB's load-balander
implemenation; no port-forwarding required.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Installation](#macos)
   * [MacOS](#macos)
- [Usage](#uage)
   * [Simple Test](#simple-test)
- [Usage notes](#usage-notes)
   * [k3d-registry-dockerd](#k3d-registry-dockerd)
   * [Pi-hole DNS](#pihole-dns)
- [Technical Notes](#technical-notes)

<!-- TOC end -->

<!-- TOC --><a name="installation"></a>
# Installation

Currently, I have only developed k3d-calico-metallb (KCM) for MacOS.

<!-- TOC --><a name="macos"></a>
## MacOS

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).

    It also works nominally with [Rancher
    Desktop](https://docs.rancherdesktop.io/getting-started/installation/), but
    I've noticed that it far less performant with Rancher. For example, with
    Docker, I can run four, sometimes more, small clusters. With Rancher, even with
    small clusters, I am unable to deploy more than two.

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

Now, in order to create K3D clusters, I've created several convient aliases,
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
s0up
```

The cluster's context is `solo`.

Create a simple httpbin service of type `LoadBalancer`:

```bash
kubectl --context solo apply -f templates/service_mockup.yaml
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
s0down
```

<!-- TOC --><a name="usage-notes"></a>
## Usage notes

The `functions.sh` file has a bash function called `k3d-cluster` that wraps
around all the important cluster creation and deletion logic. It's usage syntax
is:

```text
k3d cluster [create|delete] [cluster_name] <ip_range> <region> <zone> <no_of_servers> <enable_ambient>
```

In the samples above, I'll explain two of the convience aliases that I use:

```bash
alias d0up3="k3d-cluster -m create -c \$DEMO -r \$IP_RANGE_100 -e us-west-1 -s 3"
alias d0down="k3d-cluster -m delete -c \$DEMO"

alias c1upa="k3d-cluster -m create -c \$CLUSTER1 -r \$IP_RANGE_30 -e us-west-2 -i"
alias c1down="k3d-cluster delete \$CLUSTER1"
```

For the `demo` cluster, we create a cluster in the 192.168.96.100-109 range with 3 servers and no ambient (the region is arbitrary).

For the `cluster1` cluster, we create a cluster in the 192.168.96.30-39 range with 1 server and enable ambient.

For your purposes, you can change these values to what fit your needs, or add your own!

<!-- TOC --><a name="k3d-registry-dockerd"></a>
### k3d-registry-dockerd

In order to speed up deployments and to avoid the dreaded docker.io anonymous
pull limit inside a local k8s cluster, we implement
[k3d-registry-dockerd](https://github.com/ligfx/k3d-registry-dockerd). This
proxies the k3d registry through the Docker Desktop registry. If the images are
already present, pod instantiation is significantly faster. For example, on my
laptop, I can bring up a three-server ambient-enabled cluster in under 60
seconds. If to measure how long it takes to bring up cluster `cluster1`, here
is a convient snippet to measuring the start-up time:

```bash
time (c1up; sleep 1; while kubectl --context cluster1 -n istio-system get pods |grep -v NAME | grep -v Running; do sleep .5; done)
```

```text
0.91s user 0.51s system 4% cpu 34.475 total
```

The last number is the total time that passed in the universe, so 34 seconds.

<!-- TOC --><a name="pihole-dns"></a>
### Pi-hole

KCM also deploys [Pi-hole](https://github.com/pi-hole/docker-pi-hole/) on the
Docker network. If external-dns is deployed correctly on your clusters, you can
use programmable DNS outside your cluster to test URLs that would otherwise
require burdensome curl-hacking, like some SSL setups.

For example, I frequently use `helloworld.example.com` to test whether I've
configured my gateway correctly. Being able to test it from outside the
cluster, with a FQDN, in conjunction with MetalLB, makes my local mock-up feel
more like an actual cloud deploy.

The compansion projection,
[GSI](https://github.com/vincentjorgensen/gloo-solo-istio/), makes frequent use
of this.

<!-- TOC --><a name="technical-notes"></a>
## Technical Notes

It is important to start the docker network with the a subnet cidr that
includes the metallb subnets. I got bit by this. For example, the snippet
below (similar to what is used in [functions.sh](./functions.sh#L87) creates
docker network resource.

```bash
# Create a docker network on a defined subnet
docker network create --subnet 192.168.96.0/24 k3d-cluster-network
```

Then, the [k3d cluster
template](./templates/k3d-omni-cluster.template.yaml#L24), we specify this
network: `network: k3d-cluster-network`.

Finally, in the [metallb address
pool](./templates/metallb-native.address-pool.template.yaml#L9), we chose an ip
range in this cidr.

```yaml
spec:
  addresses:
  - ${MLB_ADDY_RANGE}
```

The ranges in the docker network can be found [here](./templates/k3d-omni-cluster.template.yaml#L30-L37)

For Docker Desktop greater than `v4.39.0` the network used to need an extra
option:

```bash
docker network create "$network"                                              \
      --subnet "$subnet"                                                      \
      --opt "com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected"
```

However, the issue has since been resolved.  [See
this](https://github.com/chipmk/docker-mac-net-connect/issues/48) for details.
I am leaving this here for historical purposes, and because it's like that
this--or something similar--will happen again.
