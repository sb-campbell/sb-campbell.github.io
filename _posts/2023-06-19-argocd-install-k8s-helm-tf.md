---
title: ArgoCD Installation Into Kubernetes Cluster
date: 2023-06-19 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm,argocd]     # TAG names should always be lowercase
---

# Overview

ArgoCD is a Continuous Deployment/Delivery (CD) tool which ensures the Kubernetes state stays synchronized with the IaC definitions held in Git source control.

As an overview... as pull requests merge changes in a Git infrastructure repository, ArgoCD clones and polls the Git repo and executes 'kubectl apply' to implement changes on regular intervals. Most of the automation is actually built into Kubernetes definitions not ArgoCD.

A use case to also employ Continuous Integration (CI) might utilize Jenkins to detect changes to application source code held in a Git application source repo, and automatically compile, test, and upload new container versions to Docker Hub or other container image repository. Jenkins could then update the infrastructure repo with tags associated with the new container versions and optionally submit and even approve pull requests to merge changes into the master branch. ArgoCD could then poll, detect and apply changes as described above.

Kubernetes Dashboard also provides information on the state of Kubernetes resources in your cluster and on any errors that may have occurred.

# ArgoCD Install

There are a couple methods for installing ArgoCD into your Kubernetes cluster...

## ArgoCD Installation via kubectl

