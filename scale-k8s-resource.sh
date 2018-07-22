#!/bin/sh

usage() { echo "Usage: $0 [-k /path/to/kubectl] [-c kubeconfig.yml] <[-ud]> -r <k8s deployment resource> -n <k8s namespace> [-a <max scale>] [-i <min scale>]" 1>&2; exit 1; }

while getopts ":k:c:udr:n:a:i:" o; do
    case "${o}" in
        k)
            KUBECTL=${OPTARG}
            [[ -x $KUBECTL ]] || (echo "$KUBECTL not executable!" && usage)
            ;;
        c)
            KUBECONFIG=${OPTARG}
            [[ -f $KUBECTL ]] || (echo "$KUBECONFIG file not found!" && usage)
            ;;
        u)
            SCALE="+ 1"
            ;;
        d)
            SCALE="- 1"
            ;;
        r)
            RESOURCE=${OPTARG}
            ;;
        n)
            NAMESPACE=${OPTARG}
            ;;
        a)
            MAX_SCALE=${OPTARG}
            ;;
        i)
            MIN_SCALE=${OPTARG}
            ;;
        *)
            echo "Invalid parameter"
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${SCALE}" ] || \
   [ -z "${RESOURCE}" ] || \
   [ -z "${NAMESPACE}" ] ; then
    echo "Detected missing parameters"
    usage
fi

[ -z $MAX_SCALE ] && MAX_SCALE=99
[ -z $MIN_SCALE ] && MIN_SCALE=0

KUBECTL=${KUBECTL:-/opt/rules/kubectl/kubectl}
K8S_RESOURCE_TYPE=${RESOURCE%/*}

# Append config if necessary
[ -n $KUBECONFIG ] && KUBECTL="$KUBECTL --kubeconfig $KUBECONFIG"

CURRENT_SCALE=$($KUBECTL \
                --namespace=${NAMESPACE} \
                get ${K8S_RESOURCE_TYPE} \
                -o go-template='{{(index .items 0).spec.replicas}}')

if [ $(expr $CURRENT_SCALE ${SCALE}) -le $MAX_SCALE ] && [ $(expr $CURRENT_SCALE ${SCALE}) -ge $MIN_SCALE ]; then
  echo "Scaling $SCALE, current scale: $CURRENT_SCALE, min: $MIN_SCALE, max: $MAX_SCALE"
  $KUBECTL \
    --namespace=${NAMESPACE} \
    scale \
    ${RESOURCE} \
    --replicas=$(expr $CURRENT_SCALE ${SCALE})
else
  echo "Not scaling due to min/max constraints, current scale: $CURRENT_SCALE, min: $MIN_SCALE, max: $MAX_SCALE"
fi
