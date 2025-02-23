#!/bin/bash

#
# Default values (possible to override)
#

FT_REQ_REMOTE_CLIENT_NODE=${FT_REQ_REMOTE_CLIENT_NODE:-all}
FT_REQ_SERVER_NODE=${FT_REQ_SERVER_NODE:-all}
FT_SRIOV_NODE_LABEL=${FT_SRIOV_NODE_LABEL:-network.operator.openshift.io/external-openvswitch}

# Deployment Variations
FT_HOSTONLY=${FT_HOSTONLY:-unknown}
FT_NAMESPACE=${FT_NAMESPACE:-default}
# Multi-Cluster Control
FT_CLIENTONLY=${FT_CLIENTONLY:-unknown}
FT_EXPORT_SVC=${FT_EXPORT_SVC:-false}
FT_SVC_QUALIFIER=${FT_SVC_QUALIFIER:-}


# Launch specific variables
NET_ATTACH_DEF_NAME=${NET_ATTACH_DEF_NAME:-ftnetattach}
SRIOV_RESOURCE_NAME=${SRIOV_RESOURCE_NAME:-openshift.io/mlnx_bf}
TEST_IMAGE=${TEST_IMAGE:-quay.io/billy99/ft-base-image:0.7}


# Clean specific variables
CLEAN_ALL=${CLEAN_ALL:-false}


# Test specific variables
TEST_CASE=${TEST_CASE:-0}
VERBOSE=${VERBOSE:-false}
FT_VARS=${FT_VARS:-false}
FT_NOTES=${FT_NOTES:-true}
# curl Control
CURL=${CURL:-true}
CURL_CMD=${CURL_CMD:-curl -m 5}
# iPerf Control
IPERF=${IPERF:-false}
IPERF_CMD=${IPERF_CMD:-iperf3}
IPERF_TIME=${IPERF_TIME:-10}
# Trace Control
OVN_TRACE=${OVN_TRACE:-false}
OVN_TRACE_CMD=${OVN_TRACE_CMD:-./ovnkube-trace -loglevel=5 -tcp}
OVN_K_NAMESPACE=${OVN_K_NAMESPACE:-"ovn-kubernetes"}
SSL_ENABLE=${SSL_ENABLE:-"-noSSL"}
# External Access
EXTERNAL_IP=${EXTERNAL_IP:-8.8.8.8}
EXTERNAL_URL=${EXTERNAL_URL:-google.com}


# From YAML Files
CLIENT_POD_NAME_PREFIX=${CLIENT_POD_NAME_PREFIX:-ft-client-pod}
CLIENT_HOST_POD_NAME_PREFIX=${CLIENT_HOST_POD_NAME_PREFIX:-ft-client-pod-host}


HTTP_SERVER_POD_NAME=${HTTP_SERVER_POD_NAME:-ft-http-server-pod-v4}
HTTP_SERVER_HOST_POD_NAME=${HTTP_SERVER_HOST_POD_NAME:-ft-http-server-host-v4}

HTTP_CLUSTERIP_POD_SVC_NAME=${HTTP_CLUSTERIP_POD_SVC_NAME:-ft-http-service-clusterip-pod-v4}
HTTP_CLUSTERIP_HOST_SVC_NAME=${HTTP_CLUSTERIP_HOST_SVC_NAME:-ft-http-service-clusterip-host-v4}

HTTP_NODEPORT_SVC_NAME=${HTTP_NODEPORT_SVC_NAME:-ft-http-service-nodeport-pod-v4}
HTTP_NODEPORT_HOST_SVC_NAME=${HTTP_NODEPORT_HOST_SVC_NAME:-ft-http-service-nodeport-host-v4}

HTTP_CLUSTERIP_POD_SVC_PORT=${HTTP_CLUSTERIP_POD_SVC_PORT:-8080}
HTTP_CLUSTERIP_HOST_SVC_PORT=${HTTP_CLUSTERIP_HOST_SVC_PORT:-8081}

HTTP_NODEPORT_POD_SVC_PORT=${HTTP_NODEPORT_POD_SVC_PORT:-30080}
HTTP_NODEPORT_HOST_SVC_PORT=${HTTP_NODEPORT_HOST_SVC_PORT:-30081}


HTTP_CLUSTERIP_KUBEAPI_SVC_NAME=${HTTP_CLUSTERIP_KUBEAPI_SVC_NAME:-kubernetes.default.svc}
HTTP_CLUSTERIP_KUBEAPI_SVC_PORT=${HTTP_CLUSTERIP_KUBEAPI_SVC_PORT:-443}
HTTP_CLUSTERIP_KUBEAPI_EP_PORT=${HTTP_CLUSTERIP_KUBEAPI_EP_PORT:-6443}


