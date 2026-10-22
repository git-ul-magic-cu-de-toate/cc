# Data pipelines

Când vorbim depsre data pipelines, trebuie să devinim mai întâi înseamnă aceste
date. Când vorbim despre date în acest context, ne referim majoritatea timpului
la evenimente. Un exemplu de eveniment poate să fie o tranzacție pe un magazin
online, un login event pe un serviciu, un log generat de o soluție de
securitate.

### Use cases

Avem multe use case-uri pentru data pipelines, printre acestea putem să
enumerăm:
* managementul securității
* gestiunea tranzacțiilor în e-commerce
* parsarea informațiilor de la sensorii uni sistem
* managementul inventarului

În cadrul acestui curs ne vom concentra pe o componentă a procesului de
procesare al datelor și anume pe partea de agregare a informației. Unde o punem,
cine o încarcă, cine o consumă. Facem asta pentru a urmări un use case practic
despre ce putem să punem într-o infrastructură cloud.

Cursul de cloud computing este orientat în special spre soluțiile bazate pe
micro-servici. Asta înseamnă că aplicația noastră este spartă în servicii de
sine stătătoare care pot să comunice între ele. Avantajul micro-serviciilor este
că putem să scalăm individual componentele în funcție de usage, putem să facem
update-uri selectiv componentelor și este înlesnit procesul de dezvoltare pentru
că poți modifica și updata o componentă fără să le afectezi pe celelalte, cum ar
fi faptul că nu trebuie să aștepți să ai un release pentru toată soluția.

În cazul microserviciilor este nevoie de un mecanism de comunicare între
servicii. Putem folosi endpointuri, de exemplu putem să avem un API RESTful
pentru a face triggering între componente atunci când trebuie apelată o
funcționalitate dintr-un alt serviciu. Problema cu această abordare este faptul
că duce la o cuplare între diferitele microservicii.

Putem lua un caz mai concret cum ar fi o firmă de telecom. Ca parte a sistemului
de contabilitate această firmă blochează numerele de telefon care nu au plătit
factura la telefon timp. Atunci când clientul își plătește în sfârșit factura
cum putem putem să facem astfel încât să fie deblocat numărul. În cazul naiv
din sistemul de plăți putem să facem un API call către sistemul de gestiune al
numerelor de telefon să fie deblocat numărul de telefon. Ce vom face în cazul în
care vrem să colectăm și analitici despre astfel de evenimente? În acest caz
trebuie în funcția care notifică sistemul de accounting, trebuie să adăugăm un
apel și căte sistemul de analitici. În proiectele mari un astfel de mod de
dezvoltare nu va scala. Este necesar un sistem de stocare, parsare și notificare
în cazul unui eveniment. Putem converti sistemul de gestiune al plăților într-un
sistem de logging la care ne putem abona pentru mai multe tipuri de procesare
fără a mări code base-ul producătorului de evenimente.

### Obiective și alternative

Care este scopul logării evenimentelor? Ele pot să fie data point pentru a lua
anumite decizii. Aceste decizii pot să fie decizii de business analytics, cum
poate să facă o afacere mai mulți bani, de exemplu despre când poate un
serviciu să servească reclame mai bine, sau pot să fie folosite în decizii de
billing.

Care este legătura dintre acest mod de programare și cloud computingul? Ce am
descris până acum poate să fie descris foarte ușor ca o bază de date append-only
în care un producător scriu evenimentele. Genul ăsta de procesare poate să fie
definit ca o bază de date. Problema cu bazele de date este că sunt heavy-weight
și sunt foarte dependente de implementare. Multe implementări de baze de date nu
sunt menite să scaleze orizontal, mai de grabă ele sunt menite să scaleze
vertical, adică pentru ele contează mai mult performanță unui nod și nu scalează
bine multi-node, iar în momentul de față ne este mai ușor să scalăm un sistem de
mesagerie/stocare a evenimentelor orizontal (din punct de vedere al infrastructurii orizontal).

Nu există alte mecanisme mai inteligente pe care să le folosim decât o bază de
date? Până la urmă ăsta sună de parcă este un sistem de tipul producer-consumer.
În alte contexte ne-am mai lovit de requirementuri similare și am folosit
sisteme de message passing, sau mesage queue pentru a lucra cu evenimente. Avem
un exemplu în OpenStack, unde sunt mai multe componente, un API pentru imagini,
un API pentru gestiunea VM-urilor, un API pentru gestiunea rețelei. Toate aceste
backenduri comunică între ele și se abonează la evenimente printr-un sistem de
message passing.

