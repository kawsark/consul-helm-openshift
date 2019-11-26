#!/bin/bash

# setup environment
manifests_dir=$(pwd)/consul-helm/manifests/consul/templates #Adjust this to where YAML templates are
cli=oc #Set this to oc or kubectl

echo "Deleting objects"
pushd ${manifests_dir}
$cli delete -f server
$cli delete -f consul-server-scc.yaml
$cli delete -f client
$cli delete -f consul-client-scc.yaml
$cli delete -f sync-catalog/
$cli delete -f connect-inject/
$cli delete -f dns-service.yaml
$cli delete -f ui-service.yaml
$cli delete pvc/data-default-consul-oc-consul-server-0
$cli delete pvc/data-default-consul-oc-consul-server-1
$cli delete pvc/data-default-consul-oc-consul-server-2
popd

echo "Deleting example application"
$cli delete -f services/

echo "Done, running $cli get pods, please verify there are no consul or application pods"
$cli get pods