IPERF_SERVER_POD_NAME=${IPERF_SERVER_POD_NAME:-ft-iperf-server-pod-v4}
IPERF_SERVER_HOST_POD_NAME=${IPERF_SERVER_HOST_POD_NAME:-ft-iperf-server-host-v4}

IPERF_CLUSTERIP_POD_SVC_NAME=${IPERF_CLUSTERIP_POD_SVC_NAME:-ft-iperf-service-clusterip-pod-v4}
IPERF_CLUSTERIP_HOST_SVC_NAME=${IPERF_CLUSTERIP_HOST_SVC_NAME:-ft-iperf-service-clusterip-host-v4}

IPERF_NODEPORT_POD_SVC_NAME=${IPERF_NODEPORT_POD_SVC_NAME:-ft-iperf-service-nodeport-pod-v4}
IPERF_NODEPORT_HOST_SVC_NAME=${IPERF_NODEPORT_HOST_SVC_NAME:-ft-iperf-service-nodeport-host-v4}

IPERF_CLUSTERIP_POD_SVC_PORT=${IPERF_CLUSTERIP_POD_SVC_PORT:-5201}
IPERF_CLUSTERIP_HOST_SVC_PORT=${IPERF_CLUSTERIP_HOST_SVC_PORT:-5202}

IPERF_NODEPORT_POD_SVC_PORT=${IPERF_NODEPORT_POD_SVC_PORT:-30201}
IPERF_NODEPORT_HOST_SVC_PORT=${IPERF_NODEPORT_HOST_SVC_PORT:-30202}


POD_SERVER_STRING=${POD_SERVER_STRING:-"Server - Pod Backend Reached"}
HOST_SERVER_STRING=${HOST_SERVER_STRING:-"Server - Host Backend Reached"}
EXTERNAL_SERVER_STRING=${EXTERNAL_SERVER_STRING:-"The document has moved"}
KUBEAPI_SERVER_STRING=${KUBEAPI_SERVER_STRING:-"serverAddressByClientCIDRs"}


# Local Variables not intended to be overwritten
LOCAL_CLIENT_NODE=
LOCAL_CLIENT_POD=
REMOTE_CLIENT_NODE=
REMOTE_CLIENT_POD=

FT_SERVER_NODE_LABEL=ft.ServerPod
FT_CLIENT_NODE_LABEL=ft.ClientPod

dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Launch Control:"
  echo "    FT_HOSTONLY                        $FT_HOSTONLY"
  echo "    FT_CLIENTONLY                      $FT_CLIENTONLY"
  echo "    FT_NAMESPACE                       $FT_NAMESPACE"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_REQ_REMOTE_CLIENT_NODE          $FT_REQ_REMOTE_CLIENT_NODE"
  echo "    FT_SRIOV_NODE_LABEL                $FT_SRIOV_NODE_LABEL"
  echo "    FT_EXPORT_SVC                      $FT_EXPORT_SVC"
if [ ${COMMAND} == "cleanup" ] ; then
  echo "    HTTP_SERVER_POD_NAME               $HTTP_SERVER_POD_NAME"
  echo "    HTTP_SERVER_HOST_POD_NAME          $HTTP_SERVER_HOST_POD_NAME"
  echo "    CLEAN_ALL                          $CLEAN_ALL"
fi
  echo "  Label Management:"
  echo "    FT_SERVER_NODE_LABEL               $FT_SERVER_NODE_LABEL"
  echo "    FT_CLIENT_NODE_LABEL               $FT_CLIENT_NODE_LABEL"
if [ ${COMMAND} == "test" ] ; then
  echo "  Test Control:"
  echo "    TEST_CASE (0 means all)            $TEST_CASE"
  echo "    VERBOSE                            $VERBOSE"
  echo "    FT_VARS                            $FT_VARS"
  echo "    FT_NOTES                           $FT_NOTES"
  echo "    CURL                               $CURL"
  echo "    CURL_CMD                           $CURL_CMD"
  echo "    IPERF                              $IPERF"
  echo "    IPERF_CMD                          $IPERF_CMD"
  echo "    IPERF_TIME                         $IPERF_TIME"
  echo "    OVN_TRACE                          $OVN_TRACE"
  echo "    OVN_TRACE_CMD                      $OVN_TRACE_CMD"
  echo "    FT_SVC_QUALIFIER                   $FT_SVC_QUALIFIER"
  echo "  OVN Trace Control:"
  echo "    OVN_K_NAMESPACE                    $OVN_K_NAMESPACE"
  echo "    SSL_ENABLE                         $SSL_ENABLE"
