#!/bin/bash
# Script to automate node draining with RKE/k3s

sherlock() {

  if [ -n "${RUNTIME_FLAG}" ]
    then
      echo "Setting container runtime as ${RUNTIME_FLAG}"
      RUNTIME="${RUNTIME_FLAG}"
    else
      echo -n "Detecting container runtime... "
      if $(command -v docker >/dev/null 2>&1)
        then
          if $(docker ps >/dev/null 2>&1)
            then
              RUNTIME=docker
              echo "docker"
            else
              FOUND="docker "
          fi
      fi
      if $(command -v k3s >/dev/null 2>&1)
        then
          if $(k3s crictl ps >/dev/null 2>&1)
            then
              RUNTIME=k3s
              echo "k3s"
            else
              FOUND+="k3s"
          fi
      fi
      if [ -z "${RUNTIME}" ]
        then
          echo -e "\n couldn't detect container runtime"
          if [ -n "${FOUND}" ]
            then
              echo "Found ${FOUND} but could not execute commands successfully"
          fi
      fi
  fi

}

setup() {

  case "${RUNTIME}" in
    docker)
      KUBECTL_COMMAND="docker exec kubelet kubectl --kubeconfig=/etc/kubernetes/ssl/kubecfg-kube-node.yaml"
      ;;
    k3s)
      KUBECTL_COMMAND="/usr/local/bin/kubectl"
      ;;
  esac

}

node_drain() {

  echo "Finding node name"
  NODE_NAME=$(${KUBECTL_COMMAND} get nodes -l kubernetes.io/hostname=$(hostname -s) -o=jsonpath='{.items[0].metadata.name}')

  echo "Draining node"
  if [ -z "${KUBECTL_COMMAND}" ]
    then
      echo "I need a kubectl command, something went wrong, sorry!"
      exit 1
  fi

  ${KUBECTL_COMMAND} drain ${NODE_NAME} --ignore-daemonsets ${DELETE_LOCAL_DATA} --timeout=100s --force

}

node_delete() {

  echo "Deleting node"
  ${KUBECTL_COMMAND} delete node "${NODE_NAME}"

  sleep 2
  echo "Verifying node is deleted"
  ${KUBECTL_COMMAND} get node "${NODE_NAME}"
  status=$?
  count=0
  while [ "${status}" -eq 0 ]
    do
      sleep 2
      ((count++))
      if [ "${count}" -ge 5 ]
        then
          echo "Node is still in the cluster, using --force and exiting"
          ${KUBECTL_COMMAND} delete node "${NODE_NAME}" --force --grace-period=0
          break
      fi
      ${KUBECTL_COMMAND} get node "${NODE_NAME}"
      status=$?
  done

}

help() {

  echo "node-drain systemd service for RKE and k3s

  Usage: bash node-drain.sh [ -d -n -r <container runtime> ]

    All flags are optional:
    -d    Delete local data, pods using emptyDir volumes will be drained as well
    -n    Delete node as well, useful for immutable infrastructure as nodes are replaced on shutdown
    -r    Override container runtime if not automatically detected (docker|k3s)"

}

# Check if we're running as root.
if [[ $EUID -ne 0 ]]
  then
    echo "This script must be run as root"
    exit 1
fi

while getopts "dhnr:" opt; do
  case $opt in
    d)
      DELETE_LOCAL_DATA="--delete-local-data"
      ;;
    h)
      help; exit 0
      ;;
    n)
      DELETE_NODE="true"
      ;;
    r)
      RUNTIME_FLAG="${OPTARG}"
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
    *)
      help && exit 0
  esac
done

sherlock
setup
node_drain
if [ "${DELETE_NODE}" == "true" ]
  then
    node_delete
fi