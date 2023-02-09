USERXX=$1

#PARA LA PARTE UI USAR REPO PRINCIPAL DE LAB M4

if [ -z "$USERXX" -o "$USERXX" = "userXX" ]
  then
    echo "Usage: Input your username like deploy-solution-m4.sh user1"
    exit;
fi

echo "Start deploying all services in Module 4 of CCN DevTrack"

echo "Cleaning project"
oc project $USERXX-cloudnativeapps || oc new-project $USERXX-cloudnativeapps
oc delete dc,deployment,bc,build,svc,route,pod,is --all
rm -rf $PWD/m4/coolstore-ui/node_modules

echo "Waiting 30 seconds to finialize deletion of resources..."
sleep 30

echo "Creating Kafka and Topics........"
cat <<EOF | oc apply -n $USERXX-cloudnativeapps -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: $USERXX-cloudnativeapps
spec:
  kafka:
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      inter.broker.protocol.version: '3.3'
    storage:
      type: ephemeral
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    version: 3.3.1
    replicas: 3
  entityOperator:
    topicOperator: {}
    userOperator: {}
  zookeeper:
    storage:
      type: ephemeral
    replicas: 3
EOF

cat <<EOF | oc apply -n $USERXX-cloudnativeapps -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: orders
  labels:
    strimzi.io/cluster: my-cluster
  namespace: $USERXX-cloudnativeapps
spec:
  partitions: 10
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
EOF

cat <<EOF | oc apply -n $USERXX-cloudnativeapps -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: payments
  labels:
    strimzi.io/cluster: my-cluster
  namespace: $USERXX-cloudnativeapps
spec:
  partitions: 10
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
EOF
echo "Created Kafka and Topics........"

echo "Deploying Inventory service........"
oc new-app --as-deployment-config -e POSTGRESQL_USER=inventory \
  -e POSTGRESQL_PASSWORD=mysecretpassword \
  -e POSTGRESQL_DATABASE=inventory openshift/postgresql:latest \
  --name=inventory-database

mvn clean package -DskipTests -f $PWD/m4/inventory-service
#mvn clean package -DskipTests -f $PWD/m4/inventory-service -Dquarkus.native.container-build=true -Pnative

oc rollout status -w dc/inventory

oc label dc/inventory app.kubernetes.io/part-of=inventory --overwrite && \
oc label dc/inventory-database app.kubernetes.io/part-of=inventory app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/inventory app.openshift.io/connects-to=inventory-database --overwrite && \
oc annotate dc/inventory app.openshift.io/vcs-ref=ocp-4.11 --overwrite
echo "Deployed Inventory service........"

echo "Deploying Catalog service........"
oc new-app --as-deployment-config -e POSTGRESQL_USER=catalog \
             -e POSTGRESQL_PASSWORD=mysecretpassword \
             -e POSTGRESQL_DATABASE=catalog \
             openshift/postgresql:latest \
             --name=catalog-database

mvn clean install spring-boot:repackage -DskipTests -f $PWD/m4/catalog-service

oc new-build registry.access.redhat.com/ubi8/openjdk-11 --binary --name=catalog -l app=catalog
oc start-build catalog --from-file=$PWD/m4/catalog-service/target/catalog-1.0.0-SNAPSHOT.jar --follow

oc new-app catalog  --as-deployment-config -e JAVA_OPTS_APPEND='-Dspring.profiles.active=openshift' && oc expose service catalog && \
oc label dc/catalog app.kubernetes.io/part-of=catalog app.openshift.io/runtime=rh-spring-boot --overwrite && \
oc label dc/catalog-database app.kubernetes.io/part-of=catalog app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/catalog app.openshift.io/connects-to=inventory,catalog-database --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-uri=https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-ref=ocp-4.11 --overwrite
echo "Deployed Catalog service........"

echo "Deploying Cart service........"
oc new-app --as-deployment-config quay.io/openshiftlabs/ccn-infinispan:12.0.0.Final-1 --name=datagrid-service -e USER=user -e PASS=pass
mvn quarkus:add-extension -Dextensions="messaging-kafka" -f $PWD/m4/cart-service
mvn quarkus:add-extension -Dextensions="openshift" -f $PWD/m4/cart-service
#mvn clean package -DskipTests -f $PWD/m4/cart-service -Dquarkus.native.container-build=true -Pnative
mvn clean package -DskipTests -f $PWD/m4/cart-service
oc rollout status -w dc/cart

oc label dc/cart app.kubernetes.io/part-of=cart app.openshift.io/runtime=quarkus --overwrite && \
oc label dc/datagrid-service app.kubernetes.io/part-of=cart app.openshift.io/runtime=datagrid --overwrite && \
oc annotate dc/cart app.openshift.io/connects-to=catalog,datagrid-service --overwrite && \
oc annotate dc/cart app.openshift.io/vcs-ref=ocp-4.11 --overwrite
echo "Deployed Cart service........"

echo "Deploying Order service........"
oc new-app --as-deployment-config --docker-image quay.io/openshiftlabs/ccn-mongo:4.0 --name=order-database