fi
if [ ${COMMAND} == "launch" ] || [ ${COMMAND} == "test" ] ; then
  echo "  From YAML Files:"
  echo "    NET_ATTACH_DEF_NAME                $NET_ATTACH_DEF_NAME"
  echo "    SRIOV_RESOURCE_NAME                $SRIOV_RESOURCE_NAME"
  echo "    TEST_IMAGE                         $TEST_IMAGE"
  echo "    CLIENT_POD_NAME_PREFIX             $CLIENT_POD_NAME_PREFIX"
  echo "    http Server:"
  echo "      HTTP_SERVER_POD_NAME             $HTTP_SERVER_POD_NAME"
  echo "      HTTP_SERVER_HOST_POD_NAME        $HTTP_SERVER_HOST_POD_NAME"
  echo "      HTTP_CLUSTERIP_POD_SVC_NAME      $HTTP_CLUSTERIP_POD_SVC_NAME"
  echo "      HTTP_CLUSTERIP_POD_SVC_PORT      $HTTP_CLUSTERIP_POD_SVC_PORT"
  echo "      HTTP_CLUSTERIP_HOST_SVC_NAME     $HTTP_CLUSTERIP_HOST_SVC_NAME"
  echo "      HTTP_CLUSTERIP_HOST_SVC_PORT     $HTTP_CLUSTERIP_HOST_SVC_PORT"
  echo "      HTTP_NODEPORT_SVC_NAME           $HTTP_NODEPORT_SVC_NAME"
  echo "      HTTP_NODEPORT_POD_SVC_PORT       $HTTP_NODEPORT_POD_SVC_PORT"
  echo "      HTTP_NODEPORT_HOST_SVC_NAME      $HTTP_NODEPORT_HOST_SVC_NAME"
  echo "      HTTP_NODEPORT_HOST_SVC_PORT      $HTTP_NODEPORT_HOST_SVC_PORT"
  echo "    iperf Server:"
  echo "      IPERF_SERVER_POD_NAME            $IPERF_SERVER_POD_NAME"
  echo "      IPERF_SERVER_HOST_POD_NAME       $IPERF_SERVER_HOST_POD_NAME"
  echo "      IPERF_CLUSTERIP_POD_SVC_NAME     $IPERF_CLUSTERIP_POD_SVC_NAME"
  echo "      IPERF_CLUSTERIP_POD_SVC_PORT     $IPERF_CLUSTERIP_POD_SVC_PORT"
  echo "      IPERF_CLUSTERIP_HOST_SVC_NAME    $IPERF_CLUSTERIP_HOST_SVC_NAME"
  echo "      IPERF_CLUSTERIP_HOST_SVC_PORT    $IPERF_CLUSTERIP_HOST_SVC_PORT"
  echo "      IPERF_NODEPORT_POD_SVC_NAME      $IPERF_NODEPORT_POD_SVC_NAME"
  echo "      IPERF_NODEPORT_POD_SVC_PORT      $IPERF_NODEPORT_POD_SVC_PORT"
  echo "      IPERF_NODEPORT_HOST_SVC_NAME     $IPERF_NODEPORT_HOST_SVC_NAME"
  echo "      IPERF_NODEPORT_HOST_SVC_PORT     $IPERF_NODEPORT_HOST_SVC_PORT"