Per the [docs](https://argo-cd.readthedocs.io/en/stable/getting_started/) ArgoCD can be installed via kubectl...

```bash
$ kubectl create namespace argocd
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

ArgoCD install via Kubernetes manifests is really not the preferred method of installation. It requires a couple of extra steps as reviewed in [this](https://www.opsmx.com/blog/argo-cd-installation-into-kubernetes-using-helm-or-manifest/) well-written blog post.

## ArgoCD Installation via Helm

Alternatively, installation via Helm is preferred. It can be accomplished either via the 'helm' command or via Terraform. 

### ArgoCD Installation via 'helm' command

First, we need to add the 'argo' repo to our helm installation...

```bash
$ helm repo add argo https://argoproj.github.io/argo-helm
```

Next, we can verify the repo and get updates for all installed repos...

```bash
$ helm repo list
$ helm repo update           # update the helm repo index after adding a repo
```

Next, let's check the latest version (ie. 3.35.4) of the Helm chart for use in install...

```bash
$ helm search repo argocd    # search for the argoCD chart, identify latest chart version
```

__NOTE__: Searching for 'argocd' vs. 'argo-cd' results in two different versions. At this time I do not have an answer as to the difference. Make sure to use 'argocd'

Generally, you will wish to override at least a couple default values. Export the default configuration to a local file for later manipulation...

```bash
$ helm show values argo/argo-cd --version <version ie. '3.35.4'> > argocd-defaults.yaml
```

Review the default values and create a yaml file to contain any non-default values you wish to override (ie. ./override-values/argocd.yaml)...

```yaml
---
# these are override values to the defaults used by the ArgoCD helm 
# install defaults were exported into 
# ./override-values/argocd-defaults.yaml

# latest container version at time of this blog, see...
#   quay.io/argoproj/argocd 
#     or 
#   hub.docker.com/r/argoproj/argocd/tags  
# 
# Excerpted from argocd-defaults.yaml...
# global:
#   image:
#     # -- If defined, a repository applied to all ArgoCD 
#     #    deployments
#     repository: quay.io/argoproj/argocd
#     # -- Overrides the global ArgoCD image tag whose default is 
#     #    the chart appVersion
#     tag: ""
global:
  image:
    tag: "v2.6.6"

# prevent ArgoCD from generating self-signed cert and auto-forwarding HTTP to HTTPS
# if you wish to support HTTPS use 'ingress', terminate HTTPS at that level, and route plain HTTP to ArgoCD
# 
# Excerpted from argocd-defaults.yaml...
# -- Additional command line arguments to pass to Argo CD server
# extraArgs: []
#  - --insecure
server:
  extraArgs:
    - --insecure    
```

Install the AargoCD Helm chart specifying the namespace, instructing creation of the namespace, specifying the chart version, and specifying the file containing non-default config values...

```bash
$ helm install argocd -n argocd --create-namespace argo/argo-cd --version 3.35.4 -f ./override-values/argocd.yaml
```

Carefully review output of the 'helm install' command for log output of errors and additional instructions...

```
NAME: argocd
LAST DEPLOYED: Sat Jun 17 15:00:51 2023
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
In order to access the server UI you have the following options:

1. kubectl port-forward service/argocd-server -n argocd 8080:443

    and then open the browser on http://localhost:8080 and accept the certificate

2. enable ingress in the values file `server.ingress.enabled` and either
      - Add the annotation for ssl passthrough: https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/ingress.md#option-1-ssl-passthrough
      - Add the `--insecure` flag to `server.extraArgs` in the values file and terminate SSL at your ingress: https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/ingress.md#option-2-multiple-ingress-objects-and-hosts


After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://github.com/argoproj/argo-cd/blob/master/docs/getting_started.md#4-login-using-the-cli)
```

Query the status of the ArgoCD Helm chart at any time to view the same instructional output...

```bash
helm status argocd -n argocd
```

List installed Helm charts...

```bash
helm list -A     # list installed helm charts (-A - all namespaces)
```

Review the Kubernetes resources deployed by the Helm chart...

```bash
$ kubectl get all -n argocd        # pods, deployments, services, replicasets
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/argocd-application-controller-77fd6ccc77-g4w64   1/1     Running   0          2m48s
pod/argocd-dex-server-56789f5c9f-7rfxh               1/1     Running   0          2m48s
pod/argocd-redis-6b5b7d98dc-85xq7                    1/1     Running   0          2m48s
pod/argocd-repo-server-5bcc78b4f9-9bjss              1/1     Running   0          2m48s
pod/argocd-server-86b7cc6668-tqvmw                   1/1     Running   0          2m48s

NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/argocd-application-controller   ClusterIP   10.109.62.231    <none>        8082/TCP            2m48s
service/argocd-dex-server               ClusterIP   10.109.92.27     <none>        5556/TCP,5557/TCP   2m48s
service/argocd-redis                    ClusterIP   10.109.47.238    <none>        6379/TCP            2m48s
service/argocd-repo-server              ClusterIP   10.109.3.73      <none>        8081/TCP            2m48s
service/argocd-server                   ClusterIP   10.103.201.176   <none>        80/TCP,443/TCP      2m48s

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argocd-application-controller   1/1     1            1           2m48s
deployment.apps/argocd-dex-server               1/1     1            1           2m48s
deployment.apps/argocd-redis                    1/1     1            1           2m48s
deployment.apps/argocd-repo-server              1/1     1            1           2m48s
deployment.apps/argocd-server                   1/1     1            1           2m48s

NAME                                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/argocd-application-controller-77fd6ccc77   1         1         1       2m48s
replicaset.apps/argocd-dex-server-56789f5c9f               1         1         1       2m48s
replicaset.apps/argocd-redis-6b5b7d98dc                    1         1         1       2m48s
replicaset.apps/argocd-repo-server-5bcc78b4f9              1         1         1       2m48s
replicaset.apps/argocd-server-86b7cc6668                   1         1         1       2m48s

$ kubectl get secrets -n argocd
NAME                           TYPE                 DATA   AGE
argocd-initial-admin-secret    Opaque               1      4m20s
argocd-secret                  Opaque               3      4m20s
sh.helm.release.v1.argocd.v1   helm.sh/release.v1   1      4m20s
```

### Cleanup of the Helm installed ArgoCD release

Query the installed Helm releases...

```bash
$ helm list -n argocd
NAME  	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART         	APP VERSION
argocd	argocd   	1       	2023-06-17 15:00:51.945943 -0400 EDT	deployed	argo-cd-3.35.4	v2.2.5     
```
 
Uninstall the ArgoCD Helm release...

```bash
$ helm delete argocd -n argocd
release "argocd" uninstalled

$ kubectl delete secret -n argocd argocd-initial-admin-secret
secret "argocd-initial-admin-secret" deleted

$ kubectl get all -n argocd
No resources found in argocd namespace.

$ kubectl get secrets -n argocd
No resources found in argocd namespace.
```

### ArgoCD Helm Release Installation via Terraform

**NOTE**: This method actually uses Helm for the installation of ArgoCD, however, it uses Terraform IaC to automate and manage the installation.

Specify the Helm provider in a Terraform block (ie. 0-provider.tf)...

```terraform
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    
    # optional if docker-desktop is the current/default context
    config_context = "docker-desktop"   
  }
}
```

Specify the Helm chart release and additional configuration via a 'helm_release' resource...

```terraform
resource "helm_release" "argocd" {
  
  # convention - name after the application being deployed
  name = "argocd"                          

  repository       = "https://argoproj.github.io/argo-helm"
  
  # pre-pending the repo name is unnecessary, just chart name
  chart            = "argo-cd"             
  
  # best to use the default namespace as indicated in the default config so as to avoid req. override values
  namespace        = "argocd"              
  create_namespace = true
  
  # helm chart version
  version          = "3.35.4"              
  
  # alternative methods of providing override values
  # 1 - use set statements
  # 2 - (preferred) specify a file containing override values...
  values = [file("./override-values/argocd.yaml")]
}
```

In the above configuration we are specifying a file which contains some values to override a couple of defaults...

```yaml
# latest container version at time of video, see...
#   quay.io/argoproj/argocd or 
#   hub.docker.com/r/argoproj/argocd/tags or 
# 
# Excerpted from argocd-defaults.yaml...
# global:
#   image:
#     # -- If defined, a repository applied to all ArgoCD deployments
#     repository: quay.io/argoproj/argocd
#     # -- Overrides the global ArgoCD image tag whose default is the chart appVersion
#     tag: ""
global:
  image:
    tag: "v2.6.6"

