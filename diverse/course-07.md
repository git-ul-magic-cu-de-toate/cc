# Cursul 06 - CI/CD

## Ce este CI/CD?

CI/CD este un acronim care vine de la Continuous Integration/Continuous Delivery (sau Continuous Deployment). In primul rand, acesta este un set de practici si instrumente care ajuta developerii sa livreze cod intr-un mod stabil si reproductibil.

Scopul unui workflow de CI/CD este de a automatiza procesul de livrare a codului, de la testare si pana la deployment catre utilizatorii finali.

Inputul pentru un CI/CD este o noua versiune a codului (de obicei triggerul este un commit pushed intr-un branch sau un PR merged).
Outputul dupa terminarea pipeline-ului poate fi un artefact (o imagine noua de docker, o versiunea noua de pachet) si/sau un nou deployment.

Pipeline-ul CI/CD este un set de actiuni care se executa in urma schimbarii codului sursa. Aceste actiuni sunt definite intr-un fisier de configurare si sunt executate pe un runner (un VM sau un container) care ruleaza comenzile din fisier.

Ideea de CI/CD este strans legata de ideea de release, in sensul ca CI/CD-ul este componenta dintr-un proiect care "duce" codul in productie.

Un release in productie este versiunea finala a aplicatiei care este livrata la utilizatorii reali.

Inainte de un release, codul trece prin mai multe medii de dezvoltare:
- Development (dev) - mediul in care codul se dezvolta si se testeaza preliminar.
- Staging - mediul care simuleaza cat mai bine productie, mediul in care se fac teste de integrare cu celelalte componente ale sistemului (ex: baze de date, API-uri externe, etc.)
- Production (prod) - mediul in care codul este livrat utilizatorilor reali.

Ca sa avem release-uri fara emotii, trebuie sa avem in vedere urmatoarele aspecte:
* Reproductibilitatea - release-urile trebuie sa aiba niste pasi clari de urmat care sa fie reproductibili pentru orice mediu (development, staging, production) si orice versiune a codului.
* Downtime cat mai mic, ideal deloc - schimbarile de configuratie sau deploymenturile ar trebui sa nu aiba downtime deloc, aplicatia trebuie sa fie in picioare pe parcursul release-ului.
* Automated releases - automatizarea reduce eroare umana, pasii manuali de facut intr-un release (humanly) error-prone.
* Support rollbacks - daca sistemul crapa (si va crapa) trebuie sa avem un mecanism cat mai rapid sa-l aducem la starea stabila de dinainte. In productie, in cazul unui outage sau a unui bug, se face revert (rollback) la versiunea anterioara stabila. Debuggingul, reproducerea problemei si fixul se fac in mediul de development si dupa testare se face din nou release la noua versiune fixata.

Tooluri de CI/CD populare sunt:
* GitHub Actions - managed, out-of-the-box service, usor de folosit dintr-un repository de GitHub
* Gitlab Action - managed, out-of-the-box service, usor de folosit dintr-un repository de Gitlab
* Jenkins - self-hosted, open-source tool, ofera CI/CD pentru orice tip de aplicatie, folosit foarte des in industrie, heavyweight
* Argo - self-hosted, usor de integrat in Kubernetes, care ofera CI/CD pentru aplicatii containerizate

## CI/CD Pipeline stages

Etapele cele mai des intalnite ale unui pipeline de CI/CD sunt:

- Copierea codului sursa (i.e. source code checkout)
  - codul este preluat din repository si este copiat in VM-ul/containerul in care se va executa pipeline-ul de CI/CD.
- Compilarea aplicatiei
  - codul sursa este compilat/builduit pentru a obtine binarul sau . In pasul asta se triaza erorile de compilare si sintaxa.
- Testarea automatate (cu teste unitare, de integrare, etc.)
  - codul este testat in mod automat. In pasul asta se triaza bugurile de logica sau de functionalitate.
- Publicarea artefactelor (imagini de docker, pachete, etc.)
  - dupa validare, aplicatia este publicata sub forma in care utilizatorii reali beneficiaza de ea (imagine de docker, o noua versiune de executabil, o noua versiune de biblioteca etc.)
