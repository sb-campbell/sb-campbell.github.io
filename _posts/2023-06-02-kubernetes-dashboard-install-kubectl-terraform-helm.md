---
title: Install Kubernetes Dashboard (3 methods) - Kubectl CLI, Terraform, Helm
date: 2023-06-02 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm,k2tf]     # TAG names should always be lowercase
---

Kubernetes Dashboard is a web-based Kubernetes user interface. You can use Kubernetes Dashboard to deploy containerized applications to a Kubernetes cluster, troubleshoot your containerized application, and manage the cluster resources. You can also use Kubernetes Dashboard to get an overview of applications running on your cluster and for creating or modifying individual Kubernetes resources (such as Deployments, Jobs, DaemonSets, etc). For example, you can scale a Deployment, initiate a rolling update, restart a pod or deploy new applications using a deploy wizard.

Kubernetes Dashboard also provides information on the state of Kubernetes resources in your cluster and on any errors that may have occurred.

## Using and viewing the Kubernetes Dashboard on your local browser

Kubernetes Dashboard is a web service which executes within the Kubernetes cluster (either local or remote). However, it is not generally implemented as a public web service. Rather, it is privately 'proxied' through the admin user's local (or remote) Kubernetes CLI connection and made available through the user's browser on 'localhost:port'. If you desire a more production-ready and open deployment consider implementing an ingress service, appropriate SSL cert, and IAM based credentials.

__Production implications__: There are security configuration considerations to note in a production deployment. The user should more fully analyze these implications before deploying on any production resources.

## Links

