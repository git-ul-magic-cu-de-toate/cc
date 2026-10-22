# Persistența în containere

În cadrul acestui curs am vorbit până acum doar de partea de compute. Cum facem
sa vem servicii în picioare, cum putem să le facem highly available, cum putem
să dăm acces din exterior, să le limităm accesul la resurse, să deployem
aplicații noi sau versiuni noi ale aplicațiilor.

Toate aceste use case-uri sunt valide, dar sunt câteva limitări pe care nu le-am
discutat până acum.

## Volume în Kubernetes

În continuare în Kubernetes există conceptul de volume, dar dacă înainte ne
refeream la volume ca fiind o metodă persistentă de stocare a datelor, în
kubernetes un volume (nu un persistent volume) este doar o metodă de a împărți
fișiere între contrainere din același pod și același host.

Ne vom uita acum la ce înseamnă un volum în cadrul Kubernetes. Observăm că putem
să îl definim, îi dăm un nume, ca în exemplu de mai jos.

Poate o să vi se pară cunoscut de la temă. Avem un site web, static, html.
Acesta trebuie clonat ca să luăm ultima lui versiune și trebuie să îl servim
cumva. Pentru a face asta putem să ne scriem noi o aplicație, o comandă pe care
să le facă pe ambele într-un singur container, sau putem să ne folosim de
tooluri deja existente.

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-git
spec:
  volumes:
  - name: www
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: www
      mountPath: /usr/share/nginx/html/
  - name: git
    image: alpine
    command: [ "sh", "-c", "apk add git && git clone https://github.com/octocat/Spoon-Knife /www" ]
    volumeMounts:
    - name: www
      mountPath: /www/
  restartPolicy: OnFailure
student@sw-test:~/demo$ kubectl get pod nginx-with-git
NAME             READY   STATUS     RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
nginx-with-git   1/2     NotReady   0          42s   10.244.0.37   minikube   <none>           <none>
root@minikube:/# curl 10.244.0.37
<!DOCTYPE html>

<html>
<head>
...
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <title>Spoon-Knife</title>
  <LINK href="styles.css" rel="stylesheet" type="text/css">
</head>
</html>
```

Acest setup este ineficient, deoarece putem să folosim alte construcții sau
funcționalități pentru a pregăti un mediu pentru un container, dar demonstrează
conceptul volumelor împărțite între containere. Am denumit volumul `www` pentru
ambele containere în fișierul manifest, iar pentru fiecare container am definit
o cale diferită la care volumul va fi montat. După ce podul va fi șters,
conținutul volumelor va fi șters și el.

## Configurarea serviciilor

În primul rand vreau să vă întreb eu pe voi: cum facem să configurăm un serviciu
deployat prin kubernetes? Într-adevăr, putem să îl deployem prin Helm și acesta
va avea un config de bază, dar această configurare este una inițială, care ne
ajută să modificăm lucruri care sunt ușoare de modificat.

Hai să ne uităm la un deployment real: Vrem să configurăm un server de HAproxy
care să ne comunice între name space-uri. De ce vrem să facem asta? Un ingress
poate să facă load balancing doar între namespace-uri, el este conceput să
funcționeze în cadrul unui namespace, deoarece și selectorul funcționează în
cadrul unui singur namespace.

Cum putem să configurăm acest HAproxy? Cum am configura în mod normal un
serviciu? Am edita fișierul de configurare al serviciului și am pune acolo ce
valoare trebuie să fie pusă. Okay. Cum facem asta în containere?

Dacă eram în docker cum am face asta? Făceam un bind mount fișierului de config
pe care îl scriam și îl puneam într-un repository și îl montam l calea la care
se așteaptă haproxy să fie configul.

De ce nu mai este această metodă de configurare suficientă acum? Deoarece în
trecut în Docker eram legați de nod. Acum de multe ori nu mai avem această
posibilitate deoarece un pod poate să pornească pe oricare nod din cluster.

Din acest motiv avem nevoie de o nouă entitate care să gestioneze configurările.
Această entitate se numește un ConfigMap și o putem defini în mai multe moduri.
Un ConfigMap este o listă de perechi cheie-valoare care pot fi folosite pentru
configurarea podurilor.

Observăm două metode de configurare. Primul este pe bază de variabile de mediu.
Am văzut și la docker și la alte imagini OCI că ele se pot aștepta la configuri
prin variabile de mediu, cum ar fi la MariaDB unde putem să-i spunem prin
variabile de mediu hostul la care să se conecteze.

În loc să avem variabilele scrie în fișierul în care avem codul, putem să avem
un fișier și o resursă separată care configurează variabilele de mediu.

În exemplul de mai jos am configurat un container `mysql` expunând în variabile
de mediu configurările dintr-un obiect `ConfigMap`:

```
---
# MySQL ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  labels:
    app: wordpress