fi
if [ ${COMMAND} == "test" ] ; then
  echo "    POD_SERVER_STRING                  $POD_SERVER_STRING"
  echo "    HOST_SERVER_STRING                 $HOST_SERVER_STRING"
  echo "    EXTERNAL_SERVER_STRING             $EXTERNAL_SERVER_STRING"
  echo "    KUBEAPI_SERVER_STRING              $KUBEAPI_SERVER_STRING"
  echo "  External Access:"
  echo "    EXTERNAL_IP                        $EXTERNAL_IP"
  echo "    EXTERNAL_URL                       $EXTERNAL_URL"
  echo "Queried Values:"
  echo "  Pod Backed:"
  echo "    HTTP_SERVER_POD_IP                 $HTTP_SERVER_POD_IP"
  echo "    IPERF_SERVER_POD_IP                $IPERF_SERVER_POD_IP"
  echo "    SERVER_POD_NODE                    $SERVER_POD_NODE"
  echo "    LOCAL_CLIENT_NODE                  $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_POD                   $LOCAL_CLIENT_POD"
  echo "    REMOTE_CLIENT_NODE                 $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_POD                  $REMOTE_CLIENT_POD"
  echo "    HTTP_CLUSTERIP_POD_SVC_IPV4        $HTTP_CLUSTERIP_POD_SVC_IPV4"
  echo "    HTTP_CLUSTERIP_POD_SVC_PORT        $HTTP_CLUSTERIP_POD_SVC_PORT"
  echo "    HTTP_NODEPORT_POD_SVC_IPV4         $HTTP_NODEPORT_POD_SVC_IPV4"
  echo "    HTTP_NODEPORT_POD_SVC_PORT         $HTTP_NODEPORT_POD_SVC_PORT"
  echo "    IPERF_CLUSTERIP_POD_SVC_IPV4       $IPERF_CLUSTERIP_POD_SVC_IPV4"
  echo "    IPERF_CLUSTERIP_POD_SVC_PORT       $IPERF_CLUSTERIP_POD_SVC_PORT"
  echo "    IPERF_NODEPORT_POD_SVC_IPV4        $IPERF_NODEPORT_POD_SVC_IPV4"
  echo "    IPERF_NODEPORT_POD_SVC_PORT        $IPERF_NODEPORT_POD_SVC_PORT"
  echo "  Host backed:"
  echo "    HTTP_SERVER_HOST_IP                $HTTP_SERVER_HOST_IP"
  echo "    IPERF_SERVER_HOST_IP               $IPERF_SERVER_HOST_IP"
  echo "    SERVER_HOST_NODE                   $SERVER_POD_NODE"
  echo "    LOCAL_CLIENT_HOST_NODE             $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_HOST_POD              $LOCAL_CLIENT_HOST_POD"
  echo "    REMOTE_CLIENT_HOST_NODE            $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_HOST_POD             $REMOTE_CLIENT_HOST_POD"
  echo "    HTTP_CLUSTERIP_HOST_SVC_IPV4       $HTTP_CLUSTERIP_HOST_SVC_IPV4"
  echo "    HTTP_CLUSTERIP_HOST_SVC_PORT       $HTTP_CLUSTERIP_HOST_SVC_PORT"
  echo "    HTTP_NODEPORT_HOST_SVC_IPV4        $HTTP_NODEPORT_HOST_SVC_IPV4"
  echo "    HTTP_NODEPORT_HOST_SVC_PORT        $HTTP_NODEPORT_HOST_SVC_PORT"
  echo "    IPERF_CLUSTERIP_HOST_SVC_IPV4      $IPERF_CLUSTERIP_HOST_SVC_IPV4"
  echo "    IPERF_CLUSTERIP_HOST_SVC_PORT      $IPERF_CLUSTERIP_HOST_SVC_PORT"
  echo "    IPERF_NODEPORT_HOST_SVC_IPV4       $IPERF_NODEPORT_HOST_SVC_IPV4"
  echo "    IPERF_NODEPORT_HOST_SVC_PORT       $IPERF_NODEPORT_HOST_SVC_PORT"
  echo "  Kubernetes API:"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4    $HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_PORT    $HTTP_CLUSTERIP_KUBEAPI_SVC_PORT"
  echo "    HTTP_CLUSTERIP_KUBEAPI_EP_IP       $HTTP_CLUSTERIP_KUBEAPI_EP_IP"
  echo "    HTTP_CLUSTERIP_KUBEAPI_EP_PORT     $HTTP_CLUSTERIP_KUBEAPI_EP_PORT"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_NAME    $HTTP_CLUSTERIP_KUBEAPI_SVC_NAME"
fi
  echo
}


