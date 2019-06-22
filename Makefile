TCPDUMP_VERSION=4.9.2
STATIC_TCPDUMP_NAME=static-tcpdump
NEW_PLUGIN_SYSTEM_MINIMUM_KUBECTL_VERSION=12
UNAME := $(shell uname)
KUBECTL_MINOR_VERSION=$(shell kubectl version --client=true --short=true -o json | jq .clientVersion.minor)
IS_NEW_PLUGIN_SUBSYSTEM := $(shell [ $(KUBECTL_MINOR_VERSION) -ge $(NEW_PLUGIN_SYSTEM_MINIMUM_KUBECTL_VERSION) ] && echo true)

ifeq ($(IS_NEW_PLUGIN_SUBSYSTEM),true)
PLUGIN_FOLDER=/usr/local/bin
else
PLUGIN_FOLDER=~/.kube/plugins/sniff
endif

ifeq ($(UNAME), Darwin)
PLUGIN_NAME=kubectl-sniff-darwin
endif

ifeq ($(UNAME), Linux)
PLUGIN_NAME=kubectl-sniff
endif

linux:
	GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o kubectl-sniff cmd/kubectl-sniff.go

windows:
	GO111MODULE=on GOOS=windows GOARCH=amd64 go build -o kubectl-sniff-windows cmd/kubectl-sniff.go

darwin:
	GO111MODULE=on GOOS=darwin GOARCH=amd64 go build -o kubectl-sniff-darwin cmd/kubectl-sniff.go

all: linux windows darwin

test:
	GO111MODULE=on go test ./...

vet:
	GO111MODULE=on go vet ./...

static-tcpdump:
	wget http://www.tcpdump.org/release/tcpdump-${TCPDUMP_VERSION}.tar.gz
	tar -xvf tcpdump-${TCPDUMP_VERSION}.tar.gz
	cd tcpdump-${TCPDUMP_VERSION} && CFLAGS=-static ./configure --without-crypto && make
	mv tcpdump-${TCPDUMP_VERSION}/tcpdump ./${STATIC_TCPDUMP_NAME}
	rm -rf tcpdump-${TCPDUMP_VERSION} tcpdump-${TCPDUMP_VERSION}.tar.gz

package:
	zip ksniff.zip kubectl-sniff kubectl-sniff-windows kubectl-sniff-darwin static-tcpdump Makefile plugin.yaml

install:
	mkdir -p ${PLUGIN_FOLDER}
	cp ${PLUGIN_NAME} ${PLUGIN_FOLDER}/kubectl-sniff
	cp plugin.yaml ${PLUGIN_FOLDER}
	cp ${STATIC_TCPDUMP_NAME} ${PLUGIN_FOLDER}

uninstall:
	rm -f ${PLUGIN_FOLDER}/kubectl-sniff
	rm -f ${PLUGIN_FOLDER}/plugin.yaml
	rm -f ${PLUGIN_FOLDER}/${STATIC_TCPDUMP_NAME}

install-kubectl:
	curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl

e2e-tests-environment:
	sudo snap install microk8s --classic --channel=1.13/stable
	microk8s.status --wait-ready
	microk8s.kubectl get nodes
	microk8s.kubectl config view --raw > ${HOME}/.kube/config
	sudo echo -e "\n--allow-privileged" >> /var/snap/microk8s/current/args/kube-apiserver
	cat /var/snap/microk8s/current/args/kube-apiserver

clean:
	rm -f kubectl-sniff
	rm -f kubectl-sniff-windows
	rm -f kubectl-sniff-darwin
	rm -f static-tcpdump
	rm -f ksniff.zip

