#!/bin/bash

shopt -s expand_aliases

# Source the variables and functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

COMMAND="test"

# Source the functions in other files
. variables.sh
. generate-yaml.sh
. labels.sh
. multi-cluster.sh

determine-default-data
query-dynamic-data
process-help $1


# Local variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
IPERF_LOGS_DIR="iperf-logs"
OVN_TRACE_LOGS_DIR="ovn-traces"


# NOTE: env in the container has values that could be used instead of using the above commands:
#
# kubectl exec -it -n ${FT_NAMESPACE} $LOCAL_CLIENT_POD -- env
#  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#  HOSTNAME=ft-client-w2rps
#  container=docker
#  MY_WEB_SERVICE_NODE_V4_SERVICE_PORT=80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_PORT=80
#  KUBERNETES_PORT_443_TCP_PROTO=tcp
#  MY_WEB_SERVICE_NODE_V4_SERVICE_HOST=10.96.66.203
#  MY_WEB_SERVICE_NODE_V4_PORT=tcp://10.96.66.203:80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP=tcp://10.96.66.203:80
#  KUBERNETES_SERVICE_HOST=10.96.0.1
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_PROTO=tcp
#  KUBERNETES_SERVICE_PORT_HTTPS=443
#  KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
#  KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
#  MY_WEB_SERVICE_NODE_V4_SERVICE_PORT_WEBSERVER_NODE_V4_80=80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_ADDR=10.96.66.203
#  KUBERNETES_SERVICE_PORT=443
#  KUBERNETES_PORT=tcp://10.96.0.1:443
#  KUBERNETES_PORT_443_TCP_PORT=443
#
# kubectl exec -it -n ${FT_NAMESPACE} $LOCAL_CLIENT_POD -- /bin/sh -c 'curl "http://$MY_WEB_SERVICE_NODE_V4_SERVICE_HOST:$MY_WEB_SERVICE_NODE_V4_SERVICE_PORT/"'


#
# Functions
#

process-curl() {
  # The following VARIABLES are used by this function in the following combinations:
  #   From outside Cluster:
  #     TEST_SERVER_HTTP_DST
  #     TEST_SERVER_HTTP_DST_PORT
  #   No Port:
  #     TEST_CLIENT_POD
  #     TEST_SERVER_HTTP_DST
  #   Use Destination and Port:
  #     TEST_CLIENT_POD
  #     TEST_SERVER_HTTP_DST
  #     TEST_SERVER_HTTP_DST_PORT
  # If not used, VARIABLE should be blank for 'if [ -z "${VARIABLE}" ]' test.

  if [ -z "${TEST_CLIENT_POD}" ]; then
    # From External (no 'kubectl exec') 
    echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    TMP_OUTPUT=`$CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/"`
  elif [ -z "${TEST_SERVER_HTTP_DST_PORT}" ]; then
    # No Port, so leave off Port from command
    echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}/\""
    TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}/"`
  else
    # Default command

    # If Kubebernetes API, include --cacert and -H TOKEN
    if [ "${TEST_SERVER_RSP}" == "${KUBEAPI_SERVER_STRING}" ]; then
      LCL_SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

      echo "LCL_TOKEN=kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token"
      LCL_TOKEN=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token`

      echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H \"Authorization: Bearer LCL_TOKEN\" -X GET \"https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api\""
      TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H "Authorization: Bearer ${LCL_TOKEN}" -X GET "https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api"`
    else
      echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/"`
    fi
  fi

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "${TMP_OUTPUT}"
  fi

  # Print SUCCESS or FAILURE
  echo "${TMP_OUTPUT}" | grep -cq "${TEST_SERVER_RSP}" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}

process-iperf() {
  # The following VARIABLES are used by this function:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_IPERF_DST
  #     TEST_SERVER_IPERF_DST_PORT

  IPERF_FILENAME="${IPERF_LOGS_DIR}/${TEST_FILENAME}"

  echo "kubectl exec -it -n ${FT_NAMESPACE} $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
  kubectl exec -it -n ${FT_NAMESPACE} $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME  > ${IPERF_FILENAME}

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Output (from ${IPERF_FILENAME}):"
    cat ${IPERF_FILENAME}
  else
    echo "Summary (see ${IPERF_FILENAME} for full detail):"
    cat ${IPERF_FILENAME} | grep -B 1 -A 1 "sender"
  fi

  # Print SUCCESS or FAILURE
  cat ${IPERF_FILENAME} | grep -cq "sender" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}

