# consul-helm-openshift
This repository provides a set of steps to deploy consul-helm on OpenShift using only client side Helm tool. This alleviates the need to have Helm's server side component (Tiller) installed. This has been tested with OpenShift 3.12 and 4.2. 

Note: this deployment is for testing purposes and may not be suitable for production. Please review each .yaml file carefully against existing security policies before applying them to your Kubernetes (OpenShift) cluster.

Steps:
1. Adjust Kubeconfig to ensure `oc` or `kubectl` tools work with your OpenShift cluster
1. Generate Kubernetes YAML templates using helm client side tooling
1. Deploy Consul using a script (Option A), or manually (Option B)
1. Deploy example application
1. Cleanup

## 1. Adjust Kubeconfig
The steps in this repository requires either the OpenShift CLI tool `oc`, or the Kubernetes `kubectl` tool. The CLI tool should be configured to interact with the target OpenShift cluster. Depending on your security setup you may need to run these steps from a bastion server. 
```
export KUBECONFIG=/path/to/kubeconfig:$KUBECONFIG
# Test the config
oc clusterinfo #or kubectl clusterinfo
oc config view #or kubectl config view
oc get pods #or kubectl get pods
```
- Note: If you used RedHat's installer to install OpenShift 4.2, then you will have an directory `<installer-dir>/auth/` that will contain the kubeconfig file. 

## 2. Generate consul-helm templates (Optional)
This repo already includes example consul-helm generated files. However you can use the steps below to generate the YAML templates. Please adjust the example [oc.values.yaml](oc.values.yaml) file before running `helm template` command.
```
git clone https://github.com/hashicorp/consul-helm.git
mkdir -p consul-helm/manifests
helm template --name consul-oc --output-dir consul-helm/manifests -f oc.values.yaml consul-helm
```
**Important**: Please review and adjust the generated .yaml files as needed.

## 3 (Option A) Deploy Consul using a script
A bash script `consul-oc.sh` is included here which uses `oc` or `kubectl` CLI tool to apply the generated templates. By default it provisions consul OSS v1.6.1.
- Note: this script will only work if Persistent Volumes are available. If not, please use the manual steps below.
- Adjust variables at the top of the script if needed:
  - manifests_dir: if you generated your own YAML template, please adjust the `manifests_dir` below to: `manifests_dir=$(pwd)/consul-helm/manifests/consul/templates`
  - cli: you can choose `oc` or `kubectl`
  - license_file: If you modified `oc.values.yaml` to use a Consul Enterprise image, then please update the value with license file path.
```
# setup environment
manifests_dir=$(pwd)/manifests/consul/templates
cli=oc #Set this to oc or kubectl
license_file=license.hclic #Set path to license file if using consul-enterprise image
```
- Run the script as below
```
chmod +x ./consul-oc.sh
./consul-oc.sh
```
- Skip to: Deploy an example application

## 3 (Option B) Deploy Consul manually
If you prefer, you may run `oc apply` or `kubectl apply` commands manually as below. Below are the associated steps:
- Organize generated templates into directories
- Check if PersistentVolumes are supported
- Deploy Consul server agents
- Deploy Consul client agents
- Deploy Connect inject, sync catalog, UI and DNS service

### Organize generated templates into directories
```
cd ./manifests/consul/templates/
mkdir -p server && mv server-* server
mkdir -p client && mv client-* client
mkdir -p mesh-gateway && mv mesh-gateway-* mesh-gateway
mkdir -p connect-inject && mv connect-inject-* connect-inject
mkdir -p sync-catalog && mv sync-catalog-* sync-catalog
```

### Check if PersistentVolumes are supported
Check if your installation supports Persistent Volumes. To do this, please run the `kubectl get sc` command and see if there is a default storage class defined as shown below:
```
[core@ip-10-0-15-247 ~]$ oc get sc
NAME            PROVISIONER             AGE
gp2 (default)   kubernetes.io/aws-ebs   4d22h
```
If you do **not** see an output showing a default StorageClass please follow these steps first:[disable server Persistent Volumes](disable_pvc.md).

### Deploy Consul server agents
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
```

Once all the containers are showing a status of `Running`, please apply license as below:
```
oc exec -it consul-oc-consul-server-0 -- consul license put <license>
```

## 4. Deploy an example application
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

## 5. Cleanup
Please follow the steps in 1. Adjust Kubeconfig, then run the `cleanup.sh` script:
```
chmod +x cleanup.sh
./cleanup.sh
```
