# Cursul 03

Dacă până acum am vorbit despre containere, tooluri pe care unele persoane le-au
mai folosit deja, astăzi am ajuns la un subiect care este destul de nou pentru
voi: cum folosim containere într-un mediu care să fie la nivel de producție.

Practic, care e diferența dintre ce am făcut până acum și ce vom face restul
semestrului?

Până acum noi am folosit containere într-un mod destul de hackish sau într-un
mod care se pretează testării într-un mediu local. Persoane mai rele ar putea
spune că ăsta este un mod de folosire studențesc care nu se aplică așa de ușor
la medii în care vrei să faci bani, unde uptime-ul contează, unde tu ești
judecat pentru fiabilitatea deploymentului, pentru cât de rezistent este acesta
la defecte.

Cum am făcut noi până acum? Am învățat cum să construim niște imagini de
container pentru a rula software, poate să fie el un web server, poate să fie un
serviciu scris de noi care comunică pe rețea, cum aveam python-container în
cadrul laboratorului.

Am învățat cum putem să pornim containere, cum să le expunem pe rețea și
implicit în internet. Pentru a putea face asta trebuie să le punem porturi.

Ca să avem persistență a datelor am învățat că trebuie să folosim bind mounts
sau volume, recomandarea fiind că ar trebui să folosim volume pentru
abstractizarea workloadului de gestiune a volumelor.

În ultimă fază, am trecut la curs printr-un exemplu de folosire a
docker-compose. Acesta este un mecanism care permite folosirea unei rețete
pentru pornirea unui set de containere care funcționează împreună.
Problema la folosirea docker compose este faptul că acesta funcționează pentru
deployment-uri single-node. Dacă vrem ceva mai mult, trebuie să aducem servicii
terțe ca să verifice.

Nu spune nimeni că nu există firme care folosesc doar Docker chior, docker
compose, dar sunt niște lucruri necesare pentru a putea ajunge la un mediu
stabil.

Care sunt niște cerințe pe care vrem noi să le satisfacem?
1) Deploymentul să fie cât mai automatizabil:
  * dacă moare un nod pe care eu am containerele, acestea să pornească pe un alt
    nod
  * să am un mod de a scala numărul de containerele pe care îl folosim după
    numărul de conexiuni
  * să automatizăm gestiunea certificatelor
2) Upgrading și rollback:
  * upgrading treptat și automat, poți să pornești un upgrade al unei resurse
    * poți schimba configul, poți schimba versiunea și acesta să se facă treptat
      în infrastructură
  * green-blue deployment, avem două deploymenturi ale aplicației, unul active
    și unul passive. Atunci când facem un upgrade îl facem pe clusterul pasiv.
    Atunci când se termină upgrade-ul în clusterul pasiv, schimbăm din load
    balancer clusterul către care se duc cererile clienților
3) GitOps:
  * în loc să facem upgrade-urile, deploymenturile acestea să fie făcute
    printr-un proces de CI/CD. Tu ai un pipeline care îți aplică modificările
    făcute în configurații
  * reduci timpul petrecut în procesul de upgrade
  * poți face patching mai ușor, mai rapid și dacă introduci și teste în
    pipeline asiguri o calitate mai mare a serviciilor/verificări contra
    regresiilor

Noi la acest curs vom folosi kubernetes. Probabil acesta este orchestratorul
despre care ați auzit și voi cele mai multe. Kubernetes este un proiect
OpenSource, pornit de către Google, care are ca scop orchestrarea containerelor.
El este scris în Go și a devenit în sine un standard în industrie.
Se mai prescurtază și drept K8s, pentru că este chiar un nume lung și complex

Cum arată arhitectura platformei? Ea este construită inerent pentru a rula
multi-node, și pentru a fi pluggable. Voi știți sau ați auzit de flavor-uri de
Kubernetes?

Avantajul în k8s este că putem să folosim diferite componente. Hai să le luăm pe
rând.

Master node-ul este nodul care controlează clusterul. Acesta ține 4 servicii
importante:
* API-ul este endpointul cu care noi comunicăm, atunci când noi trimitem o
  comandă, facem un request către clusterul de Kubernetes, aceasta este primită
  de către API server și după este trimisă mai departe
* etcd este key-value store, acesta este baza de date în care kubernetes își
  ține informația cum ar fi starea nodurilor, podurile, configurile, serviciile,
  name space-urile
* Controller gestionează starea clusterului, verifică starea obiectelor. Se
  asigură că clusterul dintre către o anumită stare sau că este în acea stare
* Scheduler preia cererile de la API server și le trimite către noduri pentru a
  fi procesate, de exemplu se asigură că sunt lansate procese, sunt creeate
  obiecte sau alte taskuri.

Pe lângă nodurile master, care au destul load, mai există și noduri worker al
căror rol este să ruleze containerele pe care noi le lansăm. Pe nodurile worker
avem serviciul kubelet, care primește requesturile de la master node și le
servește. Printre atribuții, acesta are ca rol pornirea, containerelor,
gestiunea imaginilor, conexiunea cu volumele.