- [My GitHub repo containing RBAC config files](https://github.com/sb-campbell/skill-samples/tree/main/kubernetes/k8s-dashboard)
- [Kubernetes Dashboard documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Kubernetes Dashboard GitHub home](https://github.com/kubernetes/dashboard)

## Installation of the  Kubernetes Dashboard service

Installation of the Kubernetes Dashboard service is via the 'recommended.yaml' configuration file. Install in your Kubernetes cluster via 'kubectl apply' as follows...

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```
__NOTE__: All Kubernetes Dashboard services are located in the 'kubernetes-dashboard' namespace.

## RBAC (Role Based Access Control)

Create a 'dashboard-admin-user' Service Account with role-based privileged access. See [creating-sample-user.md](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md) in the Kubernetes Dashboard documentation.

View the existing service accounts...
```bash
kubectl get serviceaccount
kubectl get serviceaccount -n kubernetes-dashboard
```

__NOTE__: I have created kubernetes .yaml config files as directed by the documentation indicated above. These config files are available in my GitHub repository [here](https://github.com/sb-campbell/skill-samples/tree/main/kubernetes/k8s-dashboard), or can easily be created as per the documentation.

Create a 'dashboard-admin-user' service account in the 'kubernetes-dashboard' namespace.

__NOTE__: For clarity I have changed 'admin-user' suggested in the Kubernetes Dashboard documentation to 'dashboard-admin-user'.
```bash
kubectl apply -f ./dashboard-adminuser-serviceaccount.yaml
```

View the new service account...
```bash
kubectl get serviceaccount -n kubernetes-dashboard
```

As per documentation, most likely the ClusterRole 'cluster-admin' already exists. Verify...
```bash
kubectl get clusterrole
```

Create the ClusterRoleBinding to grant the 'cluster-admin' ClusterRole to the new 'dashboard-admin-user' service account...
```bash
kubectl apply -f ./dashboard-cluster-admin-clusterrolebinding.yaml
```

View the role assignment...
```bash
kubectl get clusterrolebinding -o wide | grep dashboard-admin
```

## Generate an Access Token for use logging into the Kubernetes Dashboard

Generate an access token for the 'dashboard-admin-user' and copy it to the clipboard (__MacOS__)...
```bash
kubectl create token dashboard-admin-user -n kubernetes-dashboard | pbcopy
```

## Start the Kubernetes Dashboard

Initiate the Kubernetes Dashboard service and 'proxy' it through to the admin user's Kubernetes CLI...
```bash
kubectl proxy
```

__NOTE__: The above command is interactive and will remain active until closed. When finished press '__ctrl-C__' to close the proxy connection.

## Browse to the Kubernetes Dashboard via browser

Via preferred browser visit...<br>
[http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

Login utilizing the 'dashboard-admin-user' and access token generated above.

## Close the local proxy connection to the Kubernetes Dashboard service

As noted above, the 'kubectl proxy' command is interactive and will remain active until closed. When finished press 'ctrl-C' to close the proxy connection.

## Delete the Service Account and Cluster Role Binding

If security is a concern, delete the 'dashboard-admin-user' service account and associated cluster role binding...
```bash
kubectl delete -f ./dashboard-adminuser-serviceaccount.yaml
kubectl delete -f ./dashboard-cluster-admin-clusterrolebinding.yamld

# ... or ...

kubectl delete serviceaccount dashboard-admin-user -n kubernetes-dashboard
kubectl delete clusterrolebinding dashboard-admin-user -n kubernetes-dashboard
```

## Delete the Kubernetes Dashboard Service

In older versions of Kubernetes and the Kubernetes Dashboard, deletion of the dashboard service was a bit of an issue. Therefore, of interest to view all resources associated with the dashboard, execute...
```bash
kubectl get secret,sa,role,rolebinding,services,deployments -n=kubernetes-dashboard
```

In later or more recent versions of Kubernetes and Kubernetes Dashboard deletion is much simpler. Simply execute the inverse of installation...
```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

## Alternative Install Method - Helm

Helm is a supported install method, see [Helm install Kubernetes-Dashboard](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard)<br>
Custom installation is also supported.

### Installation

Add kubernetes-dashboard repository
```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
```

Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
```bash
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard
```

### Start the Kubernetes Dashboard

The output of the above installation provides execution instructions...
```bash
# Get the Kubernetes Dashboard URL by running:
export POD_NAME=$(kubectl get pods -n default -l "app.kubernetes.io/name=kubernetes-dashboard,app.kubernetes.io/instance=kubernetes-dashboard" -o jsonpath="{.items[0].metadata.name}")
echo https://127.0.0.1:8443/
kubectl -n default port-forward $POD_NAME 8443:8443
```

### Additional complexity

There are still some complicated connectivity hurdles to overcome, see [Blog - kubernetes-dashboard-helm-installation-and-configuration](https://www.virtualizationhowto.com/2021/06/kubernetes-dashboard-helm-installation-and-configuration/).

### Create Dashboard-Admin service account and associated Cluster-Admin role

See [justmeandopensource/kubernetes](https://github.com/justmeandopensource/kubernetes/blob/master/dashboard/sa_cluster_admin.yaml) for Kubernetes configs for 'dashboard-admin' service account with associated clusterRoleBinding granting 'cluster-admin' privileges.

Execute...
```bash
kubectl create -f ./helm/dashboard-admin.yaml
```

Verify...
```bash
kubectl get sa -n kube-system | grep dashboard
```

### Generate and Copy the Access Token (MacOS)
```bash
kubectl create token dashboard-admin -n kube-system | pbcopy
```

### Browse to the Kubernetes Dashboard

**NOTE**: You will have to manually accept the certificate in the browser with this Helm install method.

Browse to [https://127.0.0.1:8443/](https://127.0.0.1:8443/)

### Uninstall (via Helm)...
```bash
helm delete kubernetes-dashboard
```

### Delete the Dashboard-Admin service account and associated Cluster-Admin role
Execute...
```
kubectl delete -f ./helm/dashboard-admin.yaml
```

### Alternative Install Method - Terraform

Installation of the Kubernetes Dashboard via Terraform involves converting the published and supported Kubernetes Dashboard deployment script - '__recommended.yaml__' file to Terraform HCL utilizing [k2tf](https://github.com/sl1pm4t/k2tf). K2tf is a Kubernetes (.yaml) to Terraform (.tf - HCL) converter.

- [MacOS install of k2tf via Homebrew](https://formulae.brew.sh/formula/k2tf)

Deploying the Kubernetes Dashboard via Terraform is further explored [here]().

__WARNING__: While it is possible to deploy the Kubernetes Dashboard using this method, it is strongly discouraged. It is not supported, and the evolution of the Kubernetes Dashboard will require continual manual conversion of the supported .yaml to Terraform .tf HCL. It is, however, an interesting exercise.
 
