# Cursul 5


## Introducere

Kubernetes este un orchestrator de containere care oferă o interfața facila pentru crearea, scalare și managementul aplicațiilor în mod containerizat.

Un aspect esențial al acestui proces este izolarea și securizarea aplicațiilor care rulează într-un cluster. În mod implicit, în Kubernetes, majoritatea resurselor sunt accesibile între ele și nu există restricții foarte stricte asupra comunicării între poduri sau a consumului de resurse

Este responsabilitatea developerului/sysadminului să asigure izolarea și securitatea între aplicațiile care rulează în interiorul clusterului.

În cursul acesta vom vedea care sunt mecanismele de izolare disponibile în k8s și cum le putem folosi pentru a asigura un mediu sigur pentru aplicațiile noastre.

## Izolarea resurselor in K8s

Kubernetes pune la dispoziție diverse mecanisme de izolare și control:

* `cgroups` - pentru controlul resurselor de tip CPU, memory, I/O usage la nivel de container.
* `namespaces` - pentru izolarea proceselor si sistemelor de fisiere
* `network policies` - pentru filtrarea traficului de retea
* `RBAC (Role-based access-control)` - pentru controlul accesului la resursele din cluster bazat pe roluri

### cgroups - limitarea resurselor la nivel de container

`cgroups` este un mecanism de control al resurselor "primitive" (cpu, memory, I/O usage) la nivel de container.

Limitarea resurselor la nivel de container este esentiala pentru a preveni ca un container sa consume toate resursele sistemului si sa afecteze celelalte poduri sau stabilitatea clusterului.

`cgroups` este implementat la nivel de kernel de Linux astfel incat poate fi folosit in orice mediu care ruleaza peste Linux (VM, container sau pod). Acest feature este expus in k8s prin intermediul runtime-ului de containere (ex: `containerd`, `cri-o`). In mod implicit, in k8s fiecare container are un `cgroup` asociat care limiteaza resursele pe care le poate consuma.

#### Demo 01 - `cgroups`

Pornim un cluster local cu `kind`:

```bash
kind create cluster
```

Ca sa limitam resursele unui container, putem folosi `resources` in manifestul deployment-ului:

```yaml
    spec:
      containers:
      - name: webserver
        image: nginx
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m" # 250 millicores = 0.25 vCPU
          limits:
            memory: "128Mi"
            cpu: "500m" # 500 millicores = 0.5 vCPU
```

`resources.requests` - specifica resursele minime pe care k8s le garanteaza pentru rularea podului.
`resources.limits` - specifica resursele maxime pe care podul le poate folosi.

Putem investiga resursele (`requests`/`limits`) ale containerului cu urmatoarea comanda:

```bash
kubectl get pod webserver -o json | jq '.spec.containers[].resources'
```

Pentru a investiga cum se coreleaza `resources.requests`/`limits` cu `cgroups`, putem folosi `crictl` pentru a inspecta un container din cluster direct din control-plane. `crictl` este un tool care ne permite sa inspectam containerele care ruleaza in cluster (si este similar cu `docker`).


Prima oara ne conectam direct la control-plane:

```bash
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED       STATUS       PORTS                       NAMES
333ae077ba99   kindest/node:v1.32.2   "/usr/local/bin/entr…"   5 hours ago   Up 5 hours   127.0.0.1:40113->6443/tcp   kind-control-plane
```

```bash
docker exec -it kind-control-plane bash
```

Si de aici putem folosi `crictl` pentru a inspecta containerele care ruleaza in cluster:

```bash
$ crictl ps                      default
0fec161eb3923       53a18edff8091       30 minutes ago      Running             webserver                 0                   6fed41d9e8a8f       webserver                                    default
...
```

```bash
$ crictl inspect <container-id> | jq .info.runtimeSpec.linux.resources
{
  "cpu": {
    "period": 100000, # microseconds -> 100ms
    "quota": 50000, # microseconds -> 50ms => 50% of the CPU
    "shares": 256 # shares help to prioritize the CPU usage
  },
  "memory": {
    "limit": 134217728 # 128MiB
  }
}
```

### Namespaces