# prevent ArgoCD from generating self-signed cert and auto-forwarding HTTP to HTTPS
# if you wish to support HTTPS use 'ingress', terminate HTTPS at that level, and route plain HTTP to ArgoCD
# Excerpted from argocd-defaults.yaml...
# -- Additional command line arguments to pass to Argo CD server
# extraArgs: []
#  - --insecure
server:
  extraArgs:
    - --insecure    
```

Initialize terraform which will...
- initialize all specified providers
- establish a terraform state

```bash
terraform init
terraform plan
terraform apply   # confirm with 'yes'
```

Review the Kubernetes resources installed via Terraform/Helm...

```bash
kubectl get all -n argocd
kubectl get secrets -n argocd
```

Query the status of the ArgoCD Helm chart and review output instructions as described above...

```bash
helm status argocd -n argocd
```

If the apply error'd or appears to hang review Helm pending activities...

```bash
helm list --pending -A     # list potentially failed charts (if 'terraform apply' err'd)
```

List installed Helm charts...

```bash
helm list -A               # list installed helm charts (-A - all namespaces)
```

List the created secrets...

```bash
kubectl get secrets -n argocd
kubectl get secrets -n argocd -o yaml argocd-initial-admin-secret
```

Verify all pods are 'Running' and not in 'Crash Loop' or 'Pending' status...

```bash
kubectl get pods -n argocd
```

# Startup of and Login to the  ArgoCD Application Console

As described above, most of the relevant details for the installed ArgoCD application can be listed using 'helm status'...

```bash
helm status argocd -n argocd
```

The installation created 'argocd-initial-admin-secret' which contains the password for the admin user used to login to the ArgoCD console...

```bash
kubectl get secrets -n argocd
```

Review all the details of the secret in yaml format...

```bash
kubectl get secrets -n argocd -o yaml argocd-initial-admin-secret
```

The secret is encoded in base64. Decode it for use...

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo -e "\n"
```

Port forward the 'argocd-server' service listening on port 80 to port 8080 on 'localhost'. 

__NOTE__: Command is interactive...

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

View the ArgoCD application console...

[http://localhost:8080](http://localhost:8080)

- Username is 'admin'
- Password is the decoded content of the 'argocd-initial-admin-secret'


