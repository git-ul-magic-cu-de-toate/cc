# Cursul 04

Ca să recapitulăm puțin de la cursul anterior ce am făcut. Data trecută am
interacționat pentru prima oară cu Kubernetes. Vom folosi Kubernetes, dar exista
și alte sisteme, pentru a gestiona în mod automat, folosind aplicații care
rulează. Kubernetes ne permite să pornim mai multe containere, să le conectăm
între ele, să le punem limite, să le scalăm și să le distribuim pe mai multe
noduri în funcție de cât de folosite sunt și de numărul de replici pe care vrem
să îl menținem.

Am văzut la cursul anterior cum putem să pornim un container. Avem două metode:
folosind o comandă, cum ar fi `kubectl create deployment` pentru a crea un
deployment. Acest deployment este o aplicație pe care o rulăm în cluster.
Problema când generăm un Deployment de mână, atunci când pornim o aplicație, sau
un set de aplicații, de mână este că trebuie intervenție manuală din partea unui
operator. Cursul anterior spuneam că faptul un avantaj al Kubernetes este că
putem folosi utilizare de automatizare.

Pentru a nu scrie comenzi de mână, putem să definim Deploymenturi în fișiere
numite manifesturi. Avantajul la a folosi fișiere este faptul că acestea sunt
repozitabile, pot să le încarc într-un repository de Git, pot să folosesc blame,
rollback, cherrypick pe aceste fișiere. Hai să ne uităm la taxonomia unui astfel
de fișier.

```
$ cat nextcloud.yaml
---
# Nextcloud Deployment with SQLite
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  labels:
    app: nextcloud
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: nextcloud:latest
```

Un fișier manifest pentru un deployment va conține metadata, date despre date.
În cazul acesta noi definim numele deploymentului și definim și labeluri, sau
etichete pentru deployment. Etichetele sunt un mecanism care îmi permite
selectarea obiectelor care au legătură cu aplicația.

Pentru a aplica unui manifest, adică generarea obiectelor din deployment, avem
două comenzi pe care le-am rulat și în laborator: `kubectl create -f` și
`kubectl apply -f`. Diferența dintre cele două comenzi este: `create` generează
un obiect, dar dacă este nevoie doar să aplice modificări la unul existent, nu
le aplică, între-timp ce `apply` generează obiectele și aplică modificări asupra
obiectelor existente, dacă este cazul.

Observăm că au fost generate obiectele. Avem acum o aplicație deployată, dar cum
o accesăm? Fiecare pod din Kubernetes are asociat un IP. Ca să vedem asta putem
descrie un pod și să căutăm IP-ul.

```
student@demo-sw:~$ kubectl describe pods -l app=nextcloud | grep IP:
IP:               10.244.0.43
  IP:           10.244.0.43
```

Observăm că am folosit opțiunea `-l app=nextcloud`, care face selecția conform
unui filtru. În cazul de față, comanda `kubectl describe pods` afișează podurile
care au labelul `app` setat la valoarea `nextcloud`.

Ștergând Pod-ul și regenerând-ul, observăm că IP-ul acestuia s-a modificat:

```
student@demo-sw:~$ kubectl delete pods -l app=nextcloud
pod "nextcloud-765fb446cd-hpv4l" deleted
student@demo-sw:~$ kubectl describe pods -l app=nextcloud | grep IP
IP:               10.244.0.81
IPs:
  IP:           10.244.0.81
```


### Conectarea la un Deployment


Fiecare pod într-un deployment de Kubernetes are un IP. Într-un cluster de
Kubernetes fără politici de securitate implementate, toate podurile pot să se
conecteze între ele folosind IP-ul pe care îl identifică. Problema în această
situație este că podurile sunt efemere și așa sunt și IP-urile lor. Dacă eu
opresc un pod și îl pornesc iar, acest pod va avea un alt IP. Cum pot să
identific eu în mod unic un pod, să mă conectez la el dacă la fiecare restart
sau redeploy al serviciului se schimbă IP-ul?

### Definirea serviciilor

Există obiecte numite servicii care se ocupă de această funcționalitate. Acestea
expun un deployment, un set de poduri, către clusterul de
kubernetes și chiar și către exterior, dacă îl configurăm ca atare.

Vom defini un obiect de tipul Service, care o să expună podurile. Pentru primul
exemplu putem să expunem serviciul doar intern, în cadrul clusterului
Kubernetes. Pentru a genera un serviciu vom folosi comanda următoare pentru a
expune deploymentul `nextcloud`:

```
$ kubectl expose deployment nextcloud --port 80
```

Această comandă va genera un serviciu căruia îi va fi asociat un IP și un port.
Putem să ne gândim la un Service ca la o entitate de nivel 4 din stiva OSI.

