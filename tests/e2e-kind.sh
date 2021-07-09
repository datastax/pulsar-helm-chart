#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

set -o errexit
set -o nounset
set -o pipefail

readonly CT_VERSION=latest
readonly KIND_VERSION=v0.11.1
readonly K8S_VERSION=v1.18.19

readonly CLUSTER_NAME=pulsar-helm-test

run_ct_container() {
    if [ "$(docker inspect -f '{{.State.Running}}' ct 2>/dev/null || true)" != 'true' ]; then
        echo 'Running ct container...'
        docker run --rm --interactive --detach --network host --name ct \
            --volume "$(pwd):/workdir" \
            --workdir /workdir \
            "quay.io/helmpack/chart-testing:$CT_VERSION" \
            cat
        echo
    fi
}

cleanup() {
    echo 'Removing ct container...'
    docker kill ct > /dev/null 2>&1

    echo 'Done!'
}

docker_exec() {
    docker exec --interactive ct "$@"
}

create_kind_cluster() {
    if ! [ -x "$(command -v kind)" ]; then
        echo 'Installing kind...'
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64
        chmod +x ./kind
        sudo mv kind /usr/local/bin/kind
    fi

    local no_cluster=0
    kind get nodes --name "$CLUSTER_NAME" >/dev/null 2>&1 || no_cluster=1

    if [ $no_cluster -eq 1 ]; then
        export KUBECONFIG=/tmp/kind_kube_config$$
        kind create cluster --name "$CLUSTER_NAME" --config tests/kind-config.yaml --image "kindest/node:$K8S_VERSION" --wait 60s
        pull_and_cache_docker_images

        docker_exec mkdir -p /root/.kube

        echo "Copying kubeconfig $KUBECONFIG to container..."
        docker cp "$KUBECONFIG" ct:/root/.kube/config

        docker_exec kubectl cluster-info
        echo

        docker_exec kubectl get nodes
        echo

        echo 'Cluster ready!'
        echo
    fi
}


install_charts() {
    docker_exec ct install --debug --config tests/ct.yaml --helm-extra-args "--debug"
    echo
}

pull_and_cache_docker_images() {
    if ! [ -x "$(command -v yq)" ]; then
        echo 'Installing yq...'
        curl -Lo ./yq https://github.com/mikefarah/yq/releases/download/v4.9.8/yq_linux_amd64
        chmod +x ./yq
        sudo mv yq /usr/local/bin/
    fi

    # extract the images from values.yaml
    images=$(yq e '.image | .[] |= ([.repository, .tag] | join(":")) | to_entries | .[] | .value' "$SCRIPT_DIR"/../helm-chart-sources/pulsar/values.yaml | sort | uniq)
    for image in $images; do
        docker pull "$image"
        kind load docker-image --name "$CLUSTER_NAME" "$image"
    done
}

main() {
    run_ct_container
    trap cleanup EXIT

    create_kind_cluster
    install_charts
}

main
