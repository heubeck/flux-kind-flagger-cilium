# Flux-Kind-Starter for Canary Deployment experiments using the Gateway API and Cilium

A local Kubernetes setup using [Kind](https://kind.sigs.k8s.io/) with [Podman](https://podman.io/) and [Cilium](https://cilium.io/), [Flagger](https://flagger.app/) and [Flux](https://fluxcd.io/) as template for your (and mine) canary deployment experiments.

## Usage

* [Create a new repository](https://github.com/heubeck/flux-kind-flagger-cilium/generate) from this template into your own profile.
* Clone it locally and step into its directory.
* Use [`make`](#make) for preparing your workstation and preparing the playground.

### `make`

Please have a look to the top section of the [`Makefile`](Makefile) to change its configuration for adopting it to your needs.

The included `Makefile` supports the following tasks:

* `make prepare`:
  Downloads the `kubectl`, `kind`, `flux` and `cilium` clis to `~/.fks` for later use. It's doesn't manipulate any of your regular local setup.

* `make pre-check`:
  Validates the required setup: podman, kubectl, kind and flux.

* `make new`:
  Creates a new k8s kind cluster with cilium instead of kube-proxy and points the local kube context to it.

* `make bootstrap`:
  Bootstraps flux to the local cluster, targeting the (_this_) GitHub repository you're using and _the current_ checked out branch.
  `GITHUB_TOKEN` env needs to be configured with a repo-scoped GitHub personal access token

* `make check`:
  Runs automatically before _bootstrap_, validating the kube context and printing the targeted GitHub repository.

* `make wait`:
  Blocks til reconciliation finished and the cluster is ready to use.

* `make reconcile`:
  Triggers the `flux reconcile` for the root kustomization `flux-system`.

* `make kube-ctx`:
  Configures local kubectl context (done by `make new`, just in case it changed)

* `make clean`:
  Removes the local kind cluster.

## What's in the box

* Kind [config](.kind/config.yaml) binding to host ports 8080, 8088 and 8443, so please free up those ports or change the config
* Basic GitOps setup with
* [kubernetes-dashboard](https://github.com/kubernetes/dashboard/tree/master/charts/helm-chart/kubernetes-dashboard) accessible via https:// from some IP allocated by the load balancer, check `kubectl get service` for the IP address.
* Prometheus and Grafana via `http://IP:8080/[prometheus|grafana]`  at another IP allocated by the load balancer.
* [Cilium UI](https://github.com/cilium/hubble-ui) accessible at `http://localhost:8088`.
* An [apps](apps) folder targeted by a respective [kustomization](local-cluster/apps.yaml), with an example application that gets deployed in a canary way.

## Local requirements

While `kubectl`, `kind`, `cilium` and `flux` are managed with this repository (for version compatibility of everything in here), your local setup has to fulfill the following:

* `podman` as container runtime
* `make` for orchestrating the setup
* `curl` for downloading the managed clis
* some common tools used by the Makefile:
  * `jq`
  * `cut`
  * `awk`
  * `sed`
  * `which`
  * `tar` (with `gzip` support)

For exposing loadbalancer services on virtual IPs, MetalLB is used. The `make new` command inspects the podman/kind network and configures the appropiate subnet in [its IPAddressPool](.kind/metallb/ip-address-pool.yaml).
On any issues, please check that the auto detected subnet matches your configuration and adjust it, if not.

## Walkthrough

Play with Flagger and watch it play.

### Setup

Bring it to life (after forking and cloning this repo) using:

```sh
make prepare
make new
make bootstrap
```

### Explore

* Get host mapped load balancer IPs: `kubectl get service` (EXTERNAL_IP, e.g. 10.89.0.240 for port 80; 10.89.0.241 for port 443)
* [Plain resources deployed Examiner](apps/plain): http://10.89.0.240/examine-plain
* [Helm deployed Examiner](apps/helm): http://10.89.0.240/examine-helm
* Cilium Hubble UI (exposed directly to host): http://localhost:8088
* Kubernetes Dashboard: https://10.89.0.241/ ("skip login")
* Prometheus: http://10.89.0.240/prometheus
* Grafana: http://10.89.0.240/grafana

### Experiment without Canary

* To switch between own HttpRoute config and Flagger managed routing, comment in/out route.yaml and canary.yaml
  [here](apps/plain/kustomization.yaml).
* produce some traffic:
  `hey -z 10m http://10.89.0.240/examine-plain`
* watch it in [Grafana](http://10.89.0.240/grafana/d/3g264CZVz/hubble-l7-http-metrics-by-workload?orgId=1&refresh=30s&from=now-5m&to=now&var-DS_PROMETHEUS=prometheus&var-cluster=&var-destination_namespace=plain&var-destination_workload=examiner&var-reporter=client&var-source_namespace=All&var-source_workload=All)
* and [Hubble UI](http://localhost:8088/?namespace=plain)
* Do some changes (increase error rate) by updating [its config](apps/plain/configmap.yaml), `make reconcile` to sync it and `kubectl rollout restart deployment -n plain examiner` to roll it out
* Watch it fail immediately

### Experiment with Canary

Ok, first let's repair it by reverting the [config change](apps/plain/configmap.yaml).

* Activate canary by [commenting routes.yaml out and canary.yaml in](apps/plain/kustomization.yaml)



## Contribution

Please don't hesitate to file any issues or propose enhancements to this repo.
