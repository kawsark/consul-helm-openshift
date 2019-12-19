# consul-helm-openshift
This repository provides a set of steps to deploy consul-helm on OpenShift using only client side Helm tool. This alleviates the need to have Helm's server side component (Tiller) installed. This has been tested with OpenShift 3.12 and 4.2.10. 

Note: 
- This deployment is for testing purposes and may not be suitable for production. Please review each .yaml file carefully against existing security policies before applying them to your Kubernetes (OpenShift) cluster.
- While this deployment does work for OpenShift 3.12, the sidecar injector functionality is disabled since mutator webhooks are in preview for OpenShift 3.x. Mutator webhooks must be enabled for the sidecar injector to work correctly in OpenShift 3.12.

Steps:
0. Install an Openshift cluster
1. Adjust Kubeconfig to ensure `oc` or `kubectl` tools work with your OpenShift cluster
1. Generate Kubernetes YAML templates using helm client side tooling
1. Deploy Consul using a script (Option A), or manually (Option B)
1. Check Consul deployment
1. Deploy example application
1. Cleanup

## 0. Install an OpenShift cluster
Installing the cluster is beyond the scope of this guide. This guide has been tested against an OpenShift 4.2.10 cluster on AWS using the RedHat Installer: [https://cloud.redhat.com/openshift/install/aws/installer-provisioned](https://cloud.redhat.com/openshift/install/aws/installer-provisioned)



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
```

## 4. Check Consul deployment
Check that all the pods are up, you should see something similar to the following. You may have other pods consul pods if you applied the mesh gateways.
```
watch oc get pods
Every 2.0s: oc get pods

NAME                                                              READY   STATUS    RESTARTS   AGE
consul-oc-consul-connect-injector-webhook-deployment-797ff6dzhg   1/1     Running   0          14m
consul-oc-consul-d9s2z                                            1/1     Running   0          14m
consul-oc-consul-p96xd                                            1/1     Running   0          14m
consul-oc-consul-server-0                                         1/1     Running   0          10m
consul-oc-consul-server-1                                         1/1     Running   0          14m
consul-oc-consul-server-2                                         1/1     Running   0          14m
consul-oc-consul-sync-catalog-795664bc59-52lpg                    1/1     Running   0          14m
consul-oc-consul-vdftb                                            1/1     Running   0          14m
```

Check consul deployment, you should see something similar to the following.
```
oc exec -it consul-oc-consul-server-0 -- consul members

Node                          Address           Status  Type    Build  Protocol  DC            Segment
consul-oc-consul-server-0     10.131.0.16:8301  alive   server  1.6.2  2         oc-us-east-1  <all>
consul-oc-consul-server-1     10.129.2.13:8301  alive   server  1.6.2  2         oc-us-east-1  <all>
consul-oc-consul-server-2     10.128.2.13:8301  alive   server  1.6.2  2         oc-us-east-1  <all>
ip-10-0-136-245.ec2.internal  10.129.2.12:8301  alive   client  1.6.2  2         oc-us-east-1  <default>
ip-10-0-151-78.ec2.internal   10.131.0.12:8301  alive   client  1.6.2  2         oc-us-east-1  <default>
ip-10-0-171-157.ec2.internal  10.128.2.12:8301  alive   client  1.6.2  2         oc-us-east-1  <default>
```

If you used an enterprise image, please apply license as below (once Consul server readiness checks are passing).
```
oc exec -it consul-oc-consul-server-0 -- consul license put <license>
```

## 5. Deploy an example application
We will deploy an example application with two services: Dashboard and Counting. The Dashboard service calls the counting service which returns the quantity of times it has been invoked.

From the root of the repository, please run the commands below. You can substitute `kubectl` for `oc` if needed.
```
oc apply -f app-example/

# The counting and dashboard pods should indicate 3/3 containers deployed
oc get pods

# Get the Dashboard service LoadBalancer details
oc get svc/dashboard-service-loadbalancer

# Access the dashboard on your web-browser (note that it takes some time to provision the ELB).
http://<lb-dns>
```

## 6. Cleanup
Please follow the steps in 1. Adjust Kubeconfig, then run the `cleanup.sh` script:
```
chmod +x cleanup.sh
./cleanup.sh
```