# Test for '--help'
process-help() {
  if [ ! -z "$1" ] ; then
    if [ "$1" == help ] || [ "$1" == "--help" ] ; then
      echo
      echo "This script uses ENV Variables to control test. Here are few key ones:"
      if [ ${COMMAND} == "launch" ] ; then
      echo "  FT_REQ_SERVER_NODE         - Node to run server pods on. Must be set before launching"
      echo "                               pods. Example:"
      echo "                                 FT_REQ_SERVER_NODE=ovn-worker3 ./launch.sh"
      echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
      echo "                               from server. Example:"
      echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"
      echo "  FT_SRIOV_NODE_LABEL        - SR-IOV is not easy to detect. If Server or Client pods need"
      echo "                               SR-IOV VFs to work, add a label to each node supporting SR-IOV"
      echo "                               and provide the label here. Default value is what is used"
      echo "                               by OpenShift to mark a SmartNIC."
      echo "                               Default: network.operator.openshift.io/external-openvswitch"
      echo "                               Example:"
      echo "                                 FT_SRIOV_NODE_LABEL=sriov-node ./launch.sh"
      echo "  SRIOV_RESOURCE_NAME        - launch.sh does not touch SR-IOV Device Plugin. If a node supports"
      echo "                               SR-IOV VFs, use this field to pass in the \"resourceName\" to be"
      echo "                               used in the NetworkAttachmentDefinition. Default: openshift.io/mlnx_bf"
      echo "                               Example:"
      echo "                                 SRIOV_RESOURCE_NAME=sriov_a ./launch.sh"
      fi
      if [ ${COMMAND} == "launch" ] || [ ${COMMAND} == "cleanup" ] ; then
      echo "  FT_HOSTONLY                - Only host network backed pods are launched, off by default."
      echo "                               Used on DPUs. It is best to export this variable. test.sh and"
      echo "                               cleanup.sh will try to detect if it was used on launch, but"
      echo "                               false positives could occur if pods are renamed or server pod"
      echo "                               failed to come up. Example:"
      echo "                                 export FT_HOSTONLY=true"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"
      echo "  FT_CLIENTONLY              - Only client pods are launched, no server pods or services. Off by"
      echo "                               default. Used in a Multi-Cluster deployment where server pods and"
      echo "                               services are deployed in a different cluster. It is best to export"
      echo "                               this variable. test.sh and cleanup.sh will try to detect if it was"
      echo "                               used on launch, but false positives could occur if pods are renamed"
      echo "                               or pods failed to come up. Example:"
      echo "                                 export FT_NAMESPACE=flow-test"
      echo "                                 export FT_CLIENTONLY=true"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"
      fi
      if [ ${COMMAND} == "cleanup" ] ; then
      echo "  CLEAN_ALL                  - Remove all generated files (yamls from j2, iperf logs, and"
      echo "                               ovn-trace logs). Default is to leave in place. Example:"
      echo "                                 CLEAN_ALL=true ./cleanup.sh"
      fi
      if [ ${COMMAND} == "test" ] ; then
      echo "  TEST_CASE (0 means all)    - Run a single test. Example:"
      echo "                                 TEST_CASE=3 ./test.sh"
      echo "  VERBOSE                    - Command output is masked by default. Enable curl output."
      echo "                               Example:"
      echo "                                 VERBOSE=true ./test.sh"
      echo "  IPERF                      - 'iperf3' can be run on each flow, off by default. Example:"
      echo "                                 IPERF=true ./test.sh"
      echo "  OVN_TRACE                  - 'ovn-trace' can be run on each flow, off by deafult. Example:"
      echo "                                 OVN_TRACE=true ./test.sh"
      echo "  FT_VARS                    - Print script variables. Off by default. Example:"
      echo "                                 FT_VARS=true ./test.sh"
      echo "  FT_NOTES                   - Print notes (in blue) where tests are failing but maybe shouldn't be."
      echo "                               On by default. Example:"
      echo "                                 FT_NOTES=false ./test.sh"
      echo "  CURL_CMD                   - Curl command to run. Allows additional parameters to be"
      echo "                               inserted. Example:"
      echo "                                 CURL_CMD=\"curl -v --connect-timeout 5\" ./test.sh"
      echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
      echo "                               from server. Example:"
      echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"
      fi
      echo "  FT_NAMESPACE               - Namespace for all pods, configMaps and services associated with"
      echo "                               Flow Tester. Defaults to \"default\" namespace. It is best to"
      echo "                               export this variable because launch.sh and cleanup.sh also need"
      echo "                               the same value set. Example:"
      echo "                                 export FT_NAMESPACE=flow-test"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"

      dump-working-data
    else
      echo
      if [ ${COMMAND} == "launch" ] ; then
      echo "Unknown input, try using \"./launch.sh --help\""
      elif [ ${COMMAND} == "test" ] ; then
      echo "Unknown input, try using \"./test.sh --help\""
      elif [ ${COMMAND} == "cleanup" ] ; then
      echo "Unknown input, try using \"./cleanup.sh --help\""
      fi
      echo
    fi

    exit 0
  fi
}