data:
  mysql-database: wordpress
  mysql-user: wordpress
  mysql-root-password: password123
  mysql-password: password123
---
# MySQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: wordpress
    tier: database
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: database
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: database
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: mysql-root-password
        - name: MYSQL_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: mysql-password
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: mysql-database
        - name: MYSQL_USER
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: mysql-user
        ports:
        - containerPort: 3306
          name: mysql
```

Pentru schimbarea configurării pod-ului este suficient să modificăm valoarea din
ConfigMap și să restartăm containerul.

Pentru a identifica valorile configurată în ConfigMap putem folosi comanda
`kubectl describe` astfel:

```
student@sw-test:~/demo/course-08$ kubectl describe configmap mysql-config
Name:         mysql-config
Namespace:    default
Labels:       app=wordpress
Annotations:  <none>

Data
====
mysql-database:
----
wordpress

mysql-password:
----
password123

mysql-root-password:
----
password123

mysql-user:
----
wordpress


BinaryData
====

Events:  <none>
```

Ca alternativă la expunerea configurilor în variabile de mediu, lucru care nu
scalează atunci când vrem să definim întregi fișiere de configurare, putem să
încărcăm într-un ConfigMap un fișier în felul următor și să îl montăm într-un
container ca un volum:

```
student@sw-test:~/demo/course-08/haproxy$ cat haproxy.cfg
global
  daemon

defaults
  mode tcp
  timeout connect 5s
  timeout client 50s
  timeout server 50s

listen very-basic-load-balancer
  bind *:80
  server blue color.blue.svc:80
  server green color.green.svc:80

# Note: the services above must exist,
# otherwise HAproxy won't start.
student@sw-test:~/demo/course-08/haproxy$ kubectl create configmap haproxy --from-file=./haproxy.cfg
configmap/haproxy created
student@sw-test:~/demo/course-08/haproxy$ kubectl describe configmap haproxy
Name:         haproxy
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
haproxy.cfg:
----
global
  daemon

defaults
  mode tcp
  timeout connect 5s
  timeout client 50s
  timeout server 50s

listen very-basic-load-balancer
  bind *:80
  server blue color.blue.svc:80
  server green color.green.svc:80

# Note: the services above must exist,
# otherwise HAproxy won't start.
<...>
student@sw-test:~/demo/course-08/haproxy$
student@sw-test:~/demo/course-08/haproxy$ cat haproxy.yaml
apiVersion: v1
kind: Pod
metadata:
  name: haproxy
spec:
  volumes:
  - name: config
    configMap:
      name: haproxy
  containers:
  - name: haproxy
    image: haproxy:1
    volumeMounts:
    - name: config
      mountPath: /usr/local/etc/haproxy/
```

Fișierul haproxy.yaml definește un pod care va rula serverul de HAproxy și va
monta la calea specificată în `volumeMounts` fișierul `haproxy.cfg`.

## Stocarea sigură a credențialelor

Am văzut cum putem să configurăm un sistem pentru a stoca date de configurare
ale unui serviciu pe care îl hostăm în kubernetes. Totuși acest fel de
configurare al serviciilor nu este tocmai satisfăcător din punct de vedere al
protocoalelor de securitate.

Prima problemă e că oricine are acces la namespace poate să vadă aceste
configuri. Asta e o problemă de securitate. Nu avem auditate specială peste
aceste date vitale nouă, mai ales când vorbim despre parole sau chei private.

Din cauza asta în Kubernetes pe lângă obiectele de configurare obișnuite există
și obiecte de configurare de tipul secret. Diferență dintre acestea și obiectele
obișnuite este că exisță auditare specială pentru ele, secretele pot fi
criptate, ele sunt obfuscate în etcd și pot inclusiv să fie criptate.

Criptarea secretelor vine totuși și cu un dezavantaj. Pentru a decripta
secretele este nevoie de o cheie care să fie introdusă de un utilizator. Acest
lucru reduce din automatizarea unui cluster în favoarea securitătii. Problema
apare mai ales la criptare.

Vorbeam despre obfuscare, hai să vedem cum se văđ secretele astea. Dacă dau un
get, observ că nu le văd în mod predefinit.

Un aspect al configurării secretelor este faptul ca acestea au asociate un tip.
Acest tip obligă dezvoltatorii să configureze anumite câmpuri. Avantajul
acestor tipuri este faptul că ele pot să fie folosite de alte obiecte care se
pot baza pe faptul că vor exista chei predefinite completate, stabilind un
standard.

Într-un setup de producție secretele vor fi stocate în format base64, pentru a
adăuga un strat de obfuscare acestora. Putem să observăm în exemplul de mai jos
faptul că rulăîn exemplul de mai jos că atunci când rulăm subcomanda `describe`
secretul nu va mai fi afișat:

```
student@sw-test:~/demo/course-08$ kubectl describe secret nextcloud -n nextcloud
Name:         nextcloud
Namespace:    nextcloud
Labels:       app.kubernetes.io/instance=nextcloud
              app.kubernetes.io/managed-by=Helm
              app.kubernetes.io/name=nextcloud
              app.kubernetes.io/version=30.0.10
              helm.sh/chart=nextcloud-6.6.10
