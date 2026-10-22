git clone https://gitlab.cs.pub.ro/SCGC/cloud-courses.git

docker build -t cloud-courses:latest .
kind load docker-image cloud-courses:latest --name hw-cluster

kubectl apply -f app.yaml
kubectl port-forward svc/cloud-courses-service 8081:8081
# ssh -J fep -L 8081:127.0.0.1:8081 -i ~/.ssh/id_rsa student@10.9.3.28 pentru a accesa cloud courses pe localhost