În această schemă mai avem și CRI-ul, sau container runtime-ul, aceasta este
aplicația care efectiv pornește și oprește containerele. Există diverse CRI-uri,
acestea trebuie să urmărească un standard și în practică pot să fie
interschimbabile. Voi la laborator o să vă jucați cu containerd, făcut de cei de
la Docker, între-timp ce noi în cluster folosim cri-o, o re-implementare de la
Red Hat care se promite a fi mai stabilă.

Kubernetes este o platformă care la baza ei este "object oriented", în ea
definim obiecte, interacțiuni între obiecte și folosim verbe pentru a
interacționa cu ele.

Verbele pe care le vom folosi sunt:
* get, listează informații despre obiecte
* create, crează obiecte
* delete, șterge obiecte
* describe, afișează informații detaliate despre obiecte
* logs, afișează logurile podurilor

Obiectele cu care noi vom interacționa azi sunt:
* namespaces
* poduri
* deploymenturi
* replicaset-uri

#### Namespace

Un namespace este o delimitare între obiecte. Namespace-urile sunt folosite
pentru a a face o separație între utilizatori. Noi în cadrul laboratoarelor
suntem administratori, avem super-user, putem să ne uităm la toate
namespace-urile, putem crea obiecte în ele, putem să ștergem obiecte și așa mai
departe.

În practică, atunci când o echipă lucrează la un proiect, la o aplicație,
aceasta va avea acces la un singur namespace în care își vor crea obiectele.
Astfel, putem să avem un nivel de izolare între echipe.

#### Poduri

Podurile sunt un set de containere pe care noi le rulăm. Aceste containere
rulează aceleași resurse, aceeași rețea și pot împărți sistemul de fișiere.
În general podurile sunt menite să hosteze containere care au dependențe hard
între ele. De exemplu: atunci când avem o bază de date și un serviciu care
folosește acea bază de date, ele ar trebui să stea în poduri diferite deoarece
vrem să le scalăm diferit, vrem să le deployem diferit, expun porturi diferite.

#### ReplicaSet

Un replica set este un obiect care controlează un set de poduri. Numărul de
replici ale unui pod este asigurat de către ReplicaSet. Dacă un Pod a fost
șters, acesta va fi creat iar de către ReplicaSet până numărul minim de poduri
necesar este creat.

##### Deployment

Un deployment este obicetul care configurează replicaseturi și poduri. Acesta
permite configurarea într-o formă declarativă a obiectelor replicaset.

Acesta este folositor deoarece el generează ReplicaSet-uri, care după generează
pod-uri.
În realitate, noi nu vom deploya servicii în Kubernetes direct sub formă de
poduri deoarece acest mecanism nu ne oferă flexibilitatea dorită. Obiectele de
tip deployment sunt soluția care ne oferă stratul de abstractizare necesar
pentru a porni poduri în mod automat prin ReplicaSet-uri, după o anumită
strategie.

### Demo:

#### Executarea podurilor instant

