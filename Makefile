CHART_REPO_URL ?= http://example.com
HELM_REPO_DEST ?= /tmp/gh-pages
OPERATOR_NAME ?=$(shell basename -z `pwd`)

# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.2)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.2)
VERSION ?= 0.0.1

# CHANNELS define the bundle channels used in the bundle.
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "candidate,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=candidate,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="candidate,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle.
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

# IMAGE_TAG_BASE defines the docker.io namespace and part of the image name for remote images.
# This variable is used to construct full image tags for bundle and catalog images.
#
# For example, running 'make bundle-build bundle-push catalog-build catalog-push' will build and push both
# redhat.io/vault-config-operator-bundle:$VERSION and redhat.io/vault-config-operator-catalog:$VERSION.
IMAGE_TAG_BASE ?= redhat.io/vault-config-operator

# BUNDLE_IMG defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= $(IMAGE_TAG_BASE)-bundle:v$(VERSION)

# Image URL to use all building/pushing image targets
IMG ?= controller:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"
# ENVTEST_K8S_VERSION refers to the version of kubebuilder assets to be downloaded by envtest binary.
ENVTEST_K8S_VERSION = 1.21

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

manifests: controller-gen ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

generate: controller-gen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

test: manifests generate fmt vet envtest ## Run tests.
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) -p path)" go test ./... -coverprofile cover.out

##@ Build

build: generate fmt vet ## Build manager binary.
	go build -o bin/manager main.go

run: manifests generate fmt vet ## Run a controller from your host.
	go run ./main.go

docker-build: test ## Build docker image with the manager.
	docker build -t ${IMG} .

docker-push: ## Push docker image with the manager.
	docker push ${IMG}

##@ Deployment

install: manifests kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

uninstall: manifests kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

deploy: manifests kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/default | kubectl delete -f -


CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.6.1)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

ENVTEST = $(shell pwd)/bin/setup-envtest
envtest: ## Download envtest-setup locally if necessary.
	$(call go-get-tool,$(ENVTEST),sigs.k8s.io/controller-runtime/tools/setup-envtest@latest)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

.PHONY: bundle
bundle: manifests kustomize ## Generate bundle manifests and metadata, then validate generated files.
	operator-sdk generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(IMG)
	$(KUSTOMIZE) build config/manifests | operator-sdk generate bundle -q --overwrite --version $(VERSION) $(BUNDLE_METADATA_OPTS)
	operator-sdk bundle validate ./bundle

.PHONY: bundle-build
bundle-build: ## Build the bundle image.
	docker build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Push the bundle image.
	$(MAKE) docker-push IMG=$(BUNDLE_IMG)

.PHONY: opm
OPM = ./bin/opm
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.15.1/$${OS}-$${ARCH}-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif

# A comma-separated list of bundle images (e.g. make catalog-build BUNDLE_IMGS=example.com/operator-bundle:v0.1.0,example.com/operator-bundle:v0.2.0).
# These images MUST exist in a registry and be pull-able.
BUNDLE_IMGS ?= $(BUNDLE_IMG)

# The image tag given to the resulting catalog image (e.g. make catalog-build CATALOG_IMG=example.com/operator-catalog:v0.2.0).
CATALOG_IMG ?= $(IMAGE_TAG_BASE)-catalog:v$(VERSION)

# Set CATALOG_BASE_IMG to an existing catalog image tag to add $BUNDLE_IMGS to that image.
ifneq ($(origin CATALOG_BASE_IMG), undefined)
FROM_INDEX_OPT := --from-index $(CATALOG_BASE_IMG)
endif

# Build a catalog image by adding bundle images to an empty catalog using the operator package manager tool, 'opm'.
# This recipe invokes 'opm' in 'semver' bundle add mode. For more information on add modes, see:
# https://github.com/operator-framework/community-operators/blob/7f1438c/docs/packaging-operator.md#updating-your-existing-operator
.PHONY: catalog-build
catalog-build: opm ## Build a catalog image.
	$(OPM) index add --container-tool docker --mode semver --tag $(CATALOG_IMG) --bundles $(BUNDLE_IMGS) $(FROM_INDEX_OPT)

