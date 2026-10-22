# Proiect Cloud

## Structura proiectului

* Screenshots/ -> conține capturi de ecran făcute în timpul efectuării proiectului
* app.yaml -> fișier de configurare pentru aplicația Cloud
* deployment.yaml -> fișier de configurare pentru Kubernetes (manifest)
* setup.sh -> script de configurare a mediului de dezvoltare
* task1.sh -> conține comenzile date la task-ul 1
* task2.sh -> conține comenzile date la task-ul 2
* task3.sh -> conține comenzile date la task-ul 3
* task4.sh -> conține comenzile date la task-ul 4

## Descriere implementare

### Task 0

```bash
# Am făcut update la sistemul de operare și am instalat pachetele necesare pentru a putea lucra cu Docker și Kubernetes.
sudo apt update && sudo apt upgrade -y

# am instalat git, curl, wget și vim (erau preinstalate pe mașina virtuală)
sudo apt install -y git curl wget vim

# Am instalat Docker folosind scriptul oficial de instalare (era preinstalat pe mașina virtuală)
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker

# Am instalat Kubernetes folosind scriptul oficial de instalare (era preinstalat pe mașina virtuală)
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Am instalat Kind folosind scriptul oficial de instalare
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/
```

### Task 1

```bash
# Am creat un cluster Kubernetes folosind Kind și am verificat dacă acesta a fost creat cu succes.
kind create cluster --name hw-cluster

kubectl config current-context # pentru a verifica contextul curent (hw-cluster)

kubectl get nodes # pentru a verifica dacă nodul este în stare de funcționare (Ready)
# output-ul comenzii ar trebui să fie similar cu:
# NAME                 STATUS   ROLES           AGE   VERSION
# kind-control-plane   Ready    control-plane   10m   v1.28.0

kubectl get pods -n kube-system # pentru a verifica dacă toate pod-urile sunt în stare de funcționare (Running)
```

### Task 2

```bash
# Am creat namespace-ul gitea folosind comanda:
kubectl create namespace gitea

# Am instalat Gitea folosind Helm folosind următoarele comenzi:
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
helm install gitea gitea-charts/gitea --namespace gitea

# Am făcut port-forward la serviciul gitea-http pentru a putea accesa Gitea din afara cluster-ului Kubernetes.
kubectl port-forward svc/gitea-http 3000:3000 -n gitea

# Pe mașina locală am făcut port-forward la portul expus în cluster cu:
ssh -J fep -L 3000:127.0.0.1:3000 -i ~/.ssh/id_rsa student@10.9.3.28 pentru a accesa gitea pe localhost
```

După care am accesat Gitea pe localhost:3000, mi-am creat un cont și am creat un repository numit `nginx-deployment`.

### Task 3

```bash
# Am creat namespace-ul argocd folosind comanda:
kubectl create namespace argocd

# După care am instalat ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Am făcut port-forward la serviciul argocd-server pentru a putea accesa ArgoCD din afara cluster-ului Kubernetes.
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Pe mașina locală am făcut port-forward la portul expus în cluster cu:
ssh -J fep -L 8080:127.0.0.1:8080 -i ~/.ssh/id_rsa student@10.9.3.28

# Am accesat ArgoCD pe localhost:8080, am folosit username-ul `admin` și am obținut parola cu comanda:
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Pentru că nu puteam să adaug repository-ul Gitea, am folosit argocd cli pentru a-l adăuga.
# Am descărcat argocd cli folosind următoarele comenzi: 
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Am folosit argocd cli pentru a mă conecta la ArgoCD și pentru a adăuga repository-ul Gitea:
argocd login localhost:8080 --username admin --password 'MVqO4IHlL7Czcw56'
argocd repo add http://gitea-http.gitea.svc.cluster.local:3000/florin065/nginx-deployment.git --username florin065 --password florin123
```

### Task 4

```bash
# Am clonat repository-ul `cloud-courses` dat în cerință
git clone https://gitlab.cs.pub.ro/SCGC/cloud-courses.git

# Am intrat în directorul `cloud-courses` și am creat imaginea Docker folosind comanda:
docker build -t cloud-courses:latest .

# După care am încărcat imaginea Docker în cluster-ul Kubernetes folosind comanda:
kind load docker-image cloud-courses:latest --name hw-cluster

# Am creat deployment-ul și serviciul în deployment.yaml, iar apoi aplicația în app.yaml. Am dat push pe gitea.

# După care am dat apply la aplicația Cloud folosind comanda:
kubectl apply -f app.yaml

# Am făcut port-forward la serviciul cloud-courses-service pentru a putea accesa aplicația Cloud din afara cluster-ului Kubernetes.
kubectl port-forward svc/cloud-courses-service 8081:8081

# Pe mașina locală am făcut port-forward la portul expus în cluster cu:
ssh -J fep -L 8081:127.0.0.1:8081 -i ~/.ssh/id_rsa student@10.9.3.28
```

Am creat un fișier deployment.yaml în care am definit deployment-ul și serviciul pentru aplicația Cloud. Am folosit imaginea `cloud-courses:latest` care conține aplicația Cloud.

deployment.yaml:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloud-courses-deployment
  labels:
    app: cloud-courses
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloud-courses
  template:
    metadata:
      labels:
        app: cloud-courses
    spec:
      containers:
      - name: cloud-courses
        image: cloud-courses:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
        env:
        - name: URL
          value: "http://localhost"
        - name: BASE_URL
          value: "/cloud-courses/"
---
apiVersion: v1
kind: Service
metadata:
  name: cloud-courses-service
spec:
  selector:
    app: cloud-courses
  ports:
  - protocol: TCP
    port: 8081
    targetPort: 3000
  type: NodePort
```

După care am creat aplicația în ArgoCD folosind fișierul app.yaml. Am folosit repository-ul Gitea creat anterior și am setat aplicația să fie sincronizată automat cu repository-ul.

app.yaml:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloud-courses-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'http://gitea-http.gitea.svc.cluster.local:3000/florin065/nginx-deployment.git'
    targetRevision: HEAD
    path: .
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Am testat aplicația Cloud accesând-o pe localhost:8081, dar și pe localhost:8080 (portul expus de ArgoCD) pentru a verifica dacă aplicația este sincronizată corect.

### Task 5

Am modificat deployment.yaml pentru a adăuga liveness probe pentru aplicația Cloud.

```yaml
        livenessProbe:
          httpGet:
            path: "/cloud-courses/"
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

Am intrat iar pe argocd și am verificat dacă s-a dat sync la aplicația Cloud, și am verificat dacă liveness probe-ul funcționează corect.

În cluster am dat și comanda:

```bash
kubectl describe deployment cloud-courses-deployment
```

Am observat că liveness probe-ul este activ și funcționează corect.

## Autor: Subțirică Florin-Ioan 343C3