process-ovn-trace() {
  # The following VARIABLES are used by this function in the following combinations:
  #   Use Destination and Port:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_DST
  #     TEST_SERVER_OVNTRACE_DST_PORT
  #   Use Remote Host:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_RMTHOST
  #   Use Service and Port:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_SERVICE
  #     TEST_SERVER_OVNTRACE_DST_PORT
  # If not used, VARIABLE should be blank for 'if [ -z "${VARIABLE}" ]' test.

  echo "OVN-TRACE: BEGIN"
  TRACE_FILENAME="${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}"

  if [ ! -z "${TEST_SERVER_OVNTRACE_DST}" ]; then
    echo "${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -dst=$TEST_SERVER_OVNTRACE_DST -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -dst=$TEST_SERVER_OVNTRACE_DST -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  elif [ ! -z "${TEST_SERVER_OVNTRACE_RMTHOST}" ]; then
    echo ".${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -remotehost=$TEST_SERVER_OVNTRACE_RMTHOST \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -remotehost=$TEST_SERVER_OVNTRACE_RMTHOST \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  else
    echo "${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -service=$TEST_SERVER_OVNTRACE_SERVICE -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -service=$TEST_SERVER_OVNTRACE_SERVICE -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  fi

  echo "OVN-TRACE: END (see $TRACE_FILENAME for full detail)"
  echo
}

#
# Main Body
#


if [ "$FT_VARS" == true ]; then
  dump-working-data
fi

