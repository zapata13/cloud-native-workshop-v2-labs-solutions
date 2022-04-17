#!/bin/bash

USERXX=$1

if [ -z "$USERXX" -o "$USERXX" = "userXX" ]
  then
    echo "Usage: Input your username like deploy-solution-m3.sh user1"
    exit;
fi

echo "Start deploying all services in Module 3 of CCN DevTrack"

echo "Deploying Bookinfo service........"
oc project $USERXX-bookinfo
oc delete all --all -n $USERXX-bookinfo

echo "Waiting 30 seconds to finialize deletion of resources..."
sleep 30

cat <<EOF | oc apply -n $USERXX-istio-system  -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: $USERXX-istio-system 
spec:
  members:
    - $USERXX-bookinfo 
    - $USERXX-catalog
    - $USERXX-inventory
EOF

oc apply -n $USERXX-bookinfo -f $PWD/m3/istio/bookinfo.yaml
oc apply -n $USERXX-bookinfo -f $PWD/m3/istio/bookinfo-gateway.yaml

ISTIOHOST=$(oc get route istio-ingressgateway -n $USERXX-istio-system -o jsonpath="{.spec.host}")
PATCH_VS="oc patch -n $USERXX-bookinfo virtualservice/bookinfo --type='json' -p '[{\"op\":\"add\",\"path\":\"/spec/hosts\",\"value\": ["\"$ISTIOHOST\""]}]'"
echo "PATCH_VS: $PATCH_VS"
eval $PATCH_VS

oc apply -n $USERXX-bookinfo -f $PWD/m3/istio/destination-rule-all.yaml

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

 oc rollout status -n $USERXX-bookinfo -w deployment/productpage-v1 && \
 oc rollout status -n $USERXX-bookinfo -w deployment/reviews-v1 && \
 oc rollout status -n $USERXX-bookinfo -w deployment/reviews-v2 && \
 oc rollout status -n $USERXX-bookinfo -w deployment/reviews-v3 && \
 oc rollout status -n $USERXX-bookinfo -w deployment/details-v1 && \
 oc rollout status -n $USERXX-bookinfo -w deployment/ratings-v1

 oc get pods -n $USERXX-bookinfo --selector app=reviews
echo "Deployed Bookinfo service........"

echo "Finished deploying all services in Module 3 of CCN DevTrack"