Annotations:  meta.helm.sh/release-name: nextcloud
              meta.helm.sh/release-namespace: nextcloud

Type:  Opaque

Data
====
nextcloud-password:  8 bytes
nextcloud-username:  5 bytes
```

Atunci când rulăm subcomanda `edit` pe un Secret, valoarea din obiect va fi
reținută în format base64, dar atunci când va fi expusă într-un Pod, aceasta va
fi în format clar.

Secretele pot fi expuse în același mod ca valorile dintr-un configMap, diferență
fiind că în loc să folosim cuvântul cheie `configMapKeyRef` vom folosi
`secretKeyRef`.

## Stocarea persistentă

În kubernetes când vorbim despre stocare persistentă noi ne referim defapt la
volume persistente (asta este definiția lor în Kubernetes). Ele sunt un spațiu
alocat pe un sistem de stocare care este montat în cadrul podurilor și al cărui
lifetime nu depinde de lifetime-ul podului. Asta înseamnă că eu pot să șterg
deployment-ul, pot să șterg nodul și totuși datele acestuia rămân în urmă.

Până acum nu prea am șters poduri, sau când le-am șters nu ne-a păsat de ce
lăsăm în urmă, deoarece am lucrat cu deploymenturi stateless. Un use case pe
care putem să îl avem în cadrul acestor sisteme sunt câteva:
* avem nevoie să atașăm un volum care să conecteze mai multe aplicații în
  paralel pentru a partaja datele, aici ne putem gândi la un sistem de procesare
  care are agregă outputul procesării de la toți utilizatorii și are nevoie să îl
  refolosește pentru a rerula procesarea
* avem nevoie de spațiu de stocare mai mare decât ne este oferit de nod. În
  momentul de față avem sisteme de stocare ce pot să ofere mult spatiu pe disk
  și acesta este folosit de multe ori pentru deployment-uri. Problema vine în
  momentul când ai nevoie să te folosești de un spațiu de stocare mai mare, cum
  ar deploymenturi de scratchbox-uri, spații împărțite de mai mulți utilizatori,
  sau ai nevoie să ai acces nativ, din filesystem la un dataset pentru procesare
* atunci când vrei să ai un sistem de alocare al nodurilor dinamic. Un avantaj
  în momentul de față al sistemelor de stocare publice este faptul că poți să le
  atașezi și detașezi la un nod. Asta înseamnă că eu pot să migrez workloadurile
  între-noduri fără să am probleme de downtime-uri sau să am downtime-uri
  minime, deoarece este neboie doar să îmi migrez deploymentul (sau
  statefulset-ul despre care nu voi vorbi prea mult) pe un alt nod.


### Storage Classes

Pentru a defini un volum trebuie mai întâi să definim un alocator de volume.
Până acum noi am știut un singur mod de alocare al volumelor în Docker și anume
alocarea lor folosind Docker Volumes.

Kubernetes oferă posibilitatea utilizatorilor să aloce volume folosind diverse
drivere de alocare și gestiune a volumelor. În cadrul clusterului de `minikube`
pe care îl folosim în cadrul demo-urilor este folosit driverul `hostpath` pe
care putem să îl vedem mai jos:

```
student@sw-test:~$ kubectl get storageclass
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
csi-hostpath-sc      hostpath.csi.k8s.io        Delete          Immediate           false                  4h9m
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  6h8m
```

În cadrul unui sistem va exista un strorageclass default care va fi folosit
atunci când alocăm un volum fără să specificăm unul. În cadrul deploymentului de
minkube acest storage class va aloca volume în sistemul fișierului al nodului
gazdă, acestea nefiind vizibile pe alte noduri din cluster.

Storage class-urile sunt menite să satisfacă diferite cerințe ale
utilizatorilor, de la un grad mare de redundanță, cum este oferit de Ceph, la
sisteme care se folosesc de endpointuri S3 pentru stocarea fișierelor drept
obiecte.

### Persistent volumes

Un persistent volume este o entitate de sine stătătoare care reprezintă un
spațiu alocat pe un sistem de stocare. Pentru generarea unui obiect
PerssistentVolume(PV) vom folosi următorul manifest:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
  labels:
    container.training/pvc: ""
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  claimRef:
    kind: PersistentVolumeClaim
    name: demo-pvc
    namespace: default
  storageClassName: standard
  hostPath:
    path: /tmp/test/
    type: ""
```