`namespaces` asigura separarea logica intre obiectele din cadrul unui cluster - pods, services, deployments, config maps, etc.

Prin utilizarea mai multor namespaces putem organiza mai bine mediile de dezvoltare, de testare și de producție sau putem izola echipele și clienții diferiți care folosesc același cluster. Astfel, fiecare namespace poate avea propriile resurse și propriile politici de acces.

Cazuri in care se folosesc `namespaces`:

* izolarea resurselor intre medii - development, staging, production - pentru a evita ca resursele dintr-un mediu sa afecteze resursele din alt mediu
* izolarea resurselor intre componentele unei aplicatii - frontend, backend, database.
* multi-tenancy - izolarea resurselor intre echipele unei organizatii sau intre clientii unei companii (e.g. Openstack e un mediu multi-tenant - proiecte izolate pentru diverse materii RL, CC, etc)

### Demo 02 - namespaces

In acest demo, vom crea două namespace-uri pentru a izola resursele între două grupuri de poduri: `client-1-ns` și `client-2-ns`.

Pentru a crea resurse intr-un anumit namespace, putem folosi `kubectl` cu flag-ul `-n <namespace-name>` sau putem sa il mentionam in manifestul resursei:

```yaml
apiVersion: v1
kind: <resource>
metadata:
  name: <name>
  namespace: <namespace-name>
```

Cand lucram cu mai multe namespace-uri, este important sa ne asiguram ca resursele sunt create in namespace-ul corect.
Putem verifica namespace-urile existente in cluster cu comanda:

```bash
kubectl get namespaces
```

Pentru a schimba mai usor namespace-ul curent pe care il folosim putem folosi contextul curent din `kubectl`:

```bash
kubectl config get-contexts
kubectl config set-context --current --namespace=<namespace-name>
```

### Demo 03 - conectarea intre poduri din namespace-uri diferite

In mod implicit, Kubernetes permite comunicarea între poduri din namespace-uri diferite.

```bash
kubectl get pods -A
```

```bash
kubectl exec -it ping-8644c6bf7d-slkkr -- curl http://ping.client-1-ns.svc.cluster.local
```

Nota: `ping.client-1-ns.svc.cluster.local` este solved de `kube-dns` si reprezinta adresa IP a podului `ping` din namespace-ul `client-1-ns`.

* `ping` este un `Service` care expune podul `ping` la exterior pe portul 30001
* `client-1-ns` este namespace-ul
* `svc` indica ca este un `Service`
* `cluster.local` este suffix-ul default pentru resursele din cluster

Pentru a limita accesul intre poduri din namespace-uri diferite, se poate folosi `network policies`.

### Network policies

`network policies` este un mecanism de izolare a traficului de retea in k8s.

Cazuri in care network policies sunt folosite:

* izolarea traficului intre namespace-uri
* izolarea traficului intre poduri
* restrictionarea accesului extern la poduri

Un network policy este o resursa k8s care specifica restrictionarea sau permiterea traficul de retea intre poduri si namespace-uri. În mod implicit, într-un cluster Kubernetes, dacă nu există niciun `NetworkPolicy` aplicat, tot traficul este permis — atât trafic de intrare (ingress), cât și de ieșire (egress). Asta înseamnă că podurile pot comunica liber între ele și pot accesa internetul, în lipsa unor politici explicite.

Un network policy contine o lista de reguli care specifica:

* Selectorul - `podSelector` - care poduri sunt afectate de policy.
* Tipul de policy - `policyTypes` - ingress, egress sau ambele.
* Regulile de **ingress** - trafic de intrare - care poduri sau surse externe sunt permise sa comunice cu podurile selectate.
* Regulile de **egress** - trafic de iesire - care poduri sau destinatii externe sunt permise sa comunice cu podurile selectate.


Anatomia unui `NetworkPolicy`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <name>
  namespace: <namespace-name>
