kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
# ssh -J fep -L 8080:127.0.0.1:8080 -i ~/.ssh/id_rsa student@10.9.3.28 pentru a accesa argocd pe localhost
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

argocd login localhost:8080 --username admin --password 'MVqO4IHlL7Czcw56'
argocd repo add http://gitea-http.gitea.svc.cluster.local:3000/florin065/nginx-deployment.git --username florin065 --password florin123