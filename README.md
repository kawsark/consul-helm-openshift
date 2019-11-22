# consul-helm-openshift-experimental
An experimental repo with steps to deploy consul-helm on OpenShift

All the files and steps in this repo are example only

## Generate consul-helm templates (Optional)
This repo already includes consul-helm generated files
```
git clone https://github.com/hashicorp/consul-helm.git
cd consul-helm
mkdir -p ./manifests
helm template --name consul-oc --output-dir ./manifests -f oc.values.yaml .
cd ./manifests/consul/templates/

# Organize generated templates into directories
mkdir -p server && mv server-* server
mkdir -p client && mv client-* client
mkdir -p mesh-gateway && mv mesh-gateway-* mesh-gateway
mkdir -p connect-inject && mv connect-inject-* connect-inject
mkdir -p sync-catalog && mv sync-catalog-* sync-catalog
```

Adjust the generated .yaml files as needed and use `oc` to apply generated .yaml files.

## Deploy server
```
cd server/
oc apply -f server-serviceaccount.yaml
oc apply -f consul-server-scc.yaml
oc get scc consul-server
oc adm policy add-scc-to-user consul-server -z consul-oc-consul-server
cd .. && oc apply -f server/
```

## Deploy client
```
cd client/
oc apply -f client-serviceaccount.yaml
oc apply -f consul-client-scc.yaml
oc get scc consul-client
oc adm policy add-scc-to-user consul-client -z consul-oc-consul-client
cd .. && oc apply -f client/
```

## Apply Connect inject, sync catalog, UI and DNS service
```
oc apply -f sync-catalog/
oc apply -f connect-inject/
oc apply -f dns-service.yaml
oc apply -f ui-service.yaml

# Check consul deployment
oc exec -it consul-oc-consul-server-0 -- consul members

# Apply license
oc exec -it consul-oc-consul-server-0 -- consul license put <license>
```

## Deploy example application
git clone https://github.com/chuysmans/intro-to-consul-connect-with-kubernetes.git
