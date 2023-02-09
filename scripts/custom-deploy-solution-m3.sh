#!/bin/bash

USERXX=$1

if [ -z "$USERXX" -o "$USERXX" = "userXX" ]
  then
    echo "Usage: Input your username like deploy-solution-m3.sh user1"
    exit;
fi

echo "Start deploying all services in Module 3 of CCN DevTrack"

echo "Deploying Bookinfo service........"
oc project demo-istio
oc delete all --all -n demo-istio

echo "Waiting 30 seconds to finialize deletion of resources..."
sleep 30

cat <<EOF | oc apply -n istio-system  -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system 
spec:
  members:
    - demo-istio
EOF

oc apply -n demo-istio -f $PWD/m3/istio/bookinfo.yaml
oc apply -n demo-istio -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.3.1/samples/bookinfo/platform/kube/bookinfo.yaml
oc apply -n demo-istio -f $PWD/m3/istio/bookinfo-gateway.yaml

ISTIOHOST=$(oc get route istio-ingressgateway -n istio-system -o jsonpath="{.spec.host}")
PATCH_VS="oc patch -n demo-istio virtualservice/bookinfo --type='json' -p '[{\"op\":\"add\",\"path\":\"/spec/hosts\",\"value\": ["\"$ISTIOHOST\""]}]'"
echo "PATCH_VS: $PATCH_VS"
eval $PATCH_VS

oc apply -n demo-istio -f $PWD/m3/istio/destination-rule-all.yaml

oc label deployment/productpage-v1 app.openshift.io/runtime=python --overwrite && \
oc label deployment/details-v1 app.openshift.io/runtime=ruby --overwrite && \
oc label deployment/reviews-v1 app.openshift.io/runtime=java --overwrite && \
oc label deployment/reviews-v2 app.openshift.io/runtime=java --overwrite && \
oc label deployment/reviews-v3 app.openshift.io/runtime=java --overwrite && \
oc label deployment/ratings-v1 app.openshift.io/runtime=nodejs --overwrite && \
oc label deployment/details-v1 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc label deployment/productpage-v1 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc label deployment/ratings-v1 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc label deployment/reviews-v1 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc label deployment/reviews-v2 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc label deployment/reviews-v3 app.kubernetes.io/part-of=bookinfo --overwrite && \
oc annotate deployment/productpage-v1 app.openshift.io/connects-to=reviews-v1,reviews-v2,reviews-v3,details-v1 && \
oc annotate deployment/reviews-v2 app.openshift.io/connects-to=ratings-v1 && \
oc annotate deployment/reviews-v3 app.openshift.io/connects-to=ratings-v1

 oc rollout status -n demo-istio -w deployment/productpage-v1 && \
 oc rollout status -n demo-istio -w deployment/reviews-v1 && \
 oc rollout status -n demo-istio -w deployment/reviews-v2 && \
 oc rollout status -n demo-istio -w deployment/reviews-v3 && \
 oc rollout status -n demo-istio -w deployment/details-v1 && \
 oc rollout status -n demo-istio -w deployment/ratings-v1

 oc get pods -n demo-istio --selector app=reviews
echo "Deployed Bookinfo service........"

echo "Finished deploying all services in Module 3 of CCN DevTrack"

BOOK_URL=istio-ingressgateway-istio-system.app.openshift.com

for i in {1..1000} ; do curl -o /dev/null -s -w "%{http_code}\n" http://istio-ingressgateway-istio-system.apps.cluster-p78qk.p78qk.sandbox1252.opentlc.com/productpage ; sleep 2 ; done