spec:
  # podSelector - defines which pods are affected by this policy
  # To select all pods in the namespace, use an empty selector: `{}`
  podSelector:
    # matchLabels - selector for the pods
    matchLabels:
      <label-key>: <label-value>
  # policyTypes - ingress, egress
  policyTypes:
  - Ingress
  - Egress
  # ingress - rules for incoming traffic
  ingress:
  - from:
    - podSelector:
        matchLabels:
          <label-key>: <label-value>
    ports:
    - protocol: TCP
      port: <port-number>
  # egress - rules for outgoing traffic
  egress:
  - to:
    - podSelector:
        matchLabels:
          <label-key>: <label-value>
    ports:
    - protocol: TCP
      port: <port-number>
```


De exemplu, un policy care restrictioneaza tot traficul de intrare (`ingress`) in namespace-ul `default`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-traffic
spec:
  # all pods from the default namespace are affected
  podSelector: {}
  # affects ingress and egress traffic
  policyTypes:
  - Ingress
  - Egress
  # the absence of ingress rules to allow traffic => deny all
```

Pe de alta parte, putem si sa permitem tot traficul de intrare (ingress) in namespace-ul `default`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  # all pods from the default namespace are affected
  podSelector: {}
  # affects ingress traffic
  policyTypes:
  - Ingress
  # the rule `ingress: - {}` matches all possible rules => allow all
  ingress:
  - {}
  # note: egress is not specified at all => denied
```

Note pentru clarificare:
* in absenta unor `NetworkPolicies`, tot traficul este permis. Odată ce există cel puțin o politică aplicata, traficul este blocat în mod implicit, cu excepția cazurilor în care este permis explicit prin reguli de `ingress` sau `egress`.
* Daca un selector este gol (`{}`) inseamna ca toate podurile/regulile sunt afectate de politica respectiva.
* lipsa unor reguli de `ingress` sau `egress` inseamna ca tot traficul este restrictionat. De exemplu, daca nu exista reguli de `ingress`, toate conexiunile de intrare sunt restrictionate.
* `NetworkPolicies` sunt aditive - daca exista mai multe politici aplicate in acelasi `namespace`, toate regulile sunt combinate. Traficul este permis dacă cel puțin una dintre politicile setate permite acel tip de conexiune. Nu există reguli explicite de deny – blocarea traficului se întâmplă doar în absența unei reguli care să îl permită. De exemplu, dacă un `NetworkPolicy` permite traficul pe podul `ping` pe portul `8080`, iar altul interzice traficul pe podul `ping` pe orice port, atunci traficul pe portul `8080` va fi permis, iar restul va fi interzis.

O alta clasificare a traficului de retea in k8s este:

* **North-South** - intre poduri si exteriorul clusterului. De exemplu, utilizatori care accesează aplicația din afara clusterului sau servicii din cluster care apelează resurse externe.
* **East-West** - intre poduri din acelasi namespace sau din namespace-uri diferite. De exemplu, servicii care comunica intre ele.

### Demo 04 - restrictionarea accesului intre namespace-uri

Ca sa restrictionam accesul intre namespace-uri, putem folosi `NetworkPolicies` pentru a permite sau interzice traficul de retea intre poduri din namespace-uri diferite:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  # Name of the NetworkPolicy
  name: client-1-ns-policy
  # Namespace where the policy is applied
  namespace: client-1-ns
spec:
  podSelector:
    matchLabels:
      # Apply this policy to pods with label app=webserver
      app: webserver
  policyTypes:
  # This policy affects incoming traffic
  - Ingress
  # This policy affects outgoing traffic
  - Egress
  ingress:
  - from:
    # Use a namespace selector
    - namespaceSelector:
        matchLabels:
          # Allow ingress traffic from pods in namespaces labeled with name=client-2-ns
          name: client-2-ns
    ports:
    - protocol: TCP
      # Only allow traffic on TCP port 80
      port: 80
  egress:
  # Allow all egress
  - {}
```

Ca sa testam daca `NetworkPolicy` a fost aplicat corect, putem folosi `curl` pentru a verifica conectivitatea intre poduri din namespace-uri diferite:

```bash
kubectl exec -it curl -n  client-2-ns -- curl ping-service.client-1-ns.svc.cluster.local
```

### Demo 05 - restrictionarea accesului intre orice poduri in namespace

