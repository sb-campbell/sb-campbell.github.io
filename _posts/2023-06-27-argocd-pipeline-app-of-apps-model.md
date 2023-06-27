---
title: ArgoCD GitOps Pipeline App-of-Apps Model
date: 2023-06-27 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm,argocd,cicd]     # TAG names should always be lowercase
---

## Overview

This article will provide a high level overview of the ArgoCD App-of-Apps pattern for kubernetes orchestration deployments. It will build heavily on last week's article on 'ArgoCD CI/CD Pipelines'. Please review that article first if you have not already done so.

This is a model for multiple application deployments within a single Kubernetes cluster which will be automatically deployed and maintained/upgraded by ArgoCD.

This is the file structure we will end up with...

```
.
└── example2-argocd-app-of-apps
    ├── argocd-app
    │   ├── my-app-one.yaml
    │   └── my-app-two.yaml
    ├── environments
    │   └── stage
    │       └── my-apps-stage.yaml
    ├── my-app-one
    │   ├── 0-namespace.yaml
    │   └── 1-deployment.yaml
    ├── my-app-two
    │   ├── 0-namespace.yaml
    │   └── 1-deployment.yaml
    └── upgrade.sh
```

## My-App-One and My-App-Two

Start with the same GitOps repo and create a top level 'example2-argocd-app-of-apps' directory. Within this directory create two sub-directories 'my-app-one' and 'my-app-two'. These represent the two applications we will deploy into our environment. They will be the same single nginx deployment. Copy the original '0-namespace.yaml' and '1-deployment.yaml' files into both. Each app deployment will have their own copies of each file.

In the '0-namespace.yaml' file in each sub-directory, modify the namespace to match the sub-directory name... 'my-app-one' or 'my-app-two'...

```yaml
metadata:
  name: my-app-one || my-app-two
```

Likewise, modify the '1-deployment.yaml' file in each sub-directory and modify the namespace...

```yaml
metadata:
  name: nginx
  namespace: my-app-one || my-app-two
```

Also, confirm the image is tag is 'v0.1.0'...

```yaml
    spec:
      containers:
        - name: nginx
          image: <your GitHub username>/nginx:v0.1.0
```

You should now have two nearly identical app deployment configurations.

## ArgoCD applications

We will use basically the same ArgoCD application.yaml CRD, however, we will need two copies, one for each new app.

Create an 'argocd-app' sub-directory within your 'example2...' directory, and copy the original application.yaml in twice... 'my-app-one.yaml' and 'my-app-two.yaml'. Modify the application name in each file...

```yaml
---
...
metadata:
  name: my-app-one || my-app-two
```

Modify the path as appropriate...

```yaml
spec:
  ...
  source:
    ...
    path: example2-argocd-app-of-apps/my-app-one || my-app-two
```

## Create an App-of-Apps abstraction .yaml file

Now let's create another single application.yaml ArgoCD CRD file to act as an abstraction layer and call the other two application definition files. This file is going to represent an environment. 

Create a 'environments/stage' sub-directory within your 'example2...' directory. This single abstraction file will be very similar to the 'my-app-one.yaml' and 'my-app-two.yaml' application CRD files we just created, but, will call both those as they are in the same sub-directory.

Create a 'my-apps-stage.yaml' file...

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-apps-stage
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<your GitHub username>/cicd-argocd-gitops-demo.git
    targetRevision: HEAD
    path: example2-argocd-app-of-apps/argocd-app
  destination:
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

## Commit and push your changes

That's it. Git add, commit, push your changes...

```bash
git add .
git commit -m "Example 2 - app of apps"
git push origin main
```

## ArgoCD console

If your ArgoCD console is no longer active, perform the port forward action and login with 'admin' and the contents of the 'argocd-initial-admin-secret' secret. 

Verify you have no applications installed in ArgoCD. If you do, perform the cleanup steps as defined in the previous blog article.

Deploy the new 'stage' application and two associate my-app... applications...

```bash
kubectl apply -f example2-argocd-app-of-apps/environments/stage/my-apps-stage.yaml
```

If all went well you should see 'my-apps-stage', 'my-app-one' and 'my-app-two' applications within the ArgoCD console. 

## Script to simulate CI/CD application upgrades

In the root of your 'example2...' directory create an upgrades.sh script and add the following...

```bash
#!/bin/bash

# exit when any command fails
set -e

new_ver=$1
image_owner="<GitHub username>"
image_base="nginx"
image_base_tag="1.25.1"
git_repo_url="<your GitHub GitOps repo>"
base_folder="example2-argocd-app-of-apps"

# array containing the resource .yaml files to be upgraded, space delimited list
appsArray=("my-app-one/1-deployment.yaml" "my-app-two/1-deployment.yaml")

#####################################
# Main
#####################################

echo "new version: ${new_ver}"

# Simulate release of the new docker images
docker tag ${image_base}:${image_base_tag} ${image_owner}/${image_base}:${new_ver}

# Push new version to dockerhub
docker push ${image_owner}/${image_base}:${new_ver}

# Create temporary folder
tmp_dir=$(mktemp -d)
echo "tmp_dir: ${tmp_dir}"

# Clone GitHub repo
git clone ${git_repo_url} ${tmp_dir}

# Update image tag
for app_item in ${appsArray[@]}; do
  # -i - update in place, 
  # -e - script, or following command treated as a script
  echo ${app_item}
  sed -i '' -e "s/${image_owner}\/${image_base}:.*/${image_owner}\/${image_base}:${new_ver}/g" ${tmp_dir}/${base_folder}/${app_item}
done

# Commit and push
cd $tmp_dir
git add .
git commit -m "Update image to $new_ver"
git push

# Optionally on build agents - remove folder
rm -rf $tmp_dir

```

This script will make it very easy to simulate creating a new container image, uploading it, modifying the appropriate .yaml configuration files, and deploying it.

Make the new script executable...

```bash
chmod u+x example2-argocd-app-of-apps/upgrade.sh
```

## Execute upgrade.sh to perform an application upgrade

```bash
./example2-argocd-app-of-apps/upgrade.sh "v0.1.1"
```

Watch the 'my-apps-stage' app within the ArgoCD console. It may take 3-5 minutes to refresh, or you can click 'refresh'. See the 'Current Sync Status' section and comment. You should see the commit to ver. 'v0.1.1'. 

Feel free to perform a couple more upgrades to 'v0.1.2' and 'v0.1.3' if you wish.

## Cleanup your stage environment

Cleanup all three ArgoCD applications...

```bash
kubectl delete -f example2-argocd-app-of-apps/environments/stage/my-apps-stage.yaml
```

You can reset your GitOps repo to 'v0.1.0' if you wish.

That's it. You now have a model for deploying and automatically maintaining/upgrading multiple apps within a single Kubernetes cluster!

## Special Thanks

- [Anton Putra](https://www.youtube.com/@AntonPutra) - [ArgoCD Tutorial For Beginners - GitOps CD For Kubernetes](https://www.youtube.com/watch?v=zGndgdGa1Tc&t=1189s)