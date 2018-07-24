.DEFAULT_GOAL := help
.PHONY: help build push start stop show destroy logs logs-master logs-slicer logs-worker k8s-master setup 
SHELL := bash

# defaults to my minikube teraslice master, override by setting the
TERASLICE_MASTER_URL ?= 192.168.99.100:30678
TERASLICE_K8S_IMAGE ?= peterdemartini/teraslice:k8sdev
TERASLICE_WORKER_K8S_IMAGE ?= peterdemartini/teraslice-worker:k8sdev
LOG_LENGTH ?= 10

help: ## show target summary
	@grep -E '^\S+:.* ## .+$$' $(MAKEFILE_LIST) | sed 's/##/#/' | while IFS='#' read spec help; do \
	  tgt=$${spec%%:*}; \
	  printf "\n%s: %s\n" "$$tgt" "$$help"; \
	  awk -F ': ' -v TGT="$$tgt" '$$1 == TGT && $$2 ~ "=" { print $$2 }' $(MAKEFILE_LIST) | \
	  while IFS='#' read var help; do \
	    printf "  %s  :%s\n" "$$var" "$$help"; \
	  done \
	done

install:
	yarn global add teraslice-job-manager
	
show: ## show k8s deployments and services
	kubectl get deployments,svc,po -o wide

destroy: ## delete k8s deployments and services
	kubectl delete deployments,services,pods -l app=teraslice
	kubectl delete configmap teraslice-master || echo "* it is okay..."
	kubectl delete configmap teraslice-worker || echo "* it is okay..."

logs: ## show logs for k8s deployments and services
	kubectl logs -l app=teraslice --tail=$(LOG_LENGTH) | bunyan

logs-master: ## show logs for k8s teraslice master
	kubectl logs -l app=teraslice,nodeType=master --tail=$(LOG_LENGTH) | bunyan

logs-slicer: ## show logs for k8s teraslice slicers
	kubectl logs -l app=teraslice,nodeType=execution_controller --tail=$(LOG_LENGTH) | bunyan

logs-worker: ## show logs for k8s teraslice workers
	kubectl logs -l app=teraslice,nodeType=worker --tail=$(LOG_LENGTH) | bunyan

k8s-master: ## start teraslice master in k8s
	kubectl create -f ./masterDeployment.yaml

configs: ## create the configmaps
	kubectl create configmap teraslice-master --from-file=teraslice-master.yaml
	kubectl create configmap teraslice-worker --from-file=teraslice-worker.yaml

build: ## build the teraslice:k8sdev container, override container name by setting TERASLICE_K8S_IMAGE
	docker build -t $(TERASLICE_K8S_IMAGE) ../teraslice
	docker build -t $(TERASLICE_WORKER_K8S_IMAGE) ../teraslice-worker

push: ## build the teraslice:k8sdev container, override container name by setting TERASLICE_K8S_IMAGE
	docker push $(TERASLICE_K8S_IMAGE)
	docker push $(TERASLICE_WORKER_K8S_IMAGE)

setup: configs k8s-master ## setup teraslice

rebuild: tjm stop ./example-job.json
rebuild: destroy setup ## rebuild teraslice

register:
	tjm asset deploy -c $(TERASLICE_MASTER_URL) || echo '* it is okay'
	tjm register -c $(TERASLICE_MASTER_URL) ./example-job.json

example: 
	yes | tjm asset replace -c $(TERASLICE_MASTER_URL) || echo '* it is okay'
	tjm start ./example-job.json
