SHELL := /bin/bash

### the location where the necessary cli binaries are stored
binary_location = ${HOME}/.fks

### gitops repository and branch to play with
gitops_repo = $(shell git config --get remote.origin.url)
gitops_branch = $(shell git branch --show-current)
### used as folder within the repo to contain the root kustomization "flux-system" as well as the kind cluster name
cluster_name = local-cluster

### operating system, options are (darwin|linux)
os = $(shell uname -s | awk '{print tolower($$0)}')

### operating system, options are (amd64|arm64)
arch = $(shell [[ "$$(uname -m)" = x86_64 ]] && echo "amd64" || echo "$$(uname -m)")

### versions

# https://kubernetes.io/releases/
kubectl_version = v1.29.1
# https://github.com/kubernetes-sigs/kind/releases
kind_version = v0.21.0
# https://github.com/fluxcd/flux2/releases
flux_version = v2.2.2
# https://hub.docker.com/r/kindest/node/tags
kindest_node_version = v1.29.1

# https://github.com/cilium/cilium-cli/releases
cilium_cli_version = v0.15.22
# https://github.com/cilium/cilium/releases
cilium_version = v1.15.0

# https://github.com/kubernetes-sigs/gateway-api/releases needs to be compatible with Cilium, see: https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
gatway_api_version = v1.0.0

###

kubectl_arch = $(os)/$(arch)
kubectl_location = $(binary_location)/kubectl

kind_arch = $(os)-$(arch)
kind_location = $(binary_location)/kind

flux_arch = $(os)_$(arch)
flux_location = $(binary_location)/flux

cilium_cli_arch = $(os)-$(arch)
cilium_cli_location = $(binary_location)/cilium

kindest_node_image = kindest/node:$(kindest_node_version)

### leave empty for enforcing docker even if podman was available, or set env NO_PODMAN=1
kind_podman =
# kind_podman = $(shell [[ "$$NO_PODMAN" -ne 1 ]] && which podman > /dev/null && echo "KIND_EXPERIMENTAL_PROVIDER=podman" || echo "")

kind_cmd = $(kind_podman) $(kind_location)

wait_timeout= "120s"

gitops_repo_owner = $(shell [[ "$(gitops_repo)" = http* ]] && echo $(gitops_repo) | cut -d/ -f4 || echo $(gitops_repo) | cut -d: -f2 | cut -d/ -f1)
gitops_repo_name = $(shell [[ "$(gitops_repo)" = http* ]] && echo $(gitops_repo) | cut -d/ -f5 | cut -d. -f1 || echo $(gitops_repo) | cut -d/ -f2 | cut -d. -f1)

kind_version_number = $(shell echo $(kind_version) | cut -c 2-)
flux_version_number = $(shell echo $(flux_version) | cut -c 2-)
kubectl_version_number = $(shell echo $(kubectl_version) | cut -c 2-)
cilium_version_number = $(shell $(cilium_cli_location) version --client | grep "$(cilium_version)" | awk '{print $$4}' | cut -c 2-)

.PHONY: pre-check
pre-check: # validate required tools
	### Checking installed tooling
	# Podman or Docker
	@if [ -z "$(kind_podman)" ]; then \
		docker version -f 'docker client version {{.Client.Version}}, server version {{.Server.Version}}'; \
	else \
		podman -v; \
	fi
	#
	# Kubectl ($(kubectl_location))
	@$(kubectl_location) version --client=true --output=json | jq -r '"kubectl version "+ .clientVersion.gitVersion'
	#
	# Kind ($(kind_location))
	@$(kind_location) --version
	#
	# Flux ($(flux_location))
	@$(flux_location) --version
	#
	# Cilium ($(cilium_cli_location))
	@$(cilium_cli_location) version --client
	#

.PHONY: check
check: pre-check # validate prerequisites
	### Checking prerequisites
	# Kube Context
	@$(kubectl_location) cluster-info --context kind-$(cluster_name) | grep 127.0.0.1
	@test -n "$(cilium_version_number)"
	# Cilium version set ✓
	#
	# GitOps-Repository-Url: $(gitops_repo)
	# Repo-Owner: $(gitops_repo_owner)
	# Repo-Name: $(gitops_repo_name)
	# GitOps-Branch: $(gitops_branch)
	# Cilium Version to be installed: $(cilium_version_number)
	# Everything is fine, lets get bootstrapped
	#

