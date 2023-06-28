---
title: ArgoCD GitOps App-of-Apps Model (Private GitHub and Docker Hub Repos)
date: 2023-06-28 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm,argocd,cicd]     # TAG names should always be lowercase
---

## Overview

This article extends my previous article on deploying an ArgoCD Pipeline in and App of Apps model. This time, we will extend the discussion to include private repos in both GitHub and Docker Hub.

As in the prior article, this is a model for multiple application deployments within a single Kubernetes cluster which will be automatically deployed and maintained/upgraded by ArgoCD. 

This is the file structure we will end up with...

```
.
└── example3-argocd-app-of-apps-private
    ├── argocd-app
    │   ├── git-repo-secret.yaml
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

## Prep

### Private GitHub repo

First we will need a private GitHub repo for the GitOps infrastructure source. On GitHub create a new repository, I named mine 'cicd-argocd-gitops-demo-private', select 'Private', I added a README file -> Create Repository.

Clone this new private repo to your local workstation in a directory of your choosing using the links in the 'Code' dropdown.

For simplicity we will start with the same deployment files as for the public repo. Copy the contents of 'example2-argocd-app-of-apps' directory in your public repo to 'example3-argocd-app-of-apps-private' directory in your new private repo.

### Private Docker Hub repo

Login to Docker Hub and click 'Create Repository'. Name is 'nginx-private' and make sure to select the 'Private' radio button -> Create. 

__NOTE__: You are only allowed a single private repository in the free version of Docker Hub.

## Release tagged nginx container image to private Docker Hub repo

Now we need to release a new tagged base image of the nginx container...

```bash
docker tag nginx:1.25.1 <your Docker Hub username>/nginx-private:v0.1.0
```

You can view this new image...

```bash
docker image ls | grep nginx
```

Push the image to your new private Docker Hub repository.

If you're not already logged into to Docker Hub from the command-line, login with...

```bash
docker login --user <your Docker Hub username>
```

Push the new tagged private image to your new private Docker Hub repo...

```bash
docker push <your Docker Hub username>/nginx-private:v0.1.0
```

Verify your new image in the Docker Hub web console.

## Update the app deployment files to use the new private image

Edit both 'my-app-one' and 'my-app-two' '1-deployment.yaml' files...

```bash
vi example3-argocd-app-of-apps-private/my-app-one/1-deployment.yaml 
vi example3-argocd-app-of-apps-private/my-app-two/1-deployment.yaml 
```

... update the image name ...

```
image: <your Docker Hub username>/nginx-private:v0.1.0
``` 

## Update the ArgoCD app CRD deployment files

We'll make two changes...

1. We will not use https to connect to our GitHub repo
2. We will modify the GitHub repo to specify our new private repo

```bash
vi example3-argocd-app-of-apps-private/argocd-app/my-app-one.yaml
vi example3-argocd-app-of-apps-private/argocd-app/my-app-two.yaml
```

... modify ...

```yaml
    repoURL: git@github.com:<your GitHub username>/cicd-argocd-gitops-demo-private.git
    targetRevision: HEAD
    path: example3-argocd-app-of-apps-private/my-app-one && my-app-two
```

## Update the App-of-Apps abstraction file to point to our new path

Update ...

```bash
vi example3-argocd-app-of-apps-private/environments/stage/my-apps-stage.yaml
```

... modify ...

```yaml
    repoURL: git@github.com:<your GitHub username>/cicd-argocd-gitops-demo-private.git
    targetRevision: HEAD
    path: example3-argocd-app-of-apps-private/argocd-app
