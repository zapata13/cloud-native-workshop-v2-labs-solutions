#Instalar suscripcion de openshift gitops
oc apply -f gitops-deployment/gitops-subscription.yaml

#Obtener password de usuario admin de argocd
oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath="{.data['admin\.password']}" | base64 -d

#crear aplicacion en ArgoCD
oc create -f gitops-deployment/operators-app-argocd.yaml -n openshift-gitops