- Deploymentul aplicatiei in productie
  - daca este necesar - pentru o biblioteca sau un utilitar nu este necesar deploymentul in productie, ci doar publicarea unei noi versiuni

## Use cases pentru CI/CD

- Rularea de lintere sau a checkere:
  - de exemplu, in dezvoltarea kernelului Linux, se folosește`checkpatch.pl` pentru a verifica dacă se respectă convențiile de stil
- Rularea scripturilor de configurare
  - de exemplu, pentru aplicatiile web de multe ori e necesar sa updatam tabelele din baza de date (migrarea bazei de date)
- Compilarea codului
- Builduirea imaginilor de docker
- Testarea automatate (cu teste unitare, de integrare, etc.)

## Demo 01 - Github Actions Pipeline

Concepte de interes aici: Workflows, Jobs, Steps, Triggers, Debugging, GitHub Marketplace, GHCR

Anatomia unui workflow GitHub Actions:
- Workflow - un set de actiuni care se executa la un anumit eveniment (ex: push, pull request, etc.)
- Job - un set de actiuni care se executa pe un anumit runner (ex: ubuntu-latest, windows-latest, etc.)
- Step - o actiune care se executa in cadrul unui job (ex: checkout, run, etc.)

```yaml
name: CI/CD Pipeline
on:
  push:
    branches:
      - main
jobs:
    build:
        runs-on: ubuntu-latest
        steps:
        - name: Checkout code
            uses: actions/checkout@v4
        - name: Set up Go
            uses: actions/setup-go@v4
        - name: Install dependencies
            run: go mod download
        - name: Run tests
            run: go test ./...
        - name: Build
            run: go build -o myapp
```

Am definit un workflow care se va rula la fiecare push pe branch-ul main.