Acum în linie de comandă într-un pod putem să facem o cerere folosind cluster
IP-ul, care va rămâne static, și vom accesa serverul de Nextcloud prin IP-ul de
cluster ca în exemplul de mai jos:
```
$ kubectl get services
name         type        cluster-ip       external-ip   port(s)        age
nextcloud    clusterip   10.108.49.212    <none>        80/tcp         43m
$ student@demo-sw:~$ kubectl exec -it ubuntu-pod -- curl 10.108.49.212
<!doctype html>
<..>
```

Observăm că am putut să ne conectăm la server folosind adresa sa "statică".
Un alt mod de a ne conecta, acum pentru că avem un server, putem să folosim
numele serviciului. Asta ne ajută ca atunci când configurăm un server și vrem să
avem configurări "statice", ca o rețetă, să folosim doar numele.

```
$ kubectl delete pods -o label=nextcloud
name         type        cluster-ip       external-ip   port(s)        age
nextcloud    clusterip   10.108.49.212    <none>        80/tcp         43m
student@demo-sw:~$ kubectl exec -it ubuntu-pod -- curl nextcloud
<!doctype html>
<..>
```

Observați că folosim un pod deja existent pentru rularea comenzilor de
verificare. Conectivitatea folosind servicii definite ca mai sus este posibilă
doar între poduri și între poduri și nodul fizic. Podul `ubuntu-pod` are acces
la podul din deploymentul de nextcloud.

Putem să verificăm dacă această adresă chiar este statică. Vom șterge podul să
vedem ce se întâmplă.

TODO
```
$ kubectl delete pods -o label=nextcloud
$ student@demo-sw:~$ kubectl exec -it ubuntu-pod -- curl 10.108.49.212
<!doctype html>
<..>
```

#### Expunerea serviciului în afara clusterului

Până acum am făcut conexiuni doar între obiecte (Pod-uri, Service-uri) din
cadrul aceluiași cluster de Kubernetes, nu ne-am expus serviciul în exteriorul
clusterului.  Hai să ștergem serviciul și să facem un serviciu care permite
conexiuni din exterior. Pentru a face conexiunea din exterior, vom avea nevoie
să definim un nou tip de serviciu, NodePort, care să deschidă un port pe noduri.
Acest tip de serviciu deschide acest port pe toate nodurile prin mecanismul
intern de networking al Kubernetes, indiferent dacă podul în sine este pornit pe
acel nod.

Acum mă pot conecta la serviciu folosind adresa IP a nodului, pe care o pot lua
din configurile de la Kubernetes folosind comanda `kubectl get nodes -o wide` și
portul pe care l-am cerut sau care mi-a fost alocat.i Care este problema aici?
Eu în momentul ăsta am nevoie să cunosc adresa să o iau de undeva, să o dau
cuiva. Nu așa funcționează serverele în viața reală. Putem să avem servicii de
genul ăsta în infrastructuri de test, dar noi avem nevoie de un load balancer în
față care să îmi redirecteze traficul din exterior către serverele astea.

```
$ kubectl get nodes -o wide
$ curl TOODO
```

Din fericire, infrastructurile cloud chiar ne oferă o alternativă pentru asta.
În sisteme cloud publice și chiar și în cele private noi putem să setăm
Kubernetes să genereze load balancere care au adrese publice, adrese accesibile
din afara clusterului. Astfel putem să configurăm servicii care folosesc
care au acces in înternet.

În ce situații vom vrea sa folosim vreodată NodePort-uri în cazul ăsta. Atunci
când avem infrastructuri care nu vrem să fie accesibile din exterior, dar pe
care vrem să le accesăm dacă avem acces la noduri, luați de exemplu un dashboard
de monitorizare. Un alt use case este atunci când nu avem acces la un set de
adrese IP publice. Nu ne dă nimeni un /16 să ne tot alocăm
adrese IP în Internet și dacă nu avem un load balancer pe care să îl configureze
altcineva, nu avem cum să alocăm aceste adrese IP pentru servicii.

#### Folosirea serviciilor LoadBalancer

În cazul unui serviciu cloud, putem să cerem o alocare a unui IP generând un
serviciu de tip LoadBalancer. Aceste servicii au integrări fie folosind un
serviciu din cadrul kubernetes fie servicii externe cum ar fi F5, și pot aloca
IP-uri externe care vor redirecta conexiuni către clusterul de Kubernetes și
către serviciul pe care noi l-am generat.

Observăm mai jos definiția unui serviciu de tip LoadBalance. Diferența dintre un
serviciu de tip ClusetrIP și un serviciu de tip LoadBalancer este faptul că a
fost alocare un ExternalIP vizibil și din afara clusterului. Am folosit comanda
ping pentru a verifica conectivitatea la acest nod.

TODO:
```
$ cat nextcloud-lb.yaml
$ kubectl get services
$ curl <service-ip>
```

#### Kubernetes Ingress

