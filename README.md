# k3d-calico-metallb

K3d cluster with local load-balancing and pre-installed with Istio Ambient.

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

The three clusters' contexts are `mgmt`, `cluster1`, and `cluster2`.

Destroy the clusters with: 
```sh
m0down
c1down
c2down
```

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

## Technical Notes

It is important to start the docker network with the a subnet cidr that
includes the metalllb subnets. I got bit by this. For example, the snippet
below (similar to what is used in [functions.sh](./functions.sh#L84) creates
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