Repository: [https://github.com/andreia-oca/go-simple-webserver]

Avantajele folosirii GitHub Actions:
- usor de integrat intr-un repository de GitHub - pasii unui pipeline sunt descrisi intr-un yaml si GitHub se ocupa sa creeze mediul (containerele) pe care se ruleaza pipeline-urile.
- managed solution, nu trebuie sa setam noi infrastructura pentru a porni VM-urile pe care se ruleaza pipeline-urile
- integrat cu alte tooluri din ecosistemul de GitHub (GHCR, GitHub Secrets, etc.)

Dezavantajele folosirii GitHub Actions:
- dificil de facut debugging pe pipeline-uri complexe pentru ca nu putem simula usor mediul local
- nu avem full control asupra mediului (de exemplu, multa vreme nu au avut support pentru ARM runners, deci nu puteam compila nativ aplicatii pentru ARM)

Totusi, codul nostru nu a ajuns inca in productie, doar am creat un release cu artefactele necesare. In continuare, o sa vorbim despre cum putem sa facem deploymentul aplicatiei noastre in productie.

## Deployment in K8s cu Argo

## Demo 02 - Argo CD

Ca prerequisites, cream un cluster de kubernetes local cu `kind`:

```bash
kind create cluster

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
argo get all -n argocd
```

Pentru a crea un proiect in Argo CD putem fie sa folosim `argocd create` fie sa cream un manifest yaml si sa-l aplicam in clusterul nostru de K8s:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: go-simple-webserver
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/andreia-oca/go-simple-webserver.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

Ca sa putem sa ne conectam la Argo CD, trebuie sa configuram port-forwarding la serviciul Argo CD:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Pentru login in Argo CD, trebuie sa ne conectam la serviciul Argo CD folosind `kubectl port-forward` si sa folosim credentialele de admin generate automat de Argo CD:
```bash
password=$(kubectl get secret argocd-initial-admin-secret -n argocd   -o jsonpath="{.data.password}" | base64 -d && echo)
argocd login localhost:8080 --username admin --password $password --insecure
```

Comenzi pentru a verifica starea proiectului si a aplicatiei create anterior:
```bash
argocd proj list
argocd app list
argocd app resources go-simple-webserver
argocd app get go-simple-webserver
```

In snippetul de cod de mai jos, cream un manifest pentru un deployment plecand de la o imagine de Docker (`ghcr.io/andreia-oca/go-simple-webserver:latest`) cu 2 replicas.

```bash
export USERNAME=<github-username>
export REPO=<github-repo>
argocd app create go-simple-webserver \
  --repo https://github.com/$USERNAME/$REPO.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-simple-webserver
  labels:
    app: go-simple-webserver
spec:
  replicas: 2
  selector:
    matchLabels:
      app: go-simple-webserver
  template:
    metadata:
      labels:
        app: go-simple-webserver
    spec:
      containers:
        - name: webserver
          image: ghcr.io/andreia-oca/go-simple-webserver:latest
          ports:
            - containerPort: 8080
```

Nota: Argo ne ofera un dashboard in care putem monitoriza starea pipeline-urilor de deployment si starea podurilor din k8s de care Argo e responsabil.

Putem sa facem sync manual:

```bash
argocd app sync go-simple-webserver
```

Sau putem sa setam sync-ul automat (`syncPolicy`) in manifestul `application.yaml`:

```yaml
  syncPolicy:
    automated:
      # prune = true - remove resources that are no longer defined in `manifests`
      prune: true
      # selfHeal = true - re-sync the application if it is out of sync
      selfHeal: true
```

## Strategii de deployment

Cand vine vorba de deployment efectiv, probabil cel mai important aspecte este stabilitatea si fara downtime. Pentru asta, exista mai multe strategii pe care le putem folosi.

- Canary/Rollout Deployment:
    - Deploymentul se face in etape, incepand cu un numar mic de utilizatori (sau regiuni) si crescand treptat pana la 100% din utilizatori.
    - Strategia este utile pentru a monitoriza stabilitatea aplicatiei in productie (la scala mare) fara a afecta toti utilizatorii deodata
    - In cazul unui outage (resurse insuficiente, bug-uri, etc.) doar o mica parte din utilizatori sunt afectati
- Blue/Green Deployment
    - Blue/Green deployment este o strategie prin care ne asiguram ca nu exista downtime in timpul deploymentului.
    - Deploymentul se face in urmatoarele etape:
        1. Se creeaza un nou deployment (green) cu versiunea noua a aplicatiei si se pornesc podurile corespunzatoare in Kubernetes (Se asteapta ca podurile green sa raspunda la health checks)
        2. Se schimba traficul de la blue (deploymentul vechi) la green - pasul asta se mai numeste si promovarea deploymentului
        3. Dupa ce toate requesturile catre blue au fost terminate si traficul este mutat catre green, podurile blue sunt oprite
- Rollbacks
    - Rollbackul este procesul de a aduce aplicatia la o stare anterioara stabila in cazul in care noul deployment nu functioneaza corect sau in care a apaurt un outage in productie
    - Rollbackul se poate face prin:
        1. Schimbarea traficului inapoi la deploymentul vechi (blue) in cazul unui blue/green deployment
        2. Folosind un tool de CI/CD care sa faca rollback automat
    - Rollbackul este important pentru a reduce downtime-ul si a asigura stabilitatea aplicatiei in productie

## Demo 03 - Rollouts deployments

In snippetul de cod de mai jos se configureaza un rollout (sau canary) deployment.
- `setWeight` - reprezinta procentul de trafic redirectionat catre noile poduri
- `pause` - este timpul dupa care se va face trece la urmatoarul pas (urmatorul procentaj) din deployment

```bash
kubectl create namespace argo-rollouts
kubectl apply -f -n argo-rollouts https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/install.yaml
```

Deployment-ul este gata cand 100% din trafic a fost redirectionat catre noua versiune a aplicatiei.

```yaml
spec:
  replicas: 2
  strategy:
    # Canary strategy
    canary:
        - setWeight: 25
        - pause: {duration: 30s}
        - setWeight: 50
        - pause: {duration: 30s}
        - setWeight: 100
```

Ca sa monitorizam rollout-ul:

```bash
argo-rollouts get rollout go-simple-webserver --watch
```

Ca sa promovam manual rollout-ul:

```bash
argo-rollouts promote go-simple-webserver
```

## Keywords

- CI/CD
- Continuous Integration/Continuous Delivery
- Release
- Canary deployments
- Blue/Green deployments
- Rollbacks
- Github Actions
- Argo
