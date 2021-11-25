#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CI="${CI:-false}"
set -o errexit
set -o nounset
set -o pipefail

readonly CT_VERSION=latest
readonly KIND_VERSION=v0.11.1
readonly K8S_VERSION=v1.21.2

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

    node_count=$(kind get nodes --name "$CLUSTER_NAME" -q | wc -l)

    export KUBECONFIG=/tmp/kind_kube_config$$
    if [ "$node_count" -eq 0 ]; then
        kind create cluster --name "$CLUSTER_NAME" --config tests/kind-config.yaml --image "kindest/node:$K8S_VERSION" --wait 60s
        pull_and_cache_docker_images
    else
        kind export kubeconfig --name "$CLUSTER_NAME"
    fi
    docker_exec mkdir -p /root/.kube

    echo "Copying kubeconfig $KUBECONFIG to container..."
    docker cp "$KUBECONFIG" ct:/root/.kube/config

    docker_exec kubectl cluster-info
    echo

    docker_exec kubectl get nodes
    echo

    echo 'Cluster ready!'
    echo

    if [ "$node_count" -eq 0 ]; then
        echo 'Setup metallb in k8s'
        setup_load_balancer
    fi
}


install_charts() {
    docker_exec ct install --debug --config tests/ct.yaml --helm-extra-args "--debug"
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


setup_load_balancer() {
    # resource that use a load balancer will be in pending state forever and 
    # "helm install --wait" will never finish unless a loadbalancer is configured in the cluster

    # https://kind.sigs.k8s.io/docs/user/loadbalancer/
    docker_exec kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
    docker_exec kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
    docker_exec kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
    docker_exec kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/metallb-configmap.yaml
}


main() {
    run_ct_container
    trap cleanup EXIT

    create_kind_cluster
    install_charts
}

main