Ca sa restrictionam accesul intre orice poduri dintr-un namespace, putem folosi `NetworkPolicies` pentru a permite sau interzice traficul de retea intre poduri din acelasi namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-pods
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Role Based Access Control (RBAC)

RBAC este un mecanism de control al accesului în Kubernetes care permite definirea drepturilor de acces pentru utilizatori și servicii, în funcție de rolurile acestora.

Cazuri în care RBAC este folosit:

* definirea unor roluri clare pentru diferite tipuri de utilizatori (ex: developer vs sysadmin)
* implementarea unui mediu zero-trust, în care fiecare actor are acces doar la ceea ce îi este necesar - least privilege principle
* restricționarea accesului pentru service accounts sau aplicații care rulează în cluster

Un RBAC policy este compus din mai multe resurse Kubernetes:

* `Role` sau `ClusterRole` – definește ce acțiuni pot fi făcute pe ce resurse (ex: GET pe pods, LIST pe secrets etc.).
* `RoleBinding` sau `ClusterRoleBinding` – atașează un rol unui `ServiceAccount`.

`RoleBinding` și `ClusterRoleBinding` sunt resurse care leagă un `Role` sau un `ClusterRole` de un utilizator sau de un service account. Acestea definesc cine poate accesa ce resurse și ce acțiuni pot fi efectuate asupra acestora.

Diferența dintre `Role` și `ClusterRole` - Role – se aplică într-un singur namespace, pe cand ClusterRole – se aplică la nivel de cluster (toate namespace-urile).

Diferența dintre `RoleBinding` și `ClusterRoleBinding` - RoleBinding – leagă un Role (sau un ClusterRole) de un utilizator într-un namespace, pe cand, ClusterRoleBinding – leagă un ClusterRole de un utilizator la nivel de cluster

Un `ServiceAccount` în Kubernetes este folosit de podurile care rulează în cluster pentru a interacționa cu API-ul Kubernetes.

`ServiceAccount` defineste identitatea aplicațiilor (podurilor) care rulează în Kubernetes. Atunci când o aplicație (care rulează într-un pod) trebuie să interacționeze cu API-ul Kubernetes, folosește un service account pentru a obține acces la resursele Kubernetes. În mod implicit, fiecare pod primește un `ServiceAccount` care îi oferă acces limitat la API-ul Kubernetes. Acest `ServiceAccount` este configurat automat de Kubernetes și include un token JWT, montat în container.


### Demo 06 - creare de roluri

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: client-1-ns
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["list", "get", "describe"]
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: client-1-ns
subjects:
- kind: User
  name: alice
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sysadmin
  namespace: client-1-ns
rules:
- apiGroups: [""]
  resources: ["pods", "deployments", "services"]
  verbs: ["create", "start", "delete"]
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sysadmin-binding
  namespace: client-1-ns
subjects:
- kind: User
  name: bob
roleRef:
  kind: Role
  name: sysadmin
  apiGroup: rbac.authorization.k8s.io
```

Cream service accounts pentru utilizatori ca sa putem genera tokens pentru ei:

```bash
kubectl create serviceaccount dev-sa -n default
kubectl create serviceaccount admin-sa -n default
```

Cream token-uri pentru utilizatori ca sa ne putem autentifica sa facem request-uri la API-ul Kubernetes:

```bash
DEV_TOKEN=$(kubectl -n default create token dev-sa)
ADMIN_TOKEN=$(kubectl -n default create token admin-sa)
```

```bash
CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

Facem request-uri la API-ul Kubernetes folosind token-urile generate mai sus:

```bash
curl -s -k -X POST $SERVER/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"Pod","metadata":{"name":"test-pod"},"spec":{"containers":[{"name":"busybox","image":"busybox","command":["sleep","3600"]}]}}'

curl -s -k -X POST $SERVER/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"Pod","metadata":{"name":"test-pod-admin"},"spec":{"containers":[{"name":"busybox","image":"busybox","command":["sleep","3600"]}]}}'
```

```bash
curl -s -k $SERVER/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $DEV_TOKEN"
```

## Keywords

* isolation
* cgroups
* namespaces
* network policies
* rbac - role based access control
* egress
* ingress
* multi-tenancy