O problemă pe care o avem la MQ-uri este faptul că elste sunt menite să fie
consumate de un singur client în multe cazuri. Pot să am mai mulți producători
de evenimente, de exemplu avem mai multe backenduri care trebuie să comunice
între ele. Atunci când un consumator de exemplu un procesator de evenimente vine
să extragă ceva din coadă, dispare evenimentul din coadă. Asta este o problema
atunci când suntem într-un context unde ne interesează să consumăm evenimentele
din mai multe servicii, atunci nu ne ajută să folosim doar un MQ. O altă
problemă a acestor sisteme este faptul că nu stochează un istoric al mesajelor,
astfel nu putem face interogări pe o listă de evenimente ci este nevoie să le
agregăm într-un mediu de stocare permanent.

## Apache Kafka

Noi ne vom studia la acest curs doar Apache Kafka. Acesta nu este un tool
care procesează datele, mai de grabă el este un utilizat care facilitează
procesarea datelor. Este funcționează pe principiul unui MQ, primește mesaje de
la un producer, le stochează persistent, replicat, pe disk și le trimite la
cerere consumatorilor atunci când aceștia cer datele.

În Kafka evenimentele sunt stocate persistent pe file system. Asta oferă
persistența datelor, iar Kafka ne oferă garanții pentru capacitatea de stocare.
Un avantaj al Kafka este faptul că noi putem să setăm un grad de replicare al
evenimentelor. Asta înseamnă că în cazul unui failure, de exemplu apare o
defecțiune la un controller, datele încă sunt accesibile.

Elementele principale ale unei arhitecturi Kafka sunt:
* broker, nodul care controlează cozile;
* producer, aplicația care inserează mesaje în cozi;
* consumer, aplicația care accesează mesaje din cozi.

### Organizarea internă a brokerilor

Nodurile care gestionează cozile de mesaje, pe care le vom numi topic-uri, se numesc brokeri.

O coadă de evenimente în Kafka se numește un topic. Putem să asociem un topic
pentru un anumit tip de evenimente. De exemplu, putem să avem un topic asociat
logurilor de tranzacții dintr-un DNS. DNS-ul produce logurile, folosim un
collecter care va trimite logurile catre Kafka pentru un anumit topic;

O problemă pe care o putem avea cu aceste topic-uri este de la cum putem să le
stocăm, un topic este o serie de loguri. Cum putem să stocăm aceste
loguri pe mai multe mașini și cum putem să scalăm orizontal pentru a ne folosi
de avantajele Kafka?

Soluția pentru această problema este partiția. O partiție este o metodă de a
împărți un topic între mai mulți brokeri. Avantajul folosirii brokerilor este
faptul că putem să răspândim evenimentele pe mai mulți brokeri și evităm probleme
de hostspotting, când avem un subset de evenimente logate care sunt accesate mai
des decât altele producând un load mai mare pe un nod.

Mesajele sunt împărțite între partiții pe baza unei chei care poate să fie dată
de către producer pentru a forța mesajele pe o partiție, sau care poate fi
generată de un algoritm de hashing și va fi folosită pentru a distribui mesajele
între partiții într-un mod balansat.

Un topic are în mod predefinit un număr de replici pentru fiecare mesaj, iar un
cluster de Kafka va avea într-o arhitectură completă minim 3 brokeri pe care să
ruleze. Astfel, este garantată replicarea mesajelor, oferind un mediu highly
available pentru clienți în care poate fi pierdut accesul la un broker și datele
să fie în continuare disponibile.

### Organizarea consumerilor

Pentru a primi logurile de pe un topic, consumerii se abonează la topicuri.
Folosind API-ul Kafka un consumer poate să se aboneze la un topic pentru a primi
mesajele. Acest mod de conectare este unul naiv și nu se folosește de avantajele
enumerate mai devreme pentru folosirea Kafka. Avem o legătură strânsă între un
consumator și un topic în această situație și nu paralelizăm procesarea
informației dintr-o coadă. Este de avut în vedere că tipurile de insert pentru
care este proiectat Kafka sunt la nivel de sub o secundă. Pentru a scala
procesarea evenimentelor orizontal, este nevoie să folosim mai mulți consumatori
pentru același pool de evenimente fără să existe suprapuneri între aceștia.

Pentru a aloca evenimente pentru a fi procesate de consumatori, putem să asociem
consumatorilor un grup. Fiecare consumator din grup atunci când va consuma un
eveniment va primi unul nou din coadă față de ceilalți consumatori abonați.
Numărul de consumatori din grup este limitat de numărul de partiții dintr-un
topic. Dacă numărul de consumatori din grup este mai mare decât numărul de
partiții dintr-un topic, consumatorii în plus nu vor procesa evenimente, dar în
cazul în care un alt consumator este oprit, unul care nu era folosit până atunci
va fi alocat. Aceasta este o metodă folositoare în situația în care ne dorim
redundanță în sistemul de procesare de informații, asigurându că-ne putem să
păstrăm performanța așteptată.
