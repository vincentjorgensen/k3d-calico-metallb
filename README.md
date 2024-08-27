# k3d-calico-metallb

## MacOS

Make sure Docker Desktop is running (I also tested it successfully on Rancher Desktop).

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
source functions.sh
```

Bring up a three-cluster setup with:
```sh
k3d-up
```

Destroy the clusters with: 
```sh
k3d-down
```

## Simple Test

Bring up a single cluster
```sh
k3d-solo-up
```

Create a simple httpbin service of type LoadBalancer
```sh
kubectl --context solo-cluster apply -f service_mockup.yaml
```

When it's up, this curl command should return 200, proving that it hit the  
httpbin service
```sh
curl -I $(kubectl get svc/httpbin               \
          --context solo-cluster                \
          --namespace httpbin                   \
          -o=jsonpath='{.status.loadBalancer.ingress[0].ip}{":"}{.spec.ports[0].port}')
```

Destroy the single cluster when you're finished
```sh
k3d-solo-down
```
