#!/bin/sh

usage() { echo "Usage: $0 [-k /path/to/kubectl] [-c kubeconfig.yml] <[-ud]> -r <k8s deployment resource> -n <k8s namespace> [-a <max scale>] [-i <min scale>] [-f <scaling factor>]" 1>&2; exit 1; }

while getopts ":k:c:udr:n:a:i:f:" o; do
    case "${o}" in
        k)
            KUBECTL=${OPTARG}
            [ -f $KUBECTL ] || (echo "$KUBECTL not executable!" && usage)
            ;;
        c)
            KUBECONFIG=${OPTARG}
            [ -f $KUBECONFIG ] || (echo "$KUBECONFIG file not found!" && usage)
            ;;
        u)
            SCALE="+"
            ;;
        d)
            SCALE="-"
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
        f)
            SCALING_FACTOR=${OPTARG}
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
[ -z $SCALING_FACTOR ] && SCALING_FACTOR=1

KUBECTL=${KUBECTL:-/opt/rules/kubectl/kubectl}
K8S_RESOURCE_TYPE=${RESOURCE%/*}

# Append config if necessary
[ -n $KUBECONFIG ] && KUBECTL="$KUBECTL --kubeconfig $KUBECONFIG"

CURRENT_SCALE=$($KUBECTL \
                --namespace=${NAMESPACE} \
                get ${K8S_RESOURCE_TYPE} \
                -o go-template='{{(index .items 0).spec.replicas}}')

# Check if scaling factor will cross min/max
if [ "$SCALE" = "+" ] && [ $CURRENT_SCALE -lt $MAX_SCALE ] && [ $(expr $CURRENT_SCALE + ${SCALING_FACTOR}) -gt $MAX_SCALE ]; then
  SCALING_FACTOR=$(expr $MAX_SCALE - $CURRENT_SCALE)
fi

if [ "$SCALE" = "-" ] && [ $CURRENT_SCALE -gt $MIN_SCALE ] && [ $(expr $CURRENT_SCALE - ${SCALING_FACTOR}) -lt $MIN_SCALE ]; then
  SCALING_FACTOR=$(expr $CURRENT_SCALE - $MIN_SCALE)
fi

SCALE="${SCALE} ${SCALING_FACTOR}"

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
