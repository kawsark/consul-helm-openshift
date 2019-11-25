# consul-helm-openshift
This repository provides a set of steps to deploy consul-helm on OpenShift using only client side Helm tool. This alleviates the need to have Helm's server side component (Tiller) installed. This has been tested with OpenShift 3.12 and 4.2. 

Note: this deployment is for testing purposes and may not be suitable for production. Please review each .yaml file carefully against existing security policies before applying them to your Kubernetes (OpenShift) cluster.

Steps:
- Adjust Kubeconfig to ensure `oc` or `kubectl` tools work with your OpenShift cluster
- Generate Kubernetes YAML templates using helm client side tooling
- Deploy Consul using a script
- Or, Deploy Consul manually:
  - Deploy Consul server agents
  - Deploy Consul client agents
  - Apply Connect inject, sync catalog, UI and DNS service
- Deploy example application

## Adjust Kubeconfig
The steps in this repository requires either the OpenShift CLI tool `oc`, or the Kubernetes `kubectl` tool. The CLI tool should be configured to interact with the target OpenShift cluster. Depending on your security setup you may need to run these steps from a bastion server. 
```
export KUBECONFIG=/path/to/kubeconfig:$KUBECONFIG
# Test the config
oc clusterinfo #or kubectl clusterinfo
oc config view #or kubectl config view
oc get pods #or kubectl get pods
```
- Note: If you used RedHat's installer to install OpenShift 4.2, then you will have an directory `<installer-dir>/auth/` that will contain the kubeconfig file. 

## Generate consul-helm templates (Optional)
This repo already includes example consul-helm generated files. However you can use the steps below to generate the YAML templates. Please adjust the example [oc.values.yaml](oc.values.yaml) file before running `helm template` command.
```
git clone https://github.com/hashicorp/consul-helm.git
cd consul-helm
mkdir -p ./manifests
helm template --name consul-oc --output-dir ./manifests -f oc.values.yaml .
```

**Important**: Please review and adjust the generated .yaml files as needed.

## Deploy Consul using a script
A bash script `consul-oc.sh` is included here which uses `oc` or `kubectl` CLI tool to apply the generated templates. 
- Note: this script will only work if Persistent Volumes are available. If not, please use the manual steps below.
- If you generated your own YAML template, please adjust the `manifests_dir` below.
- Adjust variables at the top of the script if needed
```
# setup environment
manifests_dir=$(pwd)/manifests/consul/templates
cli=oc #Set this to oc or kubectl
license_file=license.hclic #Set path to license file if using consul-enterprise image
```
- Run the script as below
```
./consul-oc.sh
```
- Skip to: Deploy an example application

## Deploy Consul manually
If you prefer, you may run `oc apply` or `kubectl apply` commands manually as below. 

### Organize generated templates into directories
```
cd ./manifests/consul/templates/
mkdir -p server && mv server-* server
mkdir -p client && mv client-* client
mkdir -p mesh-gateway && mv mesh-gateway-* mesh-gateway
mkdir -p connect-inject && mv connect-inject-* connect-inject
mkdir -p sync-catalog && mv sync-catalog-* sync-catalog
```

### Deploy Consul server agents
Check if your installation supports Persistent Volumes. To do this, please run the `kubectl get sc` command and see if there is a default storage class defined as shown below:
```
kubectl get sc #or, oc get sc
```
If you do **not** see an output showing a default StorageClass please use these steps first:[disable server Persistent Volumes](disable_pvc.md).

From the root of the repository, please run the commands below. You can substitute `kubectl` for `oc` if needed.
```
cp security-contexts/consul-server-scc.yaml manifests/consul/templates/
cd manifests/consul/templates
oc apply -f server/server-serviceaccount.yaml
oc apply -f consul-server-scc.yaml
oc get scc consul-server
oc adm policy add-scc-to-user consul-server -z consul-oc-consul-server
oc apply -f server/
```

### Deploy Consul client agents
From the root of the repository, please run the commands below. You can substitute `kubectl` for `oc` if needed.
```
cp security-contexts/consul-client-scc.yaml manifests/consul/templates/
cd manifests/consul/templates/
oc apply -f client/client-serviceaccount.yaml
oc apply -f consul-client-scc.yaml
oc get scc consul-client
oc adm policy add-scc-to-user consul-client -z consul-oc-consul-client
oc apply -f client/
```

### Apply Connect inject, sync catalog, UI and DNS service
From the root of the repository, please run the commands below. You can substitute `kubectl` for `oc` if needed.
```
cd manifests/consul/templates/
oc apply -f sync-catalog/
oc apply -f connect-inject/
oc apply -f dns-service.yaml
oc apply -f ui-service.yaml

# Check consul deployment
oc exec -it consul-oc-consul-server-0 -- consul members

# Apply license (if you used an enterprise image)
oc exec -it consul-oc-consul-server-0 -- consul license put <license>
```

## Deploy an example application
We will deploy an example application with two services: Dashboard and Counting. The Dashboard service calls the counting service which returns the quantity of times it has been invoked.

From the root of the repository, please run the commands below. You can substitute `kubectl` for `oc` if needed.
```
oc apply -f services/

# The counting and dashboard pods should indicate 2/2 containers deployed
oc get pods

# Get the Dashboard service NodePort
oc get svc/dashboard-service-nodeport

# Get IP address of nodes:
oc get nodes -o wide

# Access the dashboard on your web-browser:
http://<internal-or-external-ip>:<nodeport>/
```