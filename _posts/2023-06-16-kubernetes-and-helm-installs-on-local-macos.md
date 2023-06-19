---
title: Install Kubernetes and Helm Locally on MacOS
date: 2023-06-16 12:00:00 -0500
categories: [How-to, Kubernetes]
tags: [kubernetes,terraform,helm]     # TAG names should always be lowercase
---

It is both extremely convenient to develop and test Kubernetes clusters and helm charts locally on MacOS, and helpful to access cloud-based Kubernetes orchestrations via local 'kubectl'.

There are two primary methods of installing/deploying Kubernetes locally on MacOS...

- Kubernetes built into Docker Desktop
- Minikube

Both methods deploy a single node for both user and system deployments. Both 'un-taint' the 'system' node so that Kubernetes does not prevent this single node from launching additional user defined pods. Minikube provides a lot more configuration options including the option of deploying the system node on a VirtualBox VM in addition to a Docker container.

We will explore both methods of installation.

Helm installed locally is also very helpful to deploy and test various Helm Charts.

## Kubernetes Installation via Docker Desktop

Installing Kubernetes included with Docker Desktop and via its interface is extremely simple...

- Click the 'Settings' gear icon in the upper right of the Docker Desktop primary window
- Select 'Kubernetes'
- Check 'Enable Kubernetes'
- Select 'Apply & Restart' to save the settings
- Click 'Install' to confirm

This instantiates images required to run the Kubernetes server as containers, and installs the /usr/local/bin/kubectl command on your machine.

When Kubernetes is enabled and running, an additional status bar in the Dashboard footer and Docker menu displays.

To uninstall simply...

- Un-check 'Enable Kubernetes'

Here are links to Docker Desktop [documentation](https://docs.docker.com/desktop/kubernetes/) and [workings](https://www.docker.com/blog/how-kubernetes-works-under-the-hood-with-docker-desktop/) of Kubernetes built into Docker Desktop.

## Kubernetes Installation via MiniKube

Minikube essentially provides the same local Kubernetes cluster capabilities as that provided by Docker Desktop, albeit, with a lot more configuration options. Here is a link to the [MiniKube documentation](https://minikube.sigs.k8s.io/docs/).

This [link](https://minikube.sigs.k8s.io/docs/start/) provides full documentation on MiniKube installation on MacOS. Essentially, execute the following...

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

Even simpler is to install MiniKube via [Homebrew](https://formulae.brew.sh/formula/minikube)...
```bash
brew install minikube
```

Simple command to start the local Kubernetes cluster...

```bash
minikube start
```

Review the output and confirm the version of Kubernetes installed (usually latest). 

A couple of options can be passed to the 'minikube start' command to be explicit about your configuration...

- Specify a specific version
- Direct Kubernetes to utilize a Docker container (vs. VirtualBox VM) for its single node

```bash
minikube start --kubernetes-version=v1.26.1 --driver=docker
```

This will download a Docker container image for your Kubernetes node, bootstrap a cluster configuration, and configure 'kubectl' communication with the new cluster.

```bash
kubectl get nodes
```

This single node is the 'control-plane', however, Minikube automatically un-'Taints' it so that you can run application pods on the same node.

```bash
kubectl describe node <node-name ie. 'minikube'>
```

## Helm installation

Per the Helm [documentation](https://helm.sh/docs/intro/install/) the simplest method to install Helm on MacOS is via Homebrew...

```bash
brew install helm
```

The [documentation](https://helm.sh/docs/intro/install/) also provides instructions for installation from source.

