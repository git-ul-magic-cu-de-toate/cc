kubectl create namespace gitea
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
helm install gitea gitea-charts/gitea --namespace gitea

kubectl port-forward svc/gitea-http 3000:3000 -n gitea
# ssh -J fep -L 3000:127.0.0.1:3000 -i ~/.ssh/id_rsa student@10.9.3.28 pentru a accesa gitea pe localhost