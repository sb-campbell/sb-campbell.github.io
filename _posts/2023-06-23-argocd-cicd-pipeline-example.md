---
title: ArgoCD GitOps and Application CI/CD Pipeline
date: 2023-06-23 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm,argocd,cicd]     # TAG names should always be lowercase
---

## Overview

### CI in CI/CD

The 'CI' in CI/CD stands for 'continuous integration' and is a methodology for developing application code such that additional application functionality and bug-fixes are continuously applied in a stream of changes. Generally, this utilizes a GitHub repository to control application source code. As code changes are committed, tools such as Jenkins are used to automatically compile and test new builds, and, if successful, create new version tagged Docker containers and upload to a container repo such as Docker Hub.

### CD in CI/CD

The 'CD' in CI/CD stands for 'continuous delivery or deployment' and is a methodology for sustaining application infrastructure in a particular environment (dev, stage, prod, DR, etc.) by monitoring changes to the application and new version builds, and automatically applying those changes to the infrastructure.

### GitOps

GitOps is a term coined based on the utilization of Git and GitHub source control changes and commits as the driver for automatic operational infrastructure deployments.

## GitHub repos

Under normal development processes we would utilize two GitHub repositories.

1. An application source code repo. 
2. An infrastructure repo sourcing the Kubernetes orchestration configurations for a particular application and deployment environment (ie. dev or prod). __NOTE__: A production environment would likely require greater controls, probably via GitHub pull requests and approvals.
3. __OPTIONAL__: Repository or local directory to contain Terraform .hcl code to install ArgoCD. This will also contain our ArgoCD application resource configuration code.

For this example we'll forego the application source code repo, and simulate it by tagging our own versions of a publicly available container image (ie. nginx). We can then mock our own incremental version tags and simulate CI (Continuous Integration).

-

## Prep

### Prep - ArgoCD application install, console and login

