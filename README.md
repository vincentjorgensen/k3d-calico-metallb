# k3d-calico-metallb

K3d cluster with local load-balancing and pre-installed with Istio Ambient.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [MacOS](#macos)
- [Simple Test](#simple-test)
- [Usage notes](#usage-notes)
   * [k3d-registry-dockerd](#k3d-registry-dockerd)
- [Technical Notes](#technical-notes)

<!-- TOC end -->

<!-- TOC --><a name="macos"></a>
## MacOS

Make sure Docker Desktop is running (TBD test ambient on Rancher Desktop.
Non-istio has already been proven to work.)

Install or update k3d:
```sh
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Install [Docker Mac Net Connect](https://github.com/chipmk/docker-mac-net-connect)
```sh
brew install chipmk/tap/docker-mac-net-connect
sudo brew services start chipmk/tap/docker-mac-net-connect
```

Source `functions.sh`
```sh
source ./functions.sh
```

Bring up a three-cluster setup with:
```sh
m0up
c1up
c2up
```

The three clusters' contexts are `mgmt`, `cluster1`, and `cluster2`. Clusters 1
and 2 are istio enabled. The management cluster is not. 

Destroy the clusters with: 
```sh
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
alias d0up="k3d-cluster create \$DEMO \$IP_RANGE_100 us-west-1 us-west-1a 3 false"
alias d0down="k3d-cluster delete \$DEMO"

alias c1up="k3d-cluster create \$CLUSTER1 \$IP_RANGE_30 us-west-2 us-west-2a 2 true"
alias c1down="k3d-cluster delete \$CLUSTER1"
```

For the `demo` cluster, we create a cluster in the 192.168.96.100-109 range with 3 servers and no ambient (the regions and zones are arbitrary).

For the `cluster1` cluster, we create a cluster in the 192.168.96.30-39 range with 2 servers and enable ambient.

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

<!-- TOC --><a name="technical-notes"></a>
## Technical Notes

It is important to start the docker network with the a subnet cidr that
includes the metalllb subnets. I got bit by this. For example, the snippet
below (similar to what is used in [functions.sh](./functions.sh#L87) creates
docker network resource.

```bash
# Create a docker network on a defined subnet
docker network create --subnet 192.168.96.0/24 k3d-cluster-network
```

Then, the [k3d cluster
template](./templates/k3d-omni-cluster.template.yaml#L7), we specify this
network: `network: k3d-cluster-network`.

Finally, in the [metallb address
pool](./templates/metallb-native.address-pool.template.yaml#L9), we chose an ip
range in this cidr.

```yaml
spec:
  addresses:
  - 192.168.96.20-192.168.96.29
```

