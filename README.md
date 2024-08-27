# k3d-calico-metallb

## MacOS

Install [Docker Mac Net Connect](https://github.com/chipmk/docker-mac-net-connect)

Make sure Docker Desktop is running (I also tested it successfully on Rancher Desktop).

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