Observăm următoarele atribute:

* accessModes, câte poduri pot accesa în paralel volumul. În cazul
  acesta volumul poate fi accesat de pe un singur nod, dacă voiam acces
  multi-node trebuia să folosim `ReadWriteMany`. Deoarece folosim driverul
  hostPath este nevoie să folofim `ReadWriteOnce`;
* `capacity`, cât spațiu de stocare este disponibil în acest volum. Această
  specificație nu este o limită a spațiului de stocare, variabila fiind folosită
  pentru scheduling;
* `claimRef`, numele Persistend Volume Claim-uluil, care va fi explicat în
  următarea secțiune și namespace-ul din care face parte;
* `storageClassName`, numele clasei care va va fi folosită pentru alocarea
  volumului, nu este necesară dacă vrem să folosim soluția de stocare
  predefinită;
* `hostpath`, tipul de storageclass, acesta generează un fișier pe
  nodul gazdă.

Aplicând manifestul de mai sus Volumul este generat, spațiul este dedicat pentru
un pod care îl va utiliza, dar este nevoie ca acest volum să fie programat
pentru a fi folosit de către un pod și trebuie să fie atașat unui pod.

```
student@sw-test:~/demo$ kubectl get pv,pvc
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/demo-pv                                    1Gi        RWO            Retain           Available   default/demo-pvc          standard       <unset>                          2s
```

Observăm că starea diskului este `Available`, este gata să fie alocat unui Pod.

Obiectul care se ocupă de ocupare unui volum in numele unui pod se numește un
PersistentVolumeClaim (PVC) și este folosit pentru a cere de la sistemul de
provizionare al volumelor un volum care să poată fi atașat unui pod. Generând un
PVC noi cerem scheduler-uli de resurse din Kubernetes să aloce un volum deja
existent, sau dacă storage classul permite, generarea unui volum care
întreplinește criteriile PVC-ului.

Pentru exemplul de mai sus vom genera un PVC astfel:
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
  labels:
    container.training/pvc: ""
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  claimRef:
    kind: PersistentVolumeClaim
    name: demo-pvc
    namespace: default
  storageClassName: standard
  hostPath:
    path: /tmp/test/
    type: ""

```

```
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/demo-pv                                    1Gi        RWO            Retain           Bound    default/demo-pvc          standard       <unset>                          3m5s

NAME                             STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/demo-pvc   Bound    demo-pv   1Gi        RWO            standard       <unset>                 7s
```

Stare PV-ului  fost schimbată în `Bound` și observăm că PVC-ul este și el
alocat. Este de avut în vedere că există PV-ul poate să fie alocat și dezalocat
mai multor claim-uri. Acesta a continua să existe pe disk chiar dacă PVC-ul va
fi șters.

Pentru a folosi un PVC pentru montarea uni volum în Pod vom folosi următorul
manifest:
```
student@sw-test:~/demo$ cat mounter.yaml
kind: Pod
apiVersion: v1
metadata:
  name: mounter
spec:
  volumes:
  - name: pvc
    persistentVolumeClaim:
      claimName: demo-pvc
  containers:
  - name: mounter
    image: alpine
    stdin: true
    tty: true
    volumeMounts:
    - name: pvc
      mountPath: /pvc
    workingDir: /pvc
student@sw-test:~/demo$ kubectl apply -f mounter.yaml
pod/mounter created
student@sw-test:~/demo$ kubectl exec -it mounter -- /bin/sh
/pvc # ls
/pvc #
```

Volumul alocat prin claim a fost montat și poate să fie fie folosit de mai multe
containere în paralel, chiar și din deploymenturi diferite. Astfel obiectul PVC
este folosit pentru alocarea (și generarea, în caz în care nu este un volum deja
alocat) al unui volum pentru a fi folosit în mod distribuit.