determine-default-data() {
  # Try to determine if only host-networked pods were created.
  if [ "$FT_HOSTONLY" == unknown ]; then
    if [ ${COMMAND} == "launch" ] ; then
      FT_HOSTONLY=false
    else
      # Look for Server pod, in Host Only it shouldn't be there
      TEST_HTTP_SERVER=`kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_POD_NAME"`
      if [ -z "${TEST_HTTP_SERVER}" ]; then
        # Server pod isn't there for Client Only either, so check Host Backed Server pod, it should be there
        TEST_HTTP_HOST_SERVER=`kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME"`
        if [ -n "${TEST_HTTP_HOST_SERVER}" ]; then
          FT_HOSTONLY=true
        else
          FT_HOSTONLY=false
        fi
      else
        FT_HOSTONLY=false
      fi
    fi
  fi

  # Try to determine if only server pods were created.
  if [ "$FT_CLIENTONLY" == unknown ]; then
    if [ ${COMMAND} == "launch" ] ; then
      FT_CLIENTONLY=false
    else
      # Look for Host backer Server pod, in Client Only it shouldn't be there
      TEST_HTTP_SERVER=`kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME"`
      if [ -z "${TEST_HTTP_SERVER}" ]; then
        FT_CLIENTONLY=true
      else
        FT_CLIENTONLY=false
      fi
    fi
  fi
}

