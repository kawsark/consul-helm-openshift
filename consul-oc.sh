#!/bin/bash

# setup environment
#Adjust this to where YAML templates are
manifests_dir=$(pwd)/consul-helm/manifests/consul/templates 
#manifests_dir=$(pwd)/manifests/consul/templates

if [ ! -d $manifests_dir ]; then
  echo "Manifests directory does not exist: $manifests_dir"
  echo "Please adjust manifests_dir directory variable"
  exit
fi

cli=oc #Set this to oc or kubectl
license_file=license.hclic #Set path to license file if using consul-enterprise image

# Organize templates
echo "Organizing templates"
pushd ${manifests_dir}
mkdir -p server && mv server-* server
mkdir -p client && mv client-* client
mkdir -p mesh-gateway && mv mesh-gateway-* mesh-gateway
mkdir -p connect-inject && mv connect-inject-* connect-inject
mkdir -p sync-catalog && mv sync-catalog-* sync-catalog
popd

# Server
echo "Creating server objects"
cp security-contexts/consul-server-scc.yaml $manifests_dir
pushd $manifests_dir
$cli apply -f server/server-serviceaccount.yaml
$cli apply -f consul-server-scc.yaml
$cli get scc consul-server
$cli adm policy add-scc-to-user consul-server -z consul-oc-consul-server
$cli apply -f server/
popd

# Client
echo "Creating client objects"
cp security-contexts/consul-client-scc.yaml $manifests_dir
pushd $manifests_dir
$cli apply -f client/client-serviceaccount.yaml
$cli apply -f consul-client-scc.yaml
$cli get scc consul-client
$cli adm policy add-scc-to-user consul-client -z consul-oc-consul-client
$cli apply -f client/
popd

### Connect inject, sync catalog, UI and DNS service
pushd $manifests_dir
$cli apply -f sync-catalog/
$cli apply -f connect-inject/
$cli apply -f dns-service.yaml
$cli apply -f ui-service.yaml
popd

### Check deployment and apply license
$cli exec -it consul-oc-consul-server-0 -- consul members

echo "Waiting 90 seconds before applying license"
sleep 90

# Apply license (if you used an enterprise image)
$cli exec -it consul-oc-consul-server-0 -- consul license put $(cat license_file)