```

## Methods of communicating with private repositories

There are several method for communicating with private repositories...

- personal logins
- GitHub apps
- ssh private keys

## Create SSH private keys for user with GitHub

We will create ssh private keys as this seems generally the best option. Output them in your own home directory's '~/.ssh/' directory...

```bash
ssh-keygen -t ed25519 -C "<this is a comment ie. argocd_username>" -f ~/.ssh/argocd_ed25519
```

For reference... 'ed25519' is a relatively new solution implementing Edwards-curve Digital Signature Algorithm (EdDSA). 

Compared to the most common type of SSH key – RSA – ed25519 brings a number of cool improvements:

- it’s faster: to generate and to verify
- it’s more secure
- collision resilience – this means that it’s more resilient against hash-function collision attacks (types of attacks where large numbers of keys are generated with the hope of getting two different keys have matching hashes)
- keys are smaller – this, for instance, means that it’s easier to transfer and to copy/paste them

RSA keys are still an option if using Windows or older systems...

```bash
ssh-keygen -t rsa -b 4096 -C "<this is a comment ie. argocd_username>" -f ~/.ssh/argocd_rsa
```

## Upload the ssh public key to GitHub directly to the private repository

Give access to only your private GitHub repo using this key.<br>

__A NOTE ABOUT KEY SECURITY__: The public/private key combination we have created will only be used for access to our private GitHub repo. We will deploy the public key to our GitHub repo's settings, and we will create a 'secret.yaml' file to configure the secret within Kubernetes to contain the private key. Under most circumstances it would be a security violation to store a private ssh key in any files uploaded to a GitHub repo. However, in this case the configuration file is located within the private repo accessible by the key itself, and this is the only repo usable with this private key. <br>

If on MacOS...

```bash
cat ~/.ssh/argocd_ed25519.pub | pbcopy
```

- Navigate to your private repo page on GitHub.com
- Click 'Settings'
- then 'Deploy keys' from the left column menu
- Click 'add deploy key'
  - Name the key 'argocd' and paste the key
  - There is no reason at this time to check 'Allow write access'
  - Click 'Add key'.

## Create and apply a secret to contain the ssh private key

If on MacOS copy the private key to the clipboard...

```bash
cat ~/.ssh/argocd_ed25519 | pbcopy
```

Create a 'secret.yaml' file to create a secret containing the ssh private key...

```bash
vi example3-argocd-app-of-apps-private/argocd-app/git-repo-secret.yaml
```

... add ...

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-my-apps-private
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: git@github.com:<your GitHub username>/cicd-argocd-gitops-demo-private.git
  sshPrivateKey: |
    < your private key >
  insecure: "false"
  enableLfs: "true"
```
__OPTIONAL__: For security purposes you may wish to store this private ssh key configuration .yaml file outside of your private repo and apply manually.

Deploy the new secret...

```bash
kubectl apply -f example3-argocd-app-of-apps-private/argocd-app/git-repo-secret.yaml
```

Verify the secret was created...

```bash
kubectl get secret -n argocd | grep private
argocd-my-apps-private         Opaque               4      101s
```

Verify the contents of the 'sshPrivateKey' field in the secret...

```bash
kubectl -n argocd get secret argocd-my-apps-private -o jsonpath="{.data.sshPrivateKey}" | base64 -d ; echo -e "\n"
```

## Grant ArgoCD access to Docker Hub

### Generate a Docker Hub read-only token

To grant ArgoCD access to Docker Hub generate a read-only token.

- On the Docker Hub console select 'Account Settings' from your profile drop-down at the top right
- Click 'Security' on the left column
- Click 'New Access Token' within the 'Access Tokens' section
  - Add a description 'Docker Desktop' or 'Minikube'
  - Specify 'Read-only' Access permissions
  - Click 'Generate'
- Copy the token

__IMPORTANT__: You'll definitely want to copy and retain this token, either in a password safe or in some type of local read-only file (ie. your ~/ home directory).

### Create a 'dockerconfigjson' secret in each application namespace

It's not convenient, but, as this token could be used against our Docker Hub for other purposes it is best to create the Kubernetes secret manually via 'kubectl' in all namespaces where it must be used. 

It is kind of a chicken and egg situation. We could have tried to deploy our 'stage' applications which would have created the namespaces, but, that would have error'd out due to access issues with Docker Hub to pull the images. Alternatively, as we have not yet deployed our apps for the first time, we need to pre-create all app namespaces and manually create the secrets...

```bash
kubectl create namespace my-app-one
kubectl create namespace my-app-two
```

```bash
kubectl create secret docker-registry dockerconfigjson -n my-app-one \
--docker-server="https://index.docker.io/v1/" \
--docker-username=<your Docker Hub username> \
--docker-password=<your Docker Hub token> \
--docker-email=<your Docker Hub email>

kubectl create secret docker-registry dockerconfigjson -n my-app-two \
--docker-server="https://index.docker.io/v1/" \
--docker-username=<your Docker Hub username> \
--docker-password=<your Docker Hub token> \
--docker-email=<your Docker Hub email>
```