query-dynamic-data() {
  # In Client Only mode, no Server Pods or Services are created. They are assumed
  # to be in another cluster. So checks for FT_CLIENTONLY are needed to skip
  # any queries looking for Server Pods or Services.

  # In Host Only mode, only Host Backed Pods and Services are created. So checks for
  # FT_HOSTONLY are need to skip checks non-Host Backed Pods and Services.

  #
  # Determine Local and Remote Nodes
  #
  if [ "$FT_CLIENTONLY" == false ] ; then
    SERVER_POD_NODE=`kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $HTTP_SERVER_HOST_POD_NAME  | awk -F' ' '{print $7}'`
  else
  	# In Client Only, there are no Server Nodes, so leave blank and logic below
  	# will pick the first non-Master. 
    SERVER_POD_NODE=
  fi

  # Local Client Node is the same Node Server is running on.
  LOCAL_CLIENT_NODE=$SERVER_POD_NODE
  # Initialize to the Local Client Node and over write below.
  REMOTE_CLIENT_NODE=$LOCAL_CLIENT_NODE

  # Find the REMOTE NODE for POD and HOST POD. (REMOTE is a node server is NOT running on)
  NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    # Check for non-master (KIND clusters don't have "worker" role set)
    kubectl get node ${NODE_ARRAY[$i]} --no-headers=true | awk -F' ' '{print $3}' | grep -q master
    if [ "$?" == 1 ]; then
      # If this node was requested and LOCAL_CLIENT_NODE is blank (because Client Only Mode
      # and there is no Server Node, which is the default), then use this node as Local Client.
      if [ "$FT_REQ_SERVER_NODE" == "${NODE_ARRAY[$i]}" ] && [ -z "${LOCAL_CLIENT_NODE}" ] ; then
        LOCAL_CLIENT_NODE=${NODE_ARRAY[$i]}
      # If this node was requested and REMOTE_CLIENT_NODE is blank (because Client Only Mode
      # and there is no Server Node, which is the default), then use this node as Remote Client.
      elif [ "$FT_REQ_REMOTE_CLIENT_NODE" == "${NODE_ARRAY[$i]}" ] && [ -z "${REMOTE_CLIENT_NODE}" ] ; then
        REMOTE_CLIENT_NODE=${NODE_ARRAY[$i]}
      # If LOCAL_CLIENT_NODE is blank (because Client Only Mode and there is no Server Node,
      # which is the default), then use this node as Local Client.
      elif [ -z "${LOCAL_CLIENT_NODE}" ] ; then
        LOCAL_CLIENT_NODE=${NODE_ARRAY[$i]}
      # Otherwise if this was the requested Remote Client, make sure it doesn't overlap with Server Node.
      elif [ "$FT_REQ_REMOTE_CLIENT_NODE" == all ] || [ "$FT_REQ_REMOTE_CLIENT_NODE" == "${NODE_ARRAY[$i]}" ]; then
        if [ "$LOCAL_CLIENT_NODE" != "${NODE_ARRAY[$i]}" ]; then
          REMOTE_CLIENT_NODE=${NODE_ARRAY[$i]}
        fi
      fi
    fi
  done
  if [ "$REMOTE_CLIENT_NODE" == "$LOCAL_CLIENT_NODE" ]; then
    if [ "$FT_REQ_REMOTE_CLIENT_NODE" == "$REMOTE_CLIENT_NODE" ]; then
      echo -e "${BLUE}ERROR: As requested, REMOTE_CLIENT_NODE is same as LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
    else
      echo -e "${RED}ERROR: Unable to find REMOTE_CLIENT_NODE. Using LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
    fi
  fi
  
  #
  # Determine Local and Remote Pods
  #
  LOCAL_CLIENT_HOST_POD=`kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
  REMOTE_CLIENT_HOST_POD=`kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`

  if [ "$FT_HOSTONLY" == false ]; then
    LOCAL_CLIENT_POD=`kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
    REMOTE_CLIENT_POD=`kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide| grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`
  else
    LOCAL_CLIENT_POD=
    REMOTE_CLIENT_POD=
  fi

  #
  # Determine IP Addresses and Ports
  #
  if [ "$FT_CLIENTONLY" == false ] ; then
    HTTP_SERVER_HOST_IP=`kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $HTTP_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}'`
    IPERF_SERVER_HOST_IP=`kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $IPERF_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}'`

    HTTP_CLUSTERIP_HOST_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'`
    HTTP_CLUSTERIP_HOST_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F/ '{print $1}'`

    HTTP_NODEPORT_HOST_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`
    HTTP_NODEPORT_HOST_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}'`

    IPERF_CLUSTERIP_HOST_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'`
    IPERF_CLUSTERIP_HOST_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F'/' '{print $1}'`

    IPERF_NODEPORT_HOST_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`
    IPERF_NODEPORT_HOST_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}'`

    if [ "$FT_HOSTONLY" == false ]; then
      HTTP_SERVER_POD_IP=`kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $HTTP_SERVER_POD_NAME  | awk -F' ' '{print $6}'`
      IPERF_SERVER_POD_IP=`kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $IPERF_SERVER_POD_NAME  | awk -F' ' '{print $6}'`

      HTTP_CLUSTERIP_POD_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $3}'`
      HTTP_CLUSTERIP_POD_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F/ '{print $1}'`

      HTTP_NODEPORT_POD_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_NODEPORT_SVC_NAME | awk -F' ' '{print $3}'`
      HTTP_NODEPORT_POD_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $HTTP_NODEPORT_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}'`

      IPERF_CLUSTERIP_POD_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $3}'`
      IPERF_CLUSTERIP_POD_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F'/' '{print $1}'`

      IPERF_NODEPORT_POD_SVC_IPV4=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_NODEPORT_POD_SVC_NAME | awk -F' ' '{print $3}'`
      IPERF_NODEPORT_POD_SVC_PORT=`kubectl get services -n ${FT_NAMESPACE} | grep $IPERF_NODEPORT_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}'`
    else
      HTTP_SERVER_POD_IP=
      IPERF_SERVER_POD_IP=

      HTTP_CLUSTERIP_POD_SVC_IPV4=
      HTTP_CLUSTERIP_POD_SVC_PORT=

      HTTP_NODEPORT_POD_SVC_IPV4=
      HTTP_NODEPORT_POD_SVC_PORT=

      IPERF_CLUSTERIP_POD_SVC_IPV4=
      IPERF_CLUSTERIP_POD_SVC_PORT=

      IPERF_NODEPORT_POD_SVC_IPV4=
      IPERF_NODEPORT_POD_SVC_PORT=
    fi
  else
    # No Server Values
    HTTP_SERVER_HOST_IP=
    IPERF_SERVER_HOST_IP=

    # Client Only is true, so no Server Pods and Services are imported.
    #
    # $ kubectl get serviceimports -A
    # NAMESPACE             NAME                                                    TYPE           IP                 AGE
    # submariner-operator   ft-http-service-clusterip-host-v4-flow-test-cluster1    ClusterSetIP   ["100.1.68.196"]   46h
    # submariner-operator   ft-http-service-clusterip-pod-v4-flow-test-cluster1     ClusterSetIP   ["100.1.18.136"]   46h
    # submariner-operator   ft-iperf-service-clusterip-host-v4-flow-test-cluster1   ClusterSetIP   ["100.1.31.34"]    46h
    # submariner-operator   ft-iperf-service-clusterip-pod-v4-flow-test-cluster1    ClusterSetIP   ["100.1.39.167"]   46h
    #
    # TMP_SVC_NAME
    #   grep for the SVC_NAME (sub-string),
    #   use awk to tokenize row delimiting on 2 spaces and retrieve full NAME,
    # IP Address
    #   grep for the TMP_SVC_NAME,
    #   use awk to tokenize row delimiting on 2 spaces and retrieve IP Token,
    #   use awk to tokenize IP string delimiting on " and getting IP Address without [""]
    MC_NAMESPACE=${MC_NAMESPACE:-submariner-operator}

    TMP_SVC_NAME=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${HTTP_CLUSTERIP_HOST_SVC_NAME} | awk -F' ' '{print $1}'`
    HTTP_CLUSTERIP_HOST_SVC_IPV4=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${TMP_SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'`
    HTTP_CLUSTERIP_HOST_SVC_PORT=`kubectl describe serviceimports -n ${MC_NAMESPACE} ${TMP_SVC_NAME} | grep "Port:" | awk -F' ' '{print $2}'`

    TMP_SVC_NAME=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${IPERF_CLUSTERIP_HOST_SVC_NAME} | awk -F' ' '{print $1}'`
    IPERF_CLUSTERIP_HOST_SVC_IPV4=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${TMP_SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'`
    IPERF_CLUSTERIP_HOST_SVC_PORT=`kubectl describe serviceimports -n ${MC_NAMESPACE} ${TMP_SVC_NAME} | grep "Port:" | awk -F' ' '{print $2}'`

    if [ "$FT_HOSTONLY" == false ]; then
      TMP_SVC_NAME=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${HTTP_CLUSTERIP_POD_SVC_NAME} | awk -F' ' '{print $1}'`
      HTTP_CLUSTERIP_POD_SVC_IPV4=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE}  | grep ${TMP_SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'`
      HTTP_CLUSTERIP_POD_SVC_PORT=`kubectl describe serviceimports -n ${MC_NAMESPACE} ${TMP_SVC_NAME} | grep "Port:" | awk -F' ' '{print $2}'`

      TMP_SVC_NAME=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${IPERF_CLUSTERIP_POD_SVC_NAME} | awk -F' ' '{print $1}'`
      IPERF_CLUSTERIP_POD_SVC_IPV4=`kubectl get serviceimports --no-headers=true -n ${MC_NAMESPACE} | grep ${TMP_SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'`
      IPERF_CLUSTERIP_POD_SVC_PORT=`kubectl describe serviceimports -n ${MC_NAMESPACE} ${TMP_SVC_NAME} | grep "Port:" | awk -F' ' '{print $2}'`
    else
      HTTP_CLUSTERIP_POD_SVC_IPV4=
      #HTTP_CLUSTERIP_POD_SVC_PORT - Leave set to default instead of querying

      IPERF_CLUSTERIP_POD_SVC_IPV4=
      #IPERF_CLUSTERIP_POD_SVC_PORT - Leave set to default instead of querying
    fi

    # Node Port not supported as exported Service
    HTTP_NODEPORT_POD_SVC_IPV4=
    #HTTP_NODEPORT_POD_SVC_PORT - Leave set to default instead of querying

    HTTP_NODEPORT_HOST_SVC_IPV4=
    #HTTP_NODEPORT_HOST_SVC_PORT - Leave set to default instead of querying

    IPERF_NODEPORT_POD_SVC_IPV4=
    #IPERF_NODEPORT_POD_SVC_PORT - Leave set to default instead of querying

    IPERF_NODEPORT_HOST_SVC_IPV4=
    #IPERF_NODEPORT_HOST_SVC_PORT - Leave set to default instead of querying
  fi

  # Get Kubernetes API Server Data
  HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4=`kubectl get services --no-headers kubernetes | awk -F' ' '{print $3}'`
  HTTP_CLUSTERIP_KUBEAPI_SVC_PORT=`kubectl get services --no-headers kubernetes | awk -F' ' '{print $5}' | awk -F/ '{print $1}'`

  HTTP_CLUSTERIP_KUBEAPI_EP_IP=`kubectl get endpoints --no-headers kubernetes | awk -F' ' '{print $2}' | awk -F: '{print $1}'`
  HTTP_CLUSTERIP_KUBEAPI_EP_PORT=`kubectl get endpoints --no-headers kubernetes | awk -F' ' '{print $2}' | awk -F: '{print $2}'`

  # If Service Qualifier, update all services
  # This needs to be done after and searches using services.
  if [ ! -z "$FT_SVC_QUALIFIER" ] ; then
    HTTP_CLUSTERIP_POD_SVC_NAME=${HTTP_CLUSTERIP_POD_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_CLUSTERIP_HOST_SVC_NAME=${HTTP_CLUSTERIP_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_NODEPORT_SVC_NAME=${HTTP_NODEPORT_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_NODEPORT_HOST_SVC_NAME=${HTTP_NODEPORT_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_CLUSTERIP_POD_SVC_NAME=${IPERF_CLUSTERIP_POD_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_CLUSTERIP_HOST_SVC_NAME=${IPERF_CLUSTERIP_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_NODEPORT_SVC_NAME=${IPERF_NODEPORT_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_NODEPORT_HOST_SVC_NAME=${IPERF_NODEPORT_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
  fi
}