Vom folosi comanda `kubectl run` pentru a porni poduri polosind următoarele
opțiuni
* `-it` folosit pentru rularea containerul în foreground în terminal;
* `--image=alpine` imaginea de container folosită în pod va fi `alpine`;
* `--` este folosit pentru delimitatea între argumentele și opțiunile comenzii
  `kubectl` și comanda care va fi rulată în container (`ping 127.0.0.1 -c 10`

```
student@demo-sw:~$ kubectl run -it --image=alpine ping-test -- ping 127.0.0.1 -c 10
If you don't see a command prompt, try pressing enter.
64 bytes from 127.0.0.1: seq=1 ttl=64 time=0.036 ms
64 bytes from 127.0.0.1: seq=2 ttl=64 time=0.030 ms
64 bytes from 127.0.0.1: seq=3 ttl=64 time=0.028 ms
64 bytes from 127.0.0.1: seq=4 ttl=64 time=0.030 ms
64 bytes from 127.0.0.1: seq=5 ttl=64 time=0.030 ms
64 bytes from 127.0.0.1: seq=6 ttl=64 time=0.037 ms
64 bytes from 127.0.0.1: seq=7 ttl=64 time=0.030 ms
64 bytes from 127.0.0.1: seq=8 ttl=64 time=0.027 ms
64 bytes from 127.0.0.1: seq=9 ttl=64 time=0.027 ms

--- 127.0.0.1 ping statistics ---
10 packets transmitted, 10 packets received, 0% packet loss
round-trip min/avg/max = 0.027/0.031/0.041 ms
Session ended, resume using 'kubectl attach ping-test -c ping-test -i -t' command when the pod is running
```

În cazul în care vrem să pornim un pod în mod interactiv, vom urmări logurile
sale folosind comanda `kubectl logs <nume pod>` ca în exemplul de mai jos:

```
student@demo-sw:~$ kubectl run --image=alpine ping-test -- ping 127.0.0.1 -c 10
pod/ping-test created
student@demo-sw:~$ kubectl logs ping-test
PING 127.0.0.1 (127.0.0.1): 56 data bytes
64 bytes from 127.0.0.1: seq=0 ttl=64 time=0.024 ms
64 bytes from 127.0.0.1: seq=1 ttl=64 time=0.029 ms
64 bytes from 127.0.0.1: seq=2 ttl=64 time=0.028 ms
64 bytes from 127.0.0.1: seq=3 ttl=64 time=0.027 ms
64 bytes from 127.0.0.1: seq=4 ttl=64 time=0.029 ms
64 bytes from 127.0.0.1: seq=5 ttl=64 time=0.030 ms
64 bytes from 127.0.0.1: seq=6 ttl=64 time=0.029 ms
64 bytes from 127.0.0.1: seq=7 ttl=64 time=0.027 ms
64 bytes from 127.0.0.1: seq=8 ttl=64 time=0.027 ms
64 bytes from 127.0.0.1: seq=9 ttl=64 time=0.027 ms

--- 127.0.0.1 ping statistics ---
10 packets transmitted, 10 packets received, 0% packet loss
round-trip min/avg/max = 0.024/0.027/0.030 ms
```

#### Pornirea unui deployment

Spre deosebire de mediile single-node folosind Docker, în cazul punerii
serviciilor în funcțiune în Kubernetes, ne dorim să controlăm mai multe aspecte
funcționale ale serviciile cum ar fi numărul de replici, felul cum le accesăm.

Pentru a lansa un pod ca parte a unui deployment putem să facem asta în linie de
comandă în felul următor:
```
student@demo-sw:~/demo$ kubectl create deployment pingpong --image=alpine -- ping 127.0.0.1
deployment.apps/pingpong created
```

Putem vizualiza ce obiecte au fost folosite pentru generarea unui token folosind
comanda `kubectl get all`
```
student@demo-sw:~/demo$ kubectl get all
NAME                            READY   STATUS    RESTARTS   AGE
pod/pingpong-5949c46847-bk8sp   1/1     Running   0          71s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d20h

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/pingpong   1/1     1            1           71s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/pingpong-5949c46847   1         1         1       71s
```

Observăm că au fost create:
* un deployment `pingpong`;
* un replicaset, `pingpong-5949c46847`;
* un pod `pingpong-5949c46847-bk8sp`.

Putem folosi comanda `kubectl describe deployment pingpong` pentru a vedea
informații detaliate despre deployment astfel:
```
student@demo-sw:~/demo$ kubectl describe deployment pingpong
Name:                   pingpong
Namespace:              default
CreationTimestamp:      Thu, 13 Mar 2025 13:52:00 +0000
Labels:                 app=pingpong
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=pingpong
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=pingpong
  Containers:
   alpine:
    Image:      alpine
    Port:       <none>
    Host Port:  <none>
    Command:
      ping
      127.0.0.1
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   pingpong-5949c46847 (1/1 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  6m18s  deployment-controller  Scaled up replica set pingpong-5949c46847 from 0 to 1
```

Pentru a demonstra că ReplicaSet-ul gestionează podurile și se asigură că minim
un Pod rulează, vom șterge un pot pentru a vedea cum funcționează ReplicaSet-ul:

```
student@demo-sw:~$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
pingpong-5949c46847-bk8sp   1/1     Running   0          75m
student@demo-sw:~$ kubectl delete pod pingpong-5949c46847-bk8sp
pod "pingpong-5949c46847-bk8sp" deleted
student@demo-sw:~$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
pingpong-5949c46847-wr7wm   1/1     Running   0          62s
student@demo-sw:~$ kubectl describe replicaset pingpong-5949c46847
Name:           pingpong-5949c46847
Namespace:      default
Selector:       app=pingpong,pod-template-hash=5949c46847
Labels:         app=pingpong
                pod-template-hash=5949c46847
Annotations:    deployment.kubernetes.io/desired-replicas: 1
                deployment.kubernetes.io/max-replicas: 2
                deployment.kubernetes.io/revision: 1
Controlled By:  Deployment/pingpong
Replicas:       1 current / 1 desired
Pods Status:    1 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=pingpong
           pod-template-hash=5949c46847
  Containers:
   alpine:
    Image:      alpine
    Port:       <none>
    Host Port:  <none>
    Command:
      ping
      127.0.0.1
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Events:
  Type    Reason            Age   From                   Message
  ----    ------            ----  ----                   -------
  Normal  SuccessfulCreate  108s  replicaset-controller  Created pod: pingpong-5949c46847-wr7wm
student@demo-sw:~$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
pingpong-5949c46847-wr7wm   1/1     Running   0          5m8s
```

Observăm că ReplicaSet-ul a generat un nou Pod pentru containerul care rulează
comanda `ping`.
