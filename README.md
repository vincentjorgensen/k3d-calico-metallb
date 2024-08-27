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