See my previous blog article instructing how to [install ArgoCD](https://sb-campbell.github.io/posts/argocd-install-k8s-helm-tf/).<br>

Recall at the end of that article you should have an operational ArgoCD application running and available on [http://localhost:8080](http://localhost:8080)...

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

__NOTE__: If this is a cloud install you'll have a different URL.<br>

Login to the ArgoCD console via your browser using the 'admin' user and password extracted from the 'argocd-initial-admin-secret' secret...

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo -e "\n"
```

### Prep - Create the GitHub repository for the ArgoCD GitOps Pipeline

Create a repo in your GitHub account. In my case I named it 'CICD-ArgoCD-GitOps-Demo', create it as 'public', add a README.md file, and clone the repo to your local workstation. (Google search for instructions if needed)

### Prep - Create a Docker Hub account

Create a free [Docker Hub](https://hub.docker.com/) account if you do not already have one. A free account grants you the capacity to store a single private container image, and unlimited public images. Creating a repository is optional and only required for private images. We will skip that.

### Prep - Authenticate local Docker CLI with Docker Hub

Make sure your local Docker CLI is authenticated with your Docker Hub account...

```bash
docker login
```

If you need to login execute ...

```bash
docker login --username {username}
```

### Prep - Cleanup local Docker container images

In my case I should have cleaned up my local Docker images earlier as I had several container images downloaded from prior projects. It got a little confusing identifying which local container images were from prior projects, and which existed as part of the ArgoCD install.

As I had already installed ArgoCD via Terraform (as indicated above in the previous blog) I simply performed a 'terraform destroy' to destroy that environment. I then cleaned up my local Docker container images with...

```bash
docker image ls -a
docker system prune -a
docker image ls -a
```

At the end I still had the basic Docker Desktop and its Kubernetes containers remaining.

I then re-executed 'terraform apply' to re-install ArgoCD.

## Example 1 - Create a Kubernetes CD pipeline with public repo and image

Now that prep is complete we're ready to start our example. We're going to simulate a CI pipeline by downloading the public Nginx container image and providing it a new tag in our own account.

### Create our own tag of the public Nginx container image

We will simulate a CI pipeline using the public 'nginx' image and add our own version tags. At time of authoring this blog the current 'mainline' version is 1.25.1. Pull that image down locally...

```bash
docker pull nginx:1.25.1
docker image ls -a
```

Now to simulate a CI pipeline to deploy a new container image version, let's tag this image with our own personal Docker Hub account username and version tag...

```bash
docker tag nginx:1.25.1 <Docker Hub account username>/nginx:v0.1.0
```

Note that both the original nginx container image and the new tagged version share the same Image ID...

```bash
docker image ls -a
```

Push the newly tagged image to our personal Docker Hub account...

```bash
docker push <Docker Hub account username>/nginx:v0.1.0
```

Verify on [Docker Hub web console](https://hub.docker.com/) -> click drop-down beside your username in the upper right corner -> 'My Profile' -> Repositories -> latest tagged version of the Nginx container image -> 'Tags'. See your new tag.

### Create a Kubernetes deployment using tagged Nginx image in our GitOps Infrastructure repo

We're finally getting to the heart of our first example. Create a Kubernetes deployment using our newly tagged container image. We'll place the Kubernetes IaC resource orchestration code (.yaml) in our new GitHub repo.

From your terminal 'cd' to your local copy of the GitHub 'GitOps Infrastructure' repo created earlier. Create a directory for our Kubernetes resource code as 'example1-argocd-gitops-k8s-nginx-app'...

```bash
mkdir example1-argocd-gitops-k8s-nginx-app
cd example1-argocd-gitops-k8s-nginx-app
```

Explicitly create a 'my-app-prod' namespace to separate Kubernetes resources. Create a '0-namespace.yaml' file and add...

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: my-app-prod
```

Create a Kubernetes deployment for our application based on the newly tagged Nginx image. Create a '1-deployment.yaml' file and add...

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: my-app-prod
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: <Docker Hub username>/nginx:v0.1.0
          ports:
            - containerPort: 80
```

__EXPLANATION__: By placing this Kubernetes resource code (.yaml files) in our Infrastructure Repo our new ArgoCD application will 'watch' this repo and apply our infrastructure changes automatically. This will be explained further shortly.

```bash
$ ls -1 example1-argocd-gitops-k8s-nginx-app/
0-namespace.yaml
1-deployment.yaml
```

Perform initial Git commit and push to the remote GitHub repo...

```bash
$ git status
$ git add example1-argocd-gitops-k8s-nginx-app/*.yaml
$ git commit -m "initial commit of example1-argocd-gitops-k8s-nginx-app"
$ git push origin main
```

### Create an ArgoCD application resource

Next we will create an ArgoCD application resource to watch our GitOps Infrastructure repo and automatically apply changes to our Kubernetes deployment.

When we installed ArgoCD into our Kubernetes cluster it automatically created a new __CRD (Customer Resource Definition)__ 'application' resource type. We can use this resource type to add a configuration to our ArgoCD application to watch our GitOps Infrastructure repo and manage our application deployment within Kubernetes.

In your directory or optional repo storing Terraform .hcl code to install ArgoCD we will add Kubernetes resource .yaml code to create our ArgoCD application resource. Create an 'application.yaml' file and add...

```yaml
---
apiVersion: argoproj.io/v1alpha1
# kind - CRD - Customer Resource Definition - automatically created by the ArgoCD Helm chart
kind: Application
metadata:
  # name - Application name within ArgoCD
  name: my-app-prod
  # namespace - The namespace of ArgoCD (NOT your application deployment)
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  # project - Projects provide a logical grouping of applications, useful if multiple teams
  project: default
  # source - Source of deployment objects, public GitHub repo (get the .git suffix URL from 'Code' tab)
  # ArgoCD does not follow re-directs
  source:
    repoURL: https://github.com/sb-campbell/cicd-argocd-gitops-demo.git
    # targetRevision - HEAD points to 'main' branch's latest commit, you can use 'git branches', 'git tags', or even regex's
    # In the case of Helm Charts this should point to the chart version
    targetRevision: HEAD
    # path - Path within the GitHub repo
    path: example1-argocd-gitops-k8s-nginx-app                          
  # destination - Useful when using a single ArgoCD instance to deploy applications to multiple clusters
  destination: 
    # server - as application is deployed to same Kubernetes cluster as the ArgoCD instance is running, 
    # this is the path to the local kubernetes API server                                               
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - Validate=true
      - CreateNamespace=false
      - PrunePropagationPolicy=foreground
      - PruneLast=true
```

Review the comments in the .yaml file above for clarity on the use of various settings. This is a minimal/simple resource generation, but, we'll add to it in future examples.

### Sync with GitHub and deploy the new ArgoCD application

Save the file and utilize 'kubectl' to apply it...

```bash
$ kubectl apply -f ./application.yaml 
application.argoproj.io/my-app-prod created
```

Watch your ArgoCD console in your local browser -> Applications tab, you should see the application resource added immediately. Click on the new Application tile to view the App Details. It may not immediately connect with GitHub, download your repo, and apply your Nginx deployment. If the status is 'OutOfSync' you can watch your deployment/pods for a few minutes...

```bash
$ watch kubectl get pods -n my-app-prod
```

My understanding is ArgoCD's default is not to sync with GitHub immediately, however, in my case it was instantaneous on multiple tries. You can demo deleting the application and re-trying with...

```bash
$ kubectl delete -f ./application.yaml 
application.argoproj.io "my-app-prod" deleted
```

To review all sync details and configuration settings with your GitHub repo click on the 'Sync' button. If your application is still 'OutOfSync' click the 'Synchronize' button and leave all other settings at their defaults.

You should now see the application in green 'Synced' status. This indicates ArgoCD has communicated with GitHub, downloaded/synchronized your repo, applied your deployment, and the Git state matches the Kubernetes state.

Review all Kubernetes resources created by your application deployment both visually in the console and via command-line. You should see the new namespace, deployment, replica-set (managed by the deployment) and the pod itself...

```bash
$ kubectl get all -n my-app-prod
NAME                         READY   STATUS    RESTARTS   AGE
pod/nginx-5cd8dd9889-l8kqb   1/1     Running   0          1m

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx   1/1     1            1           1m

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-5cd8dd9889   1         1         1       1m
```

### Simulate CI/CD by creating a new image version

Now let's simulate a full CI/CD pipeline. We can do so by manually creating a new 'tag' version of our Nginx image to simulate an application upgrade.

```bash
$ docker tag nginx:1.25.1 <Your Docker Hub username>/nginx:v0.1.1
$ docker image ls -a | grep -E "REPOSITORY|nginx"
REPOSITORY                                TAG                                        IMAGE ID       CREATED         SIZE
nginx                                     1.25.1                                     eb4a57159180   10 days ago     187MB
sbcampbe/nginx                            v0.1.0                                     eb4a57159180   10 days ago     187MB
sbcampbe/nginx                            v0.1.1                                     eb4a57159180   10 days ago     187MB
```

Push the new image to Docker Hub

```bash
$ docker push <Your Docker Hub username>/nginx:v0.1.1
```

Once again, you can review your new tagged image version in Docker Hub.

Edit your '1-deployment.yaml' Kubernetes deployment configuration file in your local copy of your GitHub repo and update the image version to the new tag...

```yaml
# Edit your 1-deployment.yaml file and change...
#           image: <Your Docker Hub username>/nginx:v0.1.0
# ... to ...
#           image: <Your Docker Hub username>/nginx:v0.1.1
```
 
Commit your changes and push them to your GitHub repo...

```bash
$ git status
$ git add ./1-deployment.yaml
$ git commit -m "simulate upgrade by incrementing deployment's image version tag to v0.1.1"
$ git push origin main
```

### Watch ArgoCD automatically update the deployment

Now we can kind of sit back and watch ArgoCD automatically poll GitHub, download the changes, detect the change to our '1-deployment.yaml', and apply the new deployment configuration. Per the documentation ArgoCD polls GitHub every 3 minutes, but, I've also read 5 minutes. Per my tests it was probably closer to 5 minutes. There is not much change in the ArgoCD console. Everything still shows 'Synced' and green status. The update happens so quickly I was not able to capture the console in a yellow 'OutOfSync' state before it applied the changes. I re-ran the tests several times (v0.1.2, v0.1.3, etc.). 

In the upper section, in the 'Last Sync Result' section, note the 'Comment' which contains the latest Git commit message.

In the lower section; the diagram of resources, slide to the right and notice the 'rs' replica-set resources. The deployment stays the same, in place, and its config is updated. However, new replica-sets are generated for each version and the old is made inactive. Note the new 'rev#'. A new pod is deployed. If we had a larger replica-set we would actually see a rolling deployment update whereby one pod was switched out at a time.

We can see the same thing on the command-line...

```bash
$ kubectl get all -n my-app-prod
```