#
# Test each scenario
#
if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 1 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 01: Pod to Pod traffic"
  echo "---------------------------"

  echo
  echo "*** 1-a: Pod to Pod (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="01-a-pod2pod-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_POD_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 1-b: Pod to Pod (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="01-b-pod2pod-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_POD_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 2 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 02: Pod to Host traffic"
  echo "----------------------------"

  echo
  echo "*** 2-a: Pod to Host (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="02-a-pod2host-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_HOST_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 2-b: Pod to Host (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="02-b-pod2host-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_HOST_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 3 ] && [ "$FT_HOSTONLY" == false ]; then
  echo
  echo "FLOW 03: Pod -> Cluster IP Service traffic (Pod Backend)"
  echo "--------------------------------------------------------"

  echo
  echo "*** 3-a: Pod -> Cluster IP Service traffic (Pod Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="03-a-pod2clusterIpSvc-podBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 3-b: Pod -> Cluster IP Service traffic (Pod Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="03-b-pod2clusterIpSvc-podBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 4 ] && [ "$FT_HOSTONLY" == false ]; then
  echo
  echo "FLOW 04: Pod -> Cluster IP Service traffic (Host Backend)"
  echo "--------------------------------------------------------"

  echo
  echo "*** 4-a: Pod -> Cluster IP Service traffic (Host Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="04-a-pod2clusterIpSvc-hostBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 4-b: Pod -> Cluster IP Service traffic (Host Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="04-b-pod2clusterIpSvc-hostBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 5 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 05: Pod -> NodePort Service traffic (Pod Backend)"
  echo "------------------------------------------------------"

  echo
  echo "*** 5-a: Pod -> NodePort Service traffic (Pod Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="05-a-pod2nodePortSvc-podBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 5-b: Pod -> NodePort Service traffic (Pod Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="05-b-pod2nodePortSvc-podBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 6 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 06: Pod -> NodePort Service traffic (Host Backend)"
  echo "-------------------------------------------------------"

  echo
  echo "*** 6-a: Pod -> NodePort Service traffic (Host Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="06-a-pod2nodePortSvc-hostBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 6-b: Pod -> NodePort Service traffic (Host Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="06-b-pod2nodePortSvc-hostBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 7 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 07: Host to Pod traffic"
  echo "----------------------------"

  echo
  echo "*** 7-a: Host to Pod (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="07-a-host2pod-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_POD_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 7-b: Host to Pod (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="07-b-host2pod-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_POD_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 8 ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 08: Host to Host traffic"
  echo "-----------------------------"

  echo
  echo "*** 8-a: Host to Host (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="08-a-host2host-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_HOST_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    #process-ovn-trace
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host.${NC}"
      echo "OVN-TRACE: END"
      echo
      echo "ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi


  echo
  echo "*** 8-b: Host to Host (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="08-b-host2host-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_HOST_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    #process-ovn-trace
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host.${NC}"
      echo "OVN-TRACE: END"
      echo
      echo "ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 9 ] && [ "$FT_HOSTONLY" == false ]; then
  echo
  echo "FLOW 09: Host -> Cluster IP Service traffic (Pod Backend)"
  echo "---------------------------------------------------------"

  echo
  echo "*** 9-a: Host Pod -> Cluster IP Service traffic (Pod Backend - Same Node) ***"
  echo
  
  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="09-a-host2clusterIpSvc-podBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 9-b: Host Pod -> Cluster IP Service traffic (Pod Backend - Different Node) ***"
  echo
  
  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="09-b-host2clusterIpSvc-podBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_POD_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_POD_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_POD_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 10 ]; then
  echo
  echo "FLOW 10: Host Pod -> Cluster IP Service traffic (Host Backend)"
  echo "--------------------------------------------------------------"

  echo
  echo "*** 10-a: Host Pod -> Cluster IP Service traffic (Host Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="10-a-host2clusterIpSvc-hostBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 10-b: Host Pod -> Cluster IP Service traffic (Host Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="10-b-host2clusterIpSvc-hostBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    if [ "$FT_CLIENTONLY" == false ] ; then
      TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl
    elif [ "$FT_NOTES" == true ]; then
      echo "curl SvcEndPointIP:SvcPORT"
      echo -e "${BLUE}Test Skipped - No EndPoint exported in Multi-Cluster${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SVC_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_CLUSTERIP_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 11 ] && [ "$FT_HOSTONLY" == false ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 11: Host Pod -> NodePort Service traffic (Pod Backend)"
  echo "-----------------------------------------------------------"

  echo
  echo "*** 11-a: Host Pod -> NodePort Service traffic (Pod Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="11-a-host2nodePortSvc-podBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
    echo "curl hostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:NODEPORT"
    process-curl
    #if [ "$FT_NOTES" == true ]; then
    #  echo -e "${BLUE}curl: (6) Could not resolve host: ft-http-service-node-v4; Unknown error${NC}"
    #  echo -e "${BLUE}Should this work? -- GOOD QUESTION${NC}"
    #fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 11-b: Host Pod -> NodePort Service traffic (Pod Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="11-b-host2nodePortSvc-podBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
    echo "curl hostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    echo "curl SvcName:NODEPORT"
    process-curl
    #if [ "$FT_NOTES" == true ]; then
    #  echo "curl SvcName:NODEPORT"
    #  echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    #  echo -e "${BLUE}curl: (6) Could not resolve host: ft-http-service-node-v4; Unknown error${NC}"
    #  echo -e "${BLUE}Should this work?${NC}"
    #  echo
    #fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 12 ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 12: Host Pod -> NodePort Service traffic (Host Backend)"
  echo "------------------------------------------------------------"

  echo
  echo "*** 12-a: Host Pod -> NodePort Service traffic (Host Backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="12-a-host2nodePortSvc-hostBackend-sameNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:NODEPORT"
    process-curl
    #if [ "$FT_NOTES" == true ]; then
    #  echo "curl SvcName:NODEPORT"
    #  echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    #  echo -e "${BLUE}Test Skipped - the host has no idea about svc DNS resolution${NC}"
    #  echo
    #fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=

    echo "ovnkube-trace SvcName:NODEPORT"
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}If Test Skipped - why trace the same?${NC}"
    fi

    process-ovn-trace
  fi


  echo
  echo "*** 12-b: Host Pod -> NodePort Service traffic (Host Backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="12-b-host2nodePortSvc-hostBackend-diffNode.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    echo "curl SvcName:NODEPORT"
    process-curl
    #if [ "$FT_NOTES" == true ]; then
    #  echo "curl SvcName:NODEPORT"
    #  echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    #  echo -e "${BLUE}Test Skipped - the host has no idea about svc DNS resolution${NC}"
    #  echo
    #fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_SVC_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_CLUSTERIP_HOST_SVC_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=

    echo "ovnkube-trace SvcName:NODEPORT"
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}If Test Skipped - why trace the same?${NC}"
    fi

    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 13 ]; then
  echo
  echo "FLOW 13: Cluster -> External Network"
  echo "------------------------------------"

  if [ "$FT_HOSTONLY" == false ]; then
    echo
    echo "*** 13-a: Pod -> External Network ***"
    echo
  
    TEST_CLIENT_POD=$REMOTE_CLIENT_POD
    TEST_FILENAME="13-a-pod2external.txt"

    if [ "$CURL" == true ]; then
      TEST_SERVER_HTTP_DST=$EXTERNAL_URL
      TEST_SERVER_HTTP_DST_PORT=
      TEST_SERVER_RSP=$EXTERNAL_SERVER_STRING
      process-curl
    fi

    if [ "$IPERF" == true ]; then
      if [ "$FT_NOTES" == true ]; then
        echo -e "${BLUE}iperf Skipped - No external iperf server.${NC}"
        echo
        echo "iperf Skipped - No external iperf server." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi

    if [ "$OVN_TRACE" == true ]; then 
      TEST_SERVER_OVNTRACE_SERVICE=
      TEST_SERVER_OVNTRACE_DST=
      TEST_SERVER_OVNTRACE_DST_PORT=
      TEST_SERVER_OVNTRACE_RMTHOST=$EXTERNAL_SERVER_STRING
      process-ovn-trace
    fi
  fi

  echo
  echo "*** 13-b: Host -> External Network ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="13-b-host2external.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$EXTERNAL_URL
    TEST_SERVER_HTTP_DST_PORT=
    TEST_SERVER_RSP=$EXTERNAL_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf server.${NC}"
      echo
      echo "iperf Skipped - No external iperf server." > iperf-logs/${TEST_FILENAME}
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host.${NC}"
      echo "OVN-TRACE: END"
      echo
      echo "ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi
fi


if [ "$FT_NOTES" == true ]; then
  if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 14 ]; then
    echo
    echo "FLOW 14: External Network -> Cluster IP Service traffic"
    echo "-------------------------------------------------------"

    if [ "$FT_HOSTONLY" == false ]; then
      echo
      echo "*** 14-a: External Network -> Cluster IP Service traffic (Pod Backend) ***"
      echo

      TEST_CLIENT_POD=
      TEST_FILENAME="14-a-external2clusterIpSvc-podBackend.txt"

      if [ "$CURL" == true ]; then
        TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_POD_SVC_IPV4
        TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
        TEST_SERVER_RSP=$POD_SERVER_STRING
        #process-curl
        if [ "$FT_NOTES" == true ]; then
          echo "curl SvcClusterIP:NODEPORT"
          echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
          echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
          echo
        fi
      fi

      if [ "$IPERF" == true ]; then
        if [ "$FT_NOTES" == true ]; then
          echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
          echo
          echo "iperf Skipped - No external iperf client." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
        fi
      fi

      if [ "$OVN_TRACE" == true ]; then 
        if [ "$FT_NOTES" == true ]; then
          echo "OVN-TRACE: BEGIN"
          echo -e "${BLUE}ovn-trace Skipped.${NC}"
          echo "OVN-TRACE: END"
          echo
          echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
        fi
      fi
    fi


    echo
    echo "*** 14-b: External Network -> Cluster IP Service traffic (Host Backend) ***"
    echo

    TEST_CLIENT_POD=
    TEST_FILENAME="14-b-external2clusterIpSvc-hostBackend.txt"

    if [ "$CURL" == true ]; then
      TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SVC_IPV4
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_HOSTPOD_SVC_PORT
      TEST_SERVER_RSP=$HOST_SERVER_STRING
      #process-curl
      if [ "$FT_NOTES" == true ]; then
        echo "curl SvcClusterIP:NODEPORT"
        echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
        echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
        echo
      fi
    fi

    if [ "$IPERF" == true ]; then
      if [ "$FT_NOTES" == true ]; then
        echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
        echo
        echo "iperf Skipped - No external iperf client." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi

    if [ "$OVN_TRACE" == true ]; then 
      if [ "$FT_NOTES" == true ]; then
        echo "OVN-TRACE: BEGIN"
        echo -e "${BLUE}ovn-trace Skipped.${NC}"
        echo "OVN-TRACE: END"
        echo
        echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 15 ] && [ "$FT_CLIENTONLY" == false ] ; then
  echo
  echo "FLOW 15: External Network -> NodePort Service traffic"
  echo "-----------------------------------------------------"

  if [ "$FT_HOSTONLY" == false ]; then
    echo
    echo "*** 15-a: External Network -> NodePort Service traffic (Pod Backend) ***"
    echo

    TEST_CLIENT_POD=
    TEST_FILENAME="15-a-external2nodePortSvc-podBackend.txt"

    if [ "$CURL" == true ]; then
      TEST_SERVER_RSP=$POD_SERVER_STRING

      TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_POD_SVC_PORT
      #echo "curl SvcClusterIP:NODEPORT"
      #process-curl
      if [ "$FT_NOTES" == true ]; then
        echo "curl SvcClusterIP:NODEPORT"
        echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
        echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
        echo
      fi

      TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
      echo "curl EndPointIP:NODEPORT"
      process-curl

      TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
      TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_SVC_PORT
      #echo "curl SvcName:NODEPORT"
      #process-curl
      if [ "$FT_NOTES" == true ]; then
        echo "curl SvcName:NODEPORT"
        echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
        echo -e "${BLUE}Test Skipped - SVC HostName only resolves in cluster network${NC}"
        echo
      fi
    fi

    if [ "$IPERF" == true ]; then
      if [ "$FT_NOTES" == true ]; then
        echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
        echo
        echo "iperf Skipped - No external iperf client." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi

    if [ "$OVN_TRACE" == true ]; then 
      if [ "$FT_NOTES" == true ]; then
        echo "OVN-TRACE: BEGIN"
        echo -e "${BLUE}ovn-trace Skipped.${NC}"
        echo "OVN-TRACE: END"
        echo
        echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi
  fi


  echo
  echo "*** 15-b: External Network -> NodePort Service traffic (Host Backend) ***"
  echo

  TEST_CLIENT_POD=
  TEST_FILENAME="15-b-external2nodePortSvc-hostBackend.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_POD_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    #echo "curl SvcClusterIP:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcClusterIP:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_SVC_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVC HostName only resolves in cluster network${NC}"
      echo
    fi
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
      echo
      echo "iperf Skipped - No external iperf client." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped.${NC}"
      echo "OVN-TRACE: END"
      echo
      echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 16 ] ; then
  echo
  echo "FLOW 16: Cluster -> Kubernetes API Server"
  echo "-----------------------------------------"

  if [ "$FT_HOSTONLY" == false ]; then
    echo
    echo "*** 16-a: Pod -> Cluster IP Service traffic (Kubernetes API) ***"
    echo

    TEST_CLIENT_POD=$LOCAL_CLIENT_POD
    TEST_FILENAME="16-a-pod2clusterIpSvc-kubernetesApi.txt"

   if [ "$CURL" == true ]; then
      TEST_SERVER_RSP=$KUBEAPI_SERVER_STRING

      TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_SVC_PORT
      echo "curl SvcClusterIP:SvcPORT"
      process-curl

      TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_EP_IP
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_EP_PORT
      echo "curl SvcEndPointIP:SvcPORT"
      process-curl

      TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_SVC_NAME
      TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_SVC_PORT
      echo "curl SvcName:SvcPORT"
      process-curl
    fi

    if [ "$IPERF" == true ]; then
      if [ "$FT_NOTES" == true ]; then
        echo -e "${BLUE}iperf Skipped - No iperf client on Kubernetes API Server.${NC}"
        echo
        echo "iperf Skipped - No iperf client on Kubernetes API Server." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi

    if [ "$OVN_TRACE" == true ]; then 
      if [ "$FT_NOTES" == true ]; then
        echo "OVN-TRACE: BEGIN"
        echo -e "${BLUE}ovn-trace Skipped.${NC}"
        echo "OVN-TRACE: END"
        echo
        echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
      fi
    fi
  fi


  echo
  echo "*** 16-b: Host -> Cluster IP Service traffic (Kubernetes API) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="16-b-host2clusterIpSvc-kubernetesApi.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$KUBEAPI_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_SVC_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_EP_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_EP_PORT
    echo "curl SvcEndPointIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_KUBEAPI_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_CLUSTERIP_KUBEAPI_SVC_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No iperf client on Kubernetes API Server.${NC}"
      echo
      echo "iperf Skipped - No iperf client on Kubernetes API Server." > ${IPERF_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped.${NC}"
      echo "OVN-TRACE: END"
      echo
      echo "ovn-trace Skipped." > ${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}
    fi
  fi
fi


if [ "$FT_NOTES" == true ]; then
  if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 17 ] && [ "$FT_CLIENTONLY" == false ] ; then
    echo
    echo "FLOW 17: External Network -> Cluster (multiple external GW traffic)"
    echo "-------------------------------------------------------------------"

    if [ "$FT_NOTES" == true ]; then
      echo
      echo -e "${BLUE}NOT IMPLEMENTED${NC}"
      echo
    fi
  fi
fi

