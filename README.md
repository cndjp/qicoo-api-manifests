# はじめに
このRepositoryは、QicooのKubernetesマニフェストファイルを管理しています。

# How to run qicoo API server in local Kubernetes cluster

## Install Kustomize
(For Linux amd64)

    wget https://github.com/kubernetes-sigs/kustomize/releases/download/v1.0.8/kustomize_1.0.8_linux_amd64
    chmod +x ./chmod +x kustomize_1.0.8_linux_amd64
    sudo mv kustomize_1.0.8_linux_amd64 /usr/local/bin/kustomize

## Clone manifests and build Kustomized one

    git clone https://github.com/cndjp/qicoo-api-manifests.git
    cd qicoo-api-manifests
    kustomize build ./base -o ./base/qicoo-api-all.yaml

## One more preparation... and apply the Kustomized manifest

    kubectl create namespace qicoo
    kubectl apply -f ./base/qicoo-api-all.yaml