Totuși, în multe cazuri limitarea IP-urilor publice nu este o problemă. Dacă
avem doar servicii web de hostat, avem doar trafic HTTP, putem să ne folosim
doar o adresă IP publică. Clusterele de Kubernetes oferă posibilitatea folosirii
unui Ingress Controller. Acesta este un LoadBalancer gestionat de către
Kubernetes care își alocă o adresă IP pentru el, preia conexiuni și le trimite
mai departe către servicii. Conexiunea din exterior în loc să vină pe IP-ul
public alocat serviciului, va veni pe adresa publică a controllerului și pe baza
hostnameului pentru care a venit conexiunea, aceasta va fi redirectată către
serviciul corect.

Obiectul care controlează acest comportament numește un Ingress. El este bazat
un set de servicii nginx care preiau conexiunile. Controllerele de nginx sunt
configurate de către Kubernetes pentru a primi conexiunile. Noi trebuie să
configurăm doar rutele dinspre nginx spre serviciu.

TODO:
```
$ kubectl get services
$ cat blue-ingress.yaml
$ kubectl apply -f blue-ingress.yaml
$ kubectl get ingress
$ curl colors.yaml
```

Mai departe putem să ne folosim de funcționalități avansate cum ar fi
cert-manager, care se poate integra cu Ingress-ul pentru generarea automată a
certificatelor atunci când acestea sunt pe cale de a expira.

Este de avut în vedere că obiectele Ingress sunt folosite atât pentru definirea
unei rute de acces la un serviciu, acestea se folosesc de un serviciu deja
definit în cadrul unui cluster. În exemplul de mai sus serviciul `blue-service`
există deja și este folosit pentru a selecta unde vor fi trimise conexiunile.

### Scalarea automată a deploymenturilor

Am văzut cum putem să dăm acces din exterior unei aplicații, am tot auzit că
putem să scalăm componentele, dar noi până acum nu am văzut asta în practică.
Cum putem să facem astfel încât un deployment chiar să scaleze?
Putem să facem noi scalarea de manuală a unui deployment. Pentru a face scalarea de
mână folosind `kubectl scale deployment <nume> --replicas <număr replici>`.

În același timp putem să configurăm și în cadrul unui manifest numărul de
replici pe care îl va avea un deployment folosind cuvântul cheie `replicas` ca
în exemplul de mai jos. Scalarea statică a serviciilor va permite mărirea
capacității unui serviciu și chiar garantarea unui grad de disponibilitate a
aplicației.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  labels:
    app: nextcloud
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: nextcloud:latest
```

Sistemele cloud permit taxarea pe măsura uzului de resurse, indiferent dacă
acestea sunt folosite în modul "idle", sau în mod util pentru satisfacerea
cererilor din partea clienților. Scalarea automată vine ca o soluție pentru
problema costurilor mari pentru menținerea unei alocări constante mari de
poduri.

Ca parte a procesului de gestiune a resurselor, podurile pot cere o alocare de
resurse și acestea pot impune și limite în alocarea resurselor. În exemplul de
mai jos este prezentat un astfel deployment.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busyhttp
  labels:
    app: busyhttp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: busyhttp
  template:
    metadata:
      labels:
        app: busyhttp
    spec:
      containers:
      - name: busyhttp
        image: jpetazzo/busyhttp
        resources:
          limits:
            cpu: 200m
          requests:
            cpu: 100m

        ports:
        - containerPort: 80
```

Secțiunea `resources` cere o alocare de 10% dintr-un CPU și impune o limită de
0.2% dintr-un CPU. Aceste limite sunt impuse de către kubelet folosind cgroups,
folosite în procesul de programare a resurselor pe noduri și agregate pentru a
lua decizii despre scalarea unui deployment.

Putem folosi comanda `kubectl top pods` pentru a urmări resursele folosite în
namespace:
```
student@demo-sw:~$ kubectl top pods
NAME                         CPU(cores)   MEMORY(bytes)
blue-5c986bd7bf-6cxzn        1m           7Mi
busyhttp-69ddc78f9c-dxhp2    1m           28Mi
hello-node-c74958b5d-q4q5m   1m           8Mi
my-lamp-site                 2m           455Mi
nextcloud-765fb446cd-hpv4l   1m           87Mi
ubuntu-pod                   0m           14Mi
```

Pentru scalarea resurselor în cadrul unui deployment, este necesară folosirea
unui obiect care să gestioneze numărul de replici și să îl scaleze în cazul în
care sunt îndeplinite un set de condiții. Pentru scalarea numărului de poduri
vom folosi un HorizontalPodAutoscaler (HPA), care va monitoriza după CPU-ul
folosit și va scala numărul de poduri dintr-un deployment.

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: busyhttp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: busyhttp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 20
```

În exemplul de mai sus am definit un HPA cu numele `busyhttp` care va scala
numărul de replici între o replică și 10 replici în funcție de utilizarea medie
a CPU-urilor. Acesta va face o medie a CPU-ului folosit pe toate podurile din
deployment și va scala numărul de moduri cu un factor determinat după formula
următoare: `ceil(currentReplicas * (currentCPUValue/desiredCPUValue)`.