.PHONY: prepare
prepare: # install prerequisites
	# Creating $(binary_location)
	@mkdir -p $(binary_location)

	# Install or update kind $(kind_version_number) for $(kind_arch) into $(kind_location)
	@curl -sSLfo $(kind_location) "https://github.com/kubernetes-sigs/kind/releases/download/v$(kind_version_number)/kind-$(kind_arch)"
	@chmod a+x $(kind_location)

	# Install or update flux $(flux_version_number) for $(flux_arch) into $(flux_location)
	@curl -sSLfo $(flux_location).tgz https://github.com/fluxcd/flux2/releases/download/v$(flux_version_number)/flux_$(flux_version_number)_$(flux_arch).tar.gz
	@tar xf $(flux_location).tgz -C $(binary_location) && rm -f $(flux_location).tgz
	@chmod a+x $(flux_location)

	# Install or update kubectl $(kubectl_version_number) for $(kubectl_arch) into $(kubectl_location)
	@curl -sSLfo $(kubectl_location) https://dl.k8s.io/release/$(kubectl_version)/bin/$(kubectl_arch)/kubectl
	@chmod a+x $(kubectl_location)

	# Install or update cilium $(cilium_cli_version) for $(cilium_cli_arch) into $(cilium_cli_location)
	@curl -sSLfo $(cilium_cli_location).tgz https://github.com/cilium/cilium-cli/releases/download/$(cilium_cli_version)/cilium-$(cilium_cli_arch).tar.gz
	@tar xf $(cilium_cli_location).tgz -C $(binary_location) && rm -f $(cilium_cli_location).tgz
	@chmod a+x $(cilium_cli_location)

.PHONY: new
new: # create fresh kind cluster
	# Creating kind cluster named '$(cluster_name)'
	@$(kind_cmd) create cluster -n $(cluster_name) --config .kind/config.yaml --image $(kindest_node_image)
	@$(kind_cmd) export kubeconfig -n $(cluster_name) --kubeconfig ${HOME}/.kube/config

	# Install Gateway API CRD
	@$(kubectl_location) apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(gatway_api_version)/experimental-install.yaml

	# Install Cilium
	@$(cilium_cli_location) install --version $(cilium_version_number) --values .kind/cilium.yaml

	# Wait for Cilium to become ready
	@$(kubectl_location) rollout status --timeout=$(wait_timeout) daemonset -n kube-system cilium
	@$(cilium_cli_location) status --wait --wait-duration $(wait_timeout)

	# Install MetalLB
	@$(kubectl_location) apply -k .kind/metallb

	# Wait for MetalLB to become ready
	@$(kubectl_location) rollout status --timeout=$(wait_timeout) deployment -n metallb-system controller
	@$(kubectl_location) rollout status --timeout=$(wait_timeout) daemonset -n metallb-system speaker

	$(eval lb_ip_range := $(shell docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}' | sed 's#0.0/16#250.0/24#'))
	# Setting MetalLB address-pool range to $(lb_ip_range)
	@sed -i "s#addresses:.*#addresses: [\"$(lb_ip_range)\"]#" .kind/metallb/ip-address-pool.yaml
	@$(kubectl_location) apply -f .kind/metallb/ip-address-pool.yaml

.PHONY: kube-ctx
kube-ctx: # create fresh kind cluster
	@$(kind_cmd) export kubeconfig -n $(cluster_name) --kubeconfig ${HOME}/.kube/config

.PHONY: clean
clean: # remove kind cluster
	# Removing kind cluster named '$(cluster_name)'
	@$(kind_cmd) delete cluster -n $(cluster_name)

.PHONY: bootstrap
bootstrap: check kube-ctx # install and configure flux
ifndef GITHUB_TOKEN
	@echo "!!! please set GITHUB_TOKEN env to bootstrap flux"
	exit 1
endif
	### Bootstrapping flux from GitHub repo $(gitops_repo_owner)/$(gitops_repo_name) branch $(gitops_branch)
	$(flux_location) bootstrap github \
		--components-extra=image-reflector-controller,image-automation-controller \
		--read-write-key=true \
		--owner=$(gitops_repo_owner) \
		--repository=$(gitops_repo_name) \
		--branch=$(gitops_branch) \
		--path=$(cluster_name)
	#
	# Configuring GitHub commit status notification
	@$(kubectl_location) create secret generic -n flux-system github --from-literal token=${GITHUB_TOKEN} --save-config --dry-run=client -o yaml | $(kubectl_location) apply -f -
	@$(flux_location) create alert-provider github -n flux-system --type github --address "https://github.com/$(gitops_repo_owner)/$(gitops_repo_name)" --secret-ref github
	@$(flux_location) create alert -n flux-system --provider-ref github --event-source "Kustomization/*" flux-system
	@$(kubectl_location) get kustomization -n flux-system
	#

.PHONY: reconcile
reconcile: # reconsule flux-system kustomization
	@$(flux_location) reconcile kustomization flux-system --with-source
	@$(kubectl_location) get kustomization -n flux-system

.PHONY: wait
wait: # wait for reconciliation complete
	@$(kubectl_location) wait --for=condition=ready --timeout=$(wait_timeout) kustomization -n flux-system flux-system
	@$(kubectl_location) wait --for=condition=ready --timeout=$(wait_timeout) kustomization -n flux-system infrastructure
	@$(kubectl_location) wait --for=condition=ready --timeout=$(wait_timeout) kustomization -n flux-system apps