__NOTE__: The 'docker-registry' parameter specifies a secret type to be used with a Docker registry (as opposed to 'generic').

View the new secrets in .yaml format...

```bash
kubectl get secret -n my-app-one -o yaml dockerconfigjson
kubectl get secret -n my-app-two -o yaml dockerconfigjson
```

View the encoded contents of the new secrets...

```bash
kubectl -n my-app-one get secret dockerconfigjson -o jsonpath="{.data.\.dockerconfigjson}" | base64 -d ; echo -e "\n"
kubectl -n my-app-two get secret dockerconfigjson -o jsonpath="{.data.\.dockerconfigjson}" | base64 -d ; echo -e "\n"
```

## Modify the deployments with the secrets to be used for access to Docker Hub

Next we must modify our '1-deployment.yaml' files in each app sub-directory for access to Docker Hub using our new secret containing the access token.

```bash
vi example3-argocd-app-of-apps-private/my-app-one/1-deployment.yaml
vi example3-argocd-app-of-apps-private/my-app-two/1-deployment.yaml
```

Add the following to the end of the configuration in each file ...

```yaml
      imagePullSecrets:
        - name: dockerconfigjson
```

## Add all files, commit and push

```bash
git add example3-argocd-app-of-apps-private/
git commit -m "example3-argocd-app-of-apps-private"
git push origin main
```

## Deploy our 'stage' environment applications

Finally, we can apply our configs and deploy our applications.

```bash
kubectl apply -f example3-argocd-app-of-apps-private/environments/stage/my-apps-stage.yaml
```

Within the ArgoCD console verify creation, 'Synced', and 'Healthy' status of the 'my-app-stage' GitOps app and the two children apps 'my-app-one' and 'my-app-two'.

Verify the pods are up and running...

```bash
kubectl get pods -n my-app-one
kubectl get pods -n my-app-two
```

## Script to simulate CI/CD application upgrades

If you wish to test simulation of CI/CD upgrades using the ./upgrade.sh script as demonstrated in the last blog, you will need to make some modifications to the 'upgrade.sh' script.

```bash
vi ./example3-argocd-app-of-apps-private/upgrade.sh
```

Modify ...

```bash
image_owner="<your Docker Hub username>"
image_base="nginx-private"
image_base_tag="v0.1.0"
git_repo_url="git@github.com:<your GitHub username>/cicd-argocd-gitops-demo-private.git"
base_folder="example3-argocd-app-of-apps-private"
...
docker tag ${image_owner}/${image_base}:${image_base_tag} ${image_owner}/${image_base}:${new_ver}
```

Commit the changes...

```bash
git add ./example3-argocd-app-of-apps-private/upgrade.sh
git commit -m "upgrade.sh fix"
git push origin main
```

## Simulate a CI/CD upgrade

Execute...

```bash
./example3-argocd-app-of-apps-private/upgrade.sh "v0.1.1"
```

Observe script output. If all goes well you should see...

```
[main 872ebcc] Update image to v0.1.1
 2 files changed, 2 insertions(+), 2 deletions(-)
```

Either wait a few minutes or click 'Refresh' in the ArgoCD console. You should see the latest commit message and status green.

Verify the Kubernetes pods...

```bash
kubectl get pods -n my-app-one
kubectl get pods -n my-app-two
```

```bash
kubectl describe pod -n my-app-one {pod_name} | grep Image:
kubectl describe pod -n my-app-two {pod_name} | grep Image:
```

## Cleanup

Execute 'upgrade.sh' with version 'v0.1.0' to return the repo to its original state...

```bash
./example3-argocd-app-of-apps-private/upgrade.sh "v0.1.0"
```

Then to delete the entire configuration execute...

```bash
kubectl delete -f ./example3-argocd-app-of-apps-private/environments/stage/my-apps-stage.yaml 
```

You'll see the applications deleted from the ArgoCD console and all Kubernetes objects in the 'my-app-one' and 'my-app-two' namespaces will be removed as well as the namespaces themselves...

```bash
kubectl get namespaces
```

__NOTE__: The secrets containing the Docker Hub tokens will also be deleted so make sure and save the token.

That's it!