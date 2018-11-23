[![Travis CI](https://travis-ci.org/cndjp/qicoo-api-manifests.svg?branch=master)](https://travis-ci.org/cndjp/qicoo-api-manifests)

# はじめに
このRepositoryは、QicooのKubernetesマニフェストファイルを管理しています。


# 構成の使い分け
（productionでElastiCacheとRDSを使うところは未実装です）

名前|用途|namespace名|APIの公開|データストア
-|-|-|-|-
base|ローカル開発環境|qicoo|NodePort|Redis/MySQLのコンテナ
development|EKS上の開発環境|development|LoadBalancer|Redis/MySQLのコンテナ
staging|EKS上のステージング環境|staging|LoadBalancer|Redis/MySQLのコンテナ
production|EKS上の本番環境|production|LoadBalancer|ElastiCacheとRDS


# How to run qicoo API server in local Kubernetes cluster

## Install Kustomize
(For Linux amd64)

    wget https://github.com/kubernetes-sigs/kustomize/releases/download/v1.0.8/kustomize_1.0.8_linux_amd64
    chmod +x kustomize_1.0.8_linux_amd64
    sudo mv kustomize_1.0.8_linux_amd64 /usr/local/bin/kustomize

## Clone manifests and build Kustomized one

    git clone https://github.com/cndjp/qicoo-api-manifests.git
    cd qicoo-api-manifests
    kustomize build ./base -o ./base/qicoo-api-all.yaml

## Apply the Kustomized manifest

    kubectl apply -f ./base/qicoo-api-all.yaml
