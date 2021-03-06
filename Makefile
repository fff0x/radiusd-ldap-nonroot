# Makefile ------+
# Version: 0.0.1 |
# ---------------+
# vim: noai:ts=2

### VARIABLES
# -----------
override REGISTRY = docker.io/ff0x

### INCLUDES
# ----------
include ../@include/default.mk

### CONTAINER
# -----------
run: clean-k8s deploy-k8s logs-k8s

deploy-k8s:
	cd $(shell pwd)/manifests && kubectl apply -f .

restart-k8s:
	kubectl scale deploy "freeradius" -n "radius" --replicas=0
	@sleep 5
	kubectl scale deploy "freeradius" -n "radius" --replicas=1
	@sleep 5

logs-k8s:
	kubectl logs -n "radius" $(shell kubectl get pod -n "radius" -lapp="freeradius" -o name) -f

shell-k8s:
	kubectl exec -n "radius" -ti $(shell kubectl get pod -n "radius" -lapp="freeradius" -o name) -- /bin/sh

clean-k8s:
	cd $(shell pwd)/manifests && kubectl delete -f .

debug: clean
	docker run -ti --entrypoint /bin/sh --platform linux/${DEF_ARCH} --name ${LABEL} --hostname ${LABEL}.${DOMAIN} -d ${NAME}
	@sleep 2
	docker exec -ti ${LABEL} /bin/sh