# Push the catalog image.
.PHONY: catalog-push
catalog-push: ## Push a catalog image.
	$(MAKE) docker-push IMG=$(CATALOG_IMG)

# Generate helm chart
helmchart: kustomize helm
	mkdir -p ./charts/${OPERATOR_NAME}/templates
	mkdir -p ./charts/${OPERATOR_NAME}/crds
	repo=${OPERATOR_NAME} envsubst < ./config/local-development/tilt/env-replace-image.yaml > ./config/local-development/tilt/replace-image.yaml
	$(KUSTOMIZE) build ./config/helmchart -o ./charts/${OPERATOR_NAME}/templates
	sed -i 's/release-namespace/{{.Release.Namespace}}/' ./charts/${OPERATOR_NAME}/templates/*.yaml
	rm ./charts/${OPERATOR_NAME}/templates/v1_namespace_release-namespace.yaml ./charts/${OPERATOR_NAME}/templates/apps_v1_deployment_vault-config-operator-controller-manager.yaml
	mv ./charts/${OPERATOR_NAME}/templates/apiextensions.k8s.io_v1_customresourcedefinition* ./charts/${OPERATOR_NAME}/crds
	cp ./config/helmchart/templates/* ./charts/${OPERATOR_NAME}/templates
	version=${VERSION} envsubst < ./config/helmchart/Chart.yaml.tpl  > ./charts/${OPERATOR_NAME}/Chart.yaml
	version=${VERSION} image_repo=$${IMG%:*} envsubst < ./config/helmchart/values.yaml.tpl  > ./charts/${OPERATOR_NAME}/values.yaml
	sed -i '1s/^/{{ if .Values.enableMonitoring }}/' ./charts/${OPERATOR_NAME}/templates/monitoring.coreos.com_v1_servicemonitor_vault-config-operator-controller-manager-metrics-monitor.yaml
	echo {{ end }} >> ./charts/${OPERATOR_NAME}/templates/monitoring.coreos.com_v1_servicemonitor_vault-config-operator-controller-manager-metrics-monitor.yaml
	$(HELM) lint ./charts/${OPERATOR_NAME}	

helmchart-repo: helmchart
	mkdir -p ${HELM_REPO_DEST}/${OPERATOR_NAME}
	$(HELM) package -d ${HELM_REPO_DEST}/${OPERATOR_NAME} ./charts/${OPERATOR_NAME}
	$(HELM) repo index --url ${CHART_REPO_URL} ${HELM_REPO_DEST}

helmchart-repo-push: helmchart-repo	
	git -C ${HELM_REPO_DEST} add .
	git -C ${HELM_REPO_DEST} status
	git -C ${HELM_REPO_DEST} commit -m "Release ${VERSION}"
	git -C ${HELM_REPO_DEST} push origin "gh-pages"	

.PHONY: kind
KIND = ./bin/kind
kind: ## Download kind locally if necessary.
ifeq (,$(wildcard $(KIND)))
ifeq (,$(shell which kind 2>/dev/null))
	$(call go-get-tool,$(KIND),sigs.k8s.io/kind@v0.11.1)
else
KIND = $(shell which kind)
endif
endif

.PHONY: kubectl
KUBECTL = ./bin/kubectl
kubectl: ## Download kubectl locally if necessary.
ifeq (,$(wildcard $(KUBECTL)))
ifeq (,$(shell which kubectl 2>/dev/null))
	echo "Downloading ${KUBECTL} for managing k8s resources."
	OS=$(shell go env GOOS) ;\
	ARCH=$(shell go env GOARCH) ;\
	curl --create-dirs -sSLo ${KUBECTL} https://dl.k8s.io/release/v1.21.1/bin/$${OS}/$${ARCH}/kubectl ;\
	chmod +x ${KUBECTL}
else
KUBECTL = $(shell which kubectl)
endif
endif

.PHONY: vault
VAULT = ./bin/vault
vault: ## Download vault cli locally if necessary.
ifeq (,$(wildcard $(VAULT)))
ifeq (,$(shell which vault 2>/dev/null))
	echo "Downloading ${VAULT} cli."
	OS=$(shell go env GOOS) ;\
	ARCH=$(shell go env GOARCH) ;\
	curl --create-dirs -sSLo ${VAULT}.zip https://releases.hashicorp.com/vault/1.9.3/vault_1.9.3_linux_amd64.zip ;\
	unzip ${VAULT}.zip -d ./bin/ ;\
	chmod +x ${VAULT}
else
VAULT = $(shell which vault)
endif
endif

.PHONY: helm
HELM = ./bin/helm
helm: ## Download helm locally if necessary.
ifeq (,$(wildcard $(HELM)))
ifeq (,$(shell which helm 2>/dev/null))
	echo "Downloading ${HELM}."
	OS=$(shell go env GOOS) ;\
	ARCH=$(shell go env GOARCH) ;\
	curl --create-dirs -sSLo ${HELM}.tar.gz https://get.helm.sh/helm-v3.8.0-$${OS}-$${ARCH}.tar.gz ;\
	tar -xf ${HELM}.tar.gz -C ./bin/ ;\
	mv ./bin/$${OS}-$${ARCH}/helm ${HELM}
else
HELM = $(shell which helm)
endif
endif

VAULT_ADDR := "http://localhost"

.PHONY: integration
integration: kind-setup manifests generate fmt vet envtest ## Run tests.
	export VAULT_TOKEN=$$($(KUBECTL) get secret vault-init -n vault -o jsonpath='{.data.root_token}' | base64 -d) ;\
	export VAULT_ADDR=${VAULT_ADDR} ;\
	export ACCESSOR=$$($(VAULT) read -tls-skip-verify -format json sys/auth | jq -r '.data["kubernetes/"].accessor') ;\
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) -p path)" go test ./... -coverprofile cover.out --tags=integration

.PHONY: kind-setup
kind-setup: kind kubectl vault helm
	$(KIND) delete cluster
	$(KIND) create cluster --config=./integration/cluster-kind.yaml
	$(KUBECTL) create namespace vault
	$(KUBECTL) apply -f ./integration/rolebinding-admin.yaml -n vault
	$(HELM) repo add hashicorp https://helm.releases.hashicorp.com
	$(HELM) upgrade vault hashicorp/vault -i --create-namespace -n vault --atomic -f ./integration/vault-values.yaml
	$(KUBECTL) wait --for=condition=ready pod/vault-0 -n vault --timeout=5m	
	$(HELM) upgrade ingress-nginx ./integration/helm/ingress-nginx -i --create-namespace -n ingress-nginx --atomic
	$(KUBECTL) wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
	export VAULT_TOKEN=$$($(KUBECTL) get secret vault-init -n vault -o jsonpath='{.data.root_token}' | base64 -d) ;\
	export VAULT_ADDR=${VAULT_ADDR} ;\
	$(VAULT) policy write -tls-skip-verify vault-admin ./config/local-development/vault-admin-policy.hcl ;\
	$(VAULT) auth enable -tls-skip-verify kubernetes ;\
	export SA_SECRET=$$($(KUBECTL) get sa default -n vault -o jsonpath='{.secrets[*].name}' | grep -o '\b\w*\-token-\w*\b') ;\
	$(KUBECTL) get secret ${SA_SECRET} -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/ca.crt ;\
	$(VAULT) write -tls-skip-verify auth/kubernetes/config token_reviewer_jwt="$$($(KUBECTL) get $$($(KUBECTL) get secret -n vault -o name | grep vault-token) -n vault -o jsonpath={.data.token} | base64 -d)" kubernetes_host=https://kubernetes.default.svc:443 kubernetes_ca_cert=@/tmp/ca.crt ;\
	$(VAULT) write -tls-skip-verify auth/kubernetes/role/policy-admin bound_service_account_names=default bound_service_account_namespaces=vault-admin policies=vault-admin ttl=1h