#mvn clean package -DskipTests -f $PWD/m4/order-service -Dquarkus.native.container-build=true -Pnative
mvn clean package -DskipTests -f $PWD/m4/order-service
oc rollout status -w dc/order

oc label dc/order app.kubernetes.io/part-of=order --overwrite && \
oc label dc/order-database app.kubernetes.io/part-of=order app.openshift.io/runtime=mongodb --overwrite && \
oc annotate dc/order app.openshift.io/connects-to=order-database --overwrite && \
oc annotate dc/order app.openshift.io/vcs-ref=ocp-4.11 --overwrite
echo "Deployed Order service........"

echo "Deploying UI service........"
cd $PWD/m4/coolstore-ui && npm install --save-dev nodeshift
npm run nodeshift && oc expose svc/coolstore-ui && \
oc label dc/coolstore-ui app.kubernetes.io/part-of=coolstore --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/connects-to=order-cart,catalog,inventory,order --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-uri=https://github.com/zapata13/cloud-native-workshop-v2-labs-solutions.git --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-ref=ocp-4.11 --overwrite
cd ../../
echo "Deployed UI service........"

echo "Deploying Payment service........"

sed -i'' -e "s/userXX/${USERXX}/g" $PWD/m4/payment-service/src/main/resources/application.properties
rm -rf $PWD/m4/payment-service/src/main/resources/application.properties-e

mvn quarkus:add-extension -Dextensions="messaging-kafka" -f $PWD/m4/payment-service
mvn quarkus:add-extension -Dextensions="openshift" -f $PWD/m4/payment-service
mvn clean package -DskipTests -Dquarkus.package.uber-jar=false -Dquarkus.native.container-build=true -f $PWD/m4/payment-service -Pnative


oc label rev/payment-00001 app.openshift.io/runtime=quarkus --overwrite && \
oc label dc/payment-00001-deployment app.kubernetes.io/part-of=payment --overwrite && \
oc annotate dc/payment-00001-deployment app.openshift.io/connects-to=my-cluster --overwrite && \
oc annotate dc/payment-00001-deployment app.openshift.io/vcs-ref=ocp-4.11 --overwrite

cat <<EOF | oc apply -n demo-cloudnativeapps  -f -
apiVersion: sources.knative.dev/v1beta1
kind: KafkaSource
metadata:
  name: kafka-source
spec:
  consumerGroup: knative-group
  bootstrapServers:
  - my-cluster-kafka-bootstrap.demo-cloudnativeapps.svc:9092
  topics:
  - orders
  sink:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: payment
EOF
echo "Deployed Payment service........"

echo "Creating Cloud-Native CI/CD Pipelines using Tekton........"
oc project $USERXX-cloudnative-pipeline || oc new-project $USERXX-cloudnative-pipeline
oc delete dc,deployment,bc,build,svc,route,pod,is --all

echo "Waiting 30 seconds to finialize deletion of resources..."
sleep 30

oc create -f $PWD/m4/payment-service/knative/pipeline/apply_manifests_task.yaml
oc create -f $PWD/m4/payment-service/knative/pipeline/update_deployment_task.yaml
oc create -f $PWD/m4/payment-service/knative/pipeline/pipeline.yaml
oc create -f $PWD/m4/payment-service/knative/pipeline/persistent_volume_claim.yaml

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=$PWD/m4/payment-service/knative/pipeline/persistent_volume_claim.yaml \
    -p deployment-name=pipelines-vote-api \
    -p git-url=https://github.com/openshift/pipelines-vote-api.git \
    -p git-revision=pipelines-1.4 \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$USERXX-cloudnative-pipeline/pipelines-vote-api

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=$PWD/m4/payment-service/knative/pipeline/persistent_volume_claim.yaml \
    -p deployment-name=pipelines-vote-ui \
    -p git-url=http://github.com/openshift/pipelines-vote-ui.git \
    -p git-revision=pipelines-1.4 \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$USERXX-cloudnative-pipeline/pipelines-vvote-ui
echo "Created Cloud-Native CI/CD Pipelines using Tekton........"

echo "Finished deploying all services in Module 4 of CCN DevTrack"


#"Bootstrap AMQ Streams Tests"
#Producer
oc run kafka-producer -ti \
--image=registry.redhat.io/amq7/amq-streams-kafka-33-rhel8:2.3.0 \
--rm=true \
--restart=Never \apiVersion: v1
kind: Namespace
metadata:
  name: openshift-operators-redhat
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  finalizers:
  - kubernetes
-- bin/kafka-console-producer.sh \
--bootstrap-server my-cluster-kafka-bootstrap.demo-cloudnativeapps.svc:9092 \
--topic my-topic

#consumer
oc run kafka-consumer -ti \
--image=registry.redhat.io/amq7/amq-streams-kafka-33-rhel8:2.3.0 \
--rm=true \
--restart=Never \
-- bin/kafka-console-consumer.sh \
--bootstrap-server my-cluster-kafka-bootstrap.demo-cloudnativeapps.svc:9092 \
--topic my-topic \
--from-beginning