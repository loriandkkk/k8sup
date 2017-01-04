#!/bin/bash

KUBECTL=${KUBECTL_BIN:-/hyperkube kubectl}
KUBECTL_OPTS=${KUBECTL_OPTS:-}

function dns_route_maintainer(){
  set -x
  while true; do
    if [[ -n "$(ip route | grep -w 'cni0')" ]]; then
      if [[ -n "$(ip route | grep -w 'flannel.1' | grep -w '10.0.0.10')" ]]; then
        ip route del 10.0.0.10/32 dev flannel.1
      fi
      if [[ -z "$(ip route | grep -w 'cni0' | grep -w '10.0.0.10')" ]]; then
        ip route add 10.0.0.10/32 dev cni0
      fi
    else
      if [[ -z "$(ip route | grep -w 'flannel.1' | grep -w '10.0.0.10')" ]]; then
        ip route add 10.0.0.10/32 dev flannel.1
      fi
    fi
    sleep 2;
  done
}

function main(){

  sed -i "s|^  labels:|  labels:\n    kubernetes.io/cluster-service: 'true'|g" /etc/kubernetes/addons/multinode/heapster/*-controller.yaml

  /copy-addons.sh "$@" &

  token_found=""
  while [ -z "${token_found}" ]; do
    sleep .5
    token_found=$(${KUBECTL} ${KUBECTL_OPTS} get --namespace="kube-system" serviceaccount default -o go-template="{{with index .secrets 0}}{{.name}}{{end}}" || true)
  done

  echo "== default service account in the kube-system namespace has token ${token_found} =="

  dns_route_maintainer &

  while true; do
	  sleep 3600;
  done
}

main "$@"
