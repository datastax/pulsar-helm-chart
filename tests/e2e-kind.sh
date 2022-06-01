#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CI="${CI:-false}"
set -o errexit
set -o nounset
set -o pipefail

readonly CT_VERSION=latest
readonly KIND_VERSION=v0.11.1
: "${K8S_VERSION:=v1.21.2}"

readonly CLUSTER_NAME=pulsar-helm-test

run_ct_container() {
    if [ "$(docker inspect -f '{{.State.Running}}' ct 2>/dev/null || true)" != 'true' ]; then
        echo 'Running ct container...'
        docker run --rm --interactive --detach --network host --name ct \
            --volume "$(pwd):/workdir" \
            --workdir /workdir \
            --user 1000 \
            --env HOME=/workdir \
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

# Set the user so that it properly owns the git repo
docker_exec() {
    docker exec --user 1000 --interactive ct "$@"
}

create_kind_cluster() {
    if ! [ -x "$(command -v kind)" ]; then
        echo 'Installing kind...'
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64
        chmod +x ./kind
        sudo mv kind /usr/local/bin/kind
    fi

    node_count=$(kind get nodes --name "$CLUSTER_NAME" -q | wc -l)

    export KUBECONFIG=/tmp/kind_kube_config$$
    if [ "$node_count" -eq 0 ]; then
        kind create cluster --name "$CLUSTER_NAME" --config tests/kind-config.yaml --image "kindest/node:$K8S_VERSION" --wait 60s
        # caching docker images is useful only when there are multiple workers or when running outside of CI
        local worker_count
        worker_count=$(kind get nodes --name "$CLUSTER_NAME" -q | grep -c worker)
        if [[ $CI == "false" || $worker_count -gt 1 ]]; then
            pull_and_cache_docker_images
        fi
    else
        kind export kubeconfig --name "$CLUSTER_NAME"
    fi
    docker_exec mkdir -p /workdir/.kube

    echo "Copying kubeconfig $KUBECONFIG to container..."
    docker cp "$KUBECONFIG" ct:/workdir/.kube/config

    docker_exec kubectl cluster-info
    echo

    docker_exec kubectl get nodes
    echo

    echo 'Cluster ready!'
    echo
}


install_charts() {
    docker_exec ct install --debug --config tests/ct.yaml
    echo
}

pull_and_cache_docker_images() {
    if [[ $CI == "true" ]]; then
        echo 'Installing yq...'
        curl -Lo ./yq https://github.com/mikefarah/yq/releases/download/v4.9.8/yq_linux_amd64
        chmod +x ./yq
        sudo mv yq /usr/local/bin/
    fi
    echo 'Printing yq version'
    yq --version

    # kind cluster worker nodes as comma separated list
    nodes=$(kind get nodes --name "$CLUSTER_NAME" -q | grep worker | tr '\n' ',' | sed 's/,$//')

    # extract the images from values.yaml
    images=$(yq e '.image | .[] |= ([.repository, .tag] | join(":")) | to_entries | .[] | .value' "$SCRIPT_DIR"/../helm-chart-sources/pulsar/values.yaml | sort | uniq)
    for image in $images; do
        docker pull "$image"
        kind load docker-image -v 1 --name "$CLUSTER_NAME" --nodes "$nodes" "$image"
    done
}

main() {
    run_ct_container
    trap cleanup EXIT

    create_kind_cluster
    install_charts
}

main
