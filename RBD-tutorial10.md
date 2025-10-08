# Fragmentaryzacja pozioma w MongoDB

Celem zajęć jest zapoznanie się z właściwościami fragmentaryzacji poziomej w bazie danych MongoDB.

## Przygotowanie środowiska

Klaster MongoDB, który umożliwia fragmentaryzację poziomą wymaga utworzenia trzech rodzajów węzłów. Rodzaje tych węzłów to:

* węzły konfiguracyjne - przechowują i udostępniają metadane oraz dane konfiguracyjne,
* węzły fragmentów - przechowują i udostępniają fragmentaryzowane dane użytkownika,
* węzły ruterów zapytań - stanowią interfejs, który udostępnia język zapytań umożliwiający manipulację danymi składowanymi w klastrze MongoDB.

Klaster MongoDB wymaga utworzenie co najmniej jednego węzła konfiguracyjnego. Można utworzyć większą ich liczbę w celu uzyskania większej niezawodności rozwiązania dzięki zastosowaniu mechanizmu replikacji. Zbiór takich węzłów nazywany jest w nomenklaturze MongoDB zbiorem replikacji (ang. Replica Set). W zbiorze replikacji jeden węzeł stanowi węzeł nadrzędny, a pozostałe pełnią rolę węzłów podrzędnych lub arbitrów. Mechanizm działania zbioru replikacji został przestawiony w poprzednim tutorialu. 
Do wdrożenia węzłów konfiguracyjnych wykorzystamy jeden StatefulSet Kubernetes. Repliki tego StatefulSet będa stanowić jeden zbiór replikacji.

W celu rozproszenia danych w klastrze wykorzystuje się jeden lub więcej węzłów fragmentów. Węzły fragmentów, analogicznie jak węzły konfiguracyjne, również można grupować w zbiory replikacji w celu zwiększenia niezawodności. Zastosowanie wielu zbiorów replikacji umożliwia rozproszenia danych użytkownika i za tym idzie zwiększenie skalowalności rozwiązania. W celu wdrożenia węzłów fragmentów wykorzystamy wiele StatefulSet Kubernetes. Każdy StatefulSet będzie reprezentował zbiór replikacji węzłów fragmentów, a każda replika StatefulSet będzie odpowiadała jednemu węzłowi w danym zbiorze replikacji.

Klaster MongoDB wymaga co najmniej jednego węzła ruterów zapytań. Zastosowanie wielu takich węzłów umożliwia rozproszenie zapytań i wykorzystanie większej liczby zasobów do ich przetworzenia. Węzły te nie posiadają własnych danych i nie mogą być zorganizowane w zbiór replikacji. W związku z tym mogą ale nie muszą być wdrożone jako StatefulSet. Można by je wdrożyć jako Deployment, jednakże aby ujednolić manifesty wdrażanych obiektów Kubernetes, oraz co jest z tym związane ułatwić wdrożenie, zastosujemy StatefulSet również dla węzłów ruterów zapytań.

Z powyższych założeń wynika, że należy utworzyć szereg bardzo podobnych do siebie manifestów Kubernetes. Jest to zadanie czasochłonne oraz obarczone dużym ryzykiem pomyłki. Rozwiązaniem byłoby zastosowanie mechanizmu szablonów manifestów, w którym w wygodny sposób można ustalać zmienne parametry manifestów. Takie własności posiada narzędzie Helm. Narzędzie to oprócz możliwości stosowania parametrów udostępnia konstrukcje warunkowe, pętle i inne zaawansowanych techniki tworzenia szablonów manifestów, włącznie z tworzeniem pakietów, które można publikować w repozytoriach. Helm pozwala również na wdrażanie manifestów w Kubernetes i zarządzanie wdrożonymi obiektami.

Niniejszy rozdział poświecony jest zapoznaniu się z narzędziem Helm oraz wykorzystaniu go w celu konfiguracji kluastra MongoDB.

1. Zaloguj się do maszyny wirtualnej jako użytkownik *rbd* używając hasła *RBD#7102*.

2. Otwórz okno terminala, który nazwiemy terminalem pomocniczym.

3. W terminalu pomocniczym wykonaj poniższe polecenie w celu instalacji Helm:
   
   ```
   curl https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz | tar -xzf -
   sudo mv linux-amd64/helm /usr/local/bin/
   ```

4. W terminalu pomocniczym wykonaj poniższe polecenie aby zarejestrować repozytorium przygotowane specjalnie na niniejsze zajęcia.
   
   ```
   helm repo add rbd https://rbdput.github.io/mongo-shrd-package/
   ```

5. Aby sprawdzić listę zarejestrowanych repozytoriów uruchom w terminalu pomocniczym następujące polecenie:
   
   ```
   helm repo list
   ```

6. W celu pobrania zawartości pakietu Helm, który zawiera pliki potrzebne do wygenerowania manifestów tworzących poszczeólne składniki klastra MongoDB wykonaj w terminalu pomocniczym niniejsze polecenie:
   
   ```
   helm pull rbd/mongo-shrd --untar --untardir ~
   ```
   
   W poniższym poleceniu *rbd* oznacza nazwę zarejestrowanego repozytorium, natomiast *mongo-shrd* wskazuje na nazwę pakietu Helm, ponadto znak *~* wskazuje na katalog domowy. W wyniku powyższego polecenia w katalogu domowym został utworzony katalog *mongo-shrd* a w nim następujące katalogi oraz pliki wchodzące w skład pobranego pakietu nazywane kartą Helm (ang. Helm Chart): 
- Plik *Chart.yaml* zawiera metadane karty Helm, w tym między innymi: numer wersji wykorzystywanego API Helm, numer wersji karty, nazwę karty, opis karty oraz typ karty. Zapoznaj się z zawartością tego pliku.
- Plik *values.yaml* zawiera wartości domyślne parametrów wykorzystywanych w karcie.
- Katalog *templates* zawiera pliki na postawie, których Helm generuje plik manifestów Kubernetes. W niniejszej karcie wykorzystano dwa pliki szablonów: plik *configmap.yaml* służy do utworzenia manifestu mapy konfiguracyjnej, natomiast plik *manifests.yaml* służy do wygenerowania manifestów StatefulSet oraz Service.

Szkielet nowej karty, który zawiera odpowiednie katalogi oraz przykładowe pliki można wygenerować za pomocą polecenia `helm create nazwa-nowej-karty`.

Zapoznaj się z zawartością pliku *configmap.yaml*. Dla przypomnienia, mapa konfiguracyjna Kubernetes umożliwia składowanie i zarządzanie danymi konfiguracyjnymi, które są dostępne z poziomu kontenerów Pod w postaci wartości zmiennych środowiskowych lub zawartości plików. Pojedyncza mapa konfiguracyjna daje możliwość zapisania wielu zbiorów informacji wg schematu YAML *klucz: wartość*. W naszym scenariuszu wykorzystujemy mapę konfiguracyjną do zamontowania pliku konfiguracyjnego MongoDB w kontenerze Pod. Plik ten zawiera definicję klucza *mongod.conf*, jego wartością jest tekst zapisany w YAML ponieważ takiego formatu wymaga MongoDB dla swojego pliku konfiguracyjnego. W ogólności wartością klucza może być dowolny tekst, a nawet wartość binarna, jednakże w tym drugim przypadku wartość tę należy zapisać z wykorzystaniem kodowania Base64. Zauważ, że w pliku znajdują się wpisy typu wąsy (ang. mustash) , np. *{{ .Values.replSetName }}*. Zapis ten jest wykorzystywany do instruowania Helm o akcjach, które należy wykonać z wykorzystaniem szablonu. Konwencja ta pochodzi z języka Golang, z wykorzystaniem którego zaimplementowano Helm. Powyższy wpis jest parametrem o nazwie *replSetName* i służy do sparametryzowania nazwy zbioru replikacji MongoDB. Wartość tego parametru można podać podczas generowania manifestu lub w przypadku jej braku zostanie pobrana wartość domyślna z pliku *values.yaml*. Oprócz tego parametru wykorzystywane są jeszcze dwa parametry. Parametr *clusterRole* służy do zdefiniowania roli węzła w klastrze MongoDB, przybiera on dwie wartości: *configsvr* dla węzła konfiguracyjnego oraz *shardsvr* dla węzła fragmentu. Parametr *configDB* jest wykorzystywany przez węzły pełniące role ruterów zapytań i jego wartością są adresy węzłów konfiguracyjnych. W związku z tym, że struktura pliku konfiguracyjnego dla ruterów zapytań różni się od struktury plików dla węzłów konfiguracyjnych i węzłów fragmentów zastosowano konstrukcję warunkową *{{ if warunek }}*. Opcjonalny znak minus w konstrukcji warunkowej oznacza, że w przypadku niespełnienia warunku w manifeście nie ma być umieszczony pusty wiersz. W warunku wykorzystano wartość *mongos* parametru *clusterRole*. Wartość ta nie jest poprawną nazwą roli węzła i nie jest wykorzystywana w manifeście ze względu na zadziałanie instrukcji warunkowej, służy jedynie do zbudowania nieco odmiennej struktury pliku konfiguracyjnego dla ruterów zapytań. Nazwa tej wartości pochodzi od nazwy procesu, który dostarcza funkcjonalność rutera zapytań, która również brzmi *mongos*, w odróżnieniu od procesu *mongod*, który udostępnia funkcjonalność węzłów konfiguracyjnych i węzłów fragmentów. Zwróć uwagę, że nazwa mapy konfiguracyjnej również jest sparametryzowana parametrem *replSetName*. 

Zapoznaj się z zawartością pliku *manifest.yaml*. Szablon manifestów znajdujący się w tym pliku wykorzystuje dodatkowe parametry. Parametr *port* umożliwia wskazanie numeru portu, który ma zostać udostępniowny przez Servis i Pod w zależności typu węzła klastra MongoDB. I odpowiednio, węzły konfiguracyjne domyślnie nasłuchują na porcie 27019, węzły fragmentów domyślnie nasłuchują na porcie 27018, natomiast rutery zapytań domyślnie nasłuchują na porcie 27018. Parametr *replicas* daje możliwość określenia liczby węzłów w jednym zbiorze replikacji MongoDB. 
Zwróć uwagę na klucz *.spec.templates.spec.volumes*, definiuje on wolumin wykorzystujący mapę konfiguracyjną zdefiniowaną w pliku *configmap.yaml*. Klucz *.spec.templates.spec.containers.volumeMounts* służy do zamontowania tego woluminu w katalogu */etc/config*. Dzięki temu wartość klucza *mongod.conf* zdefiniowana w pliku *configmap.yaml* będzie dostępna w kontenerze w pliku */etc/config/mongod.conf*. Plik ten jest wskazywany w kluczu *.spec.templates.spec.containers.command* jako plik konfiguracyjny uruchamianego programu. Rodzaj uruchamianego programu zależy od wartości parametru *clusterRole*, w przypadku rutera zapytań uruchamiany jest program */usr/bin/mongos*, w przypadku węzła konfiguracyjnego lub węzła fragmentu uruchamiany jest skrypt */usr/local/bin/docker-entrypoint.sh*, który z kolei uruchamia proces *mongod*. 
Ruter zapytań nie potrzebuje trwałego woluminu, w związku z tym można by użyć instrukcji warunkowej aby dla tego typu węzłów pominąć w szablonie deklarację i montowanie trwałego woluminu.

7. Sprawdź formalną poprawność karty Helm dla parametrów węzłów konfiguracyjnych, w tym celu wykonaj w terminalu pomocniczym następujące polecenie:
   
   ```
   helm lint ~/mongo-shrd \
     --set clusterRole=configsvr \
     --set replicas=1 \
     --set port=27019 \
     --set replSetName=configsvr
   ```

8. Przejrzyj zbiór manifestów, które Helm zastosuje w celu wdrożenia zbioru replikacji węzłów konfiguracyjnych, uruchom poniższe polecenie:
   
   ```
   helm template ~/mongo-shrd \
     --set clusterRole=configsvr \
     --set replicas=1 \
     --set port=27019 \
     --set replSetName=configsvr
   ```
   
   Ile manifestów zostało wygenerowanych? <mark>[Raport]</mark>

9. Wykonaj wdrożenie manifestów wygenerowanych przez Helm dla zbioru replikacji węzłów konfiguracyjnych, wykorzystaj następujące polecenie:
   
   ```
   helm install mongo-configsvr rbd/mongo-shrd \
     --set clusterRole=configsvr \
     --set replicas=1 \
     --set port=27019 \
     --set replSetName=configsvr
   ```
   
   Za pomocą parametru *mongo-configsvr* określamy unikalną nazwę instalację Helm. Zwróć uwagę, że w punktach 7 i 8 referowaliśmy do karty Helm za pomocą nazwy katalogu *~/mongo-shrd*, w którym ona się znajduje. Polecenia w tych punktach są poleceniami deweloperskimi i posłużenie się nazwą katalogu jest jedynym dostępnym sposobem referencji do karty. Natomiast w punkcie 9 referujemy do karty za pomocą nazwy repozytorium *rbd*, które zarejestrowaliśmy w punkcie 4. W punkcie 9 można również referować za pomocą nazwy katalogu, bez konieczności korzystania z repozytorium. Wykorzystanie repozytorium w środowisku produkcyjnym zwalnia nas od potrzeby rozpakowania pakietu karty, które wykonaliśmy w punkcie 6. Do wykonania wdrożenia nie jest również potrzebne wykonania punktu 8, został on przedstawiony jedynie w celach poglądowych.

10. Wyświetl listę instalacji Helm, uruchom poniższe polecenie:
    
    ```
    helm ls --all
    ```

11. Obserwuj postęp wdrożenia StatefulSet o nazwie *mongo-configsvr* wykorzystując poniższe polecenie:
    
    ```
    kubectl get sts --watch
    ```
    
    Wdrożenie wymaga pobrania obrazu kontenera z repozytorium Docker, w związku z tym zajmuje chwilę. Wdrożenie zakończy się w momencie pojawienia się na terminalu wiersza, w którym liczba działających replik będzie równa liczbie żądanych replik. W naszym przypadku liczba ta równa się jeden.  

12. Wykonaj wdrożenie manifestów wygenerowanych przez Helm dla zbioru replikacji węzłów fragmentów o nazwie *shard-a*, wykorzystaj następujące polecenie:
    
    ```
    helm install mongo-shard-a rbd/mongo-shrd \
    --set clusterRole=shardsvr \
    --set replicas=1 \
    --set port=27018 \
    --set replSetName=shard-a
    ```
    
    Powtórz krok 10. Powtórz 11 dla StatefulSet o nazwie *mongo-shard-a*.

13. Powtórz krok 12 dla zbioru replikacji węzłów fragmentów o nazwie *shard-b* oraz *shard-c*. Zwróć uwagę, że nazwy te pojawiają się dwukrotnie w poleceniu `helm install`. Pierwszy raz w nazwie instalacji Helm i drugi raz jako wartość parametru *replSetName*. <mark>[Raport]</mark>

14. Wykonaj wdrożenie manifestów wygenerowanych przez Helm dla zbioru replikacji ruterów zapytań, wykorzystaj następujące polecenie:
    
    ```
    helm install mongo-mongos rbd/mongo-shrd \
    --set clusterRole=mongos \
    --set replicas=1 \
    --set port=27017 \
    --set replSetName=mongos \
    --set configDB='configsvr/mongo-configsvr-0.mongo-configsvr:27019'
    ```
    
    Powtórz krok 10. Powtórz krok 11 dla StatefulSet o nazwie *mongo-mongos*.

15. Wykonaj inicjalizację zbioru replikacji węzłów konfiguracyjnych, w tym celu wykonaj następujące kroki:
    
    - uruchom powłokę w Pod *mongo-configsvr-0*, który jest jedynym węzłem w zbiorze replikacji węzłów konfiguracyjnych:
    
    ```
    kubectl exec -it mongo-configsvr-0 -- /bin/bash
    ```
    
    - w powyższej powłoce, uruchom program *mongo* łącząc się do lokalnego węzła konfiguracyjnego:
    
    ```
    mongo 127.0.0.1:27019
    ```
    
    - w programie *mongo* zainicjalizuj zbiór replikacji węzłów konfiguracyjnych wykonując poniższe polecenie:
    
    ```
    rs.initiate(
      {
        _id: "configsvr",
        configsvr: true,
        members: [
          { _id : 0, host : "mongo-configsvr-0.mongo-configsvr:27019" }
        ]
      }
    )
    ```
    
    - opuść program *mongo* za pomocą polecenia `exit`, opuść powłokę  za pomocą polecenia `exit`

16. Wykonaj inicjalizację wszystkich trzech zbiorów replikacji węzłów fragmentów  w tym celu wykonaj następujące kroki:
    
    - uruchom powłokę w Pod *mongo-shard-a-0*, który jest jedynym węzłem w zbiorze replikacji węzłów framgentów o nazwie *shard-a*
      
      ```
      kubectl exec -it mongo-shard-a-0 -- /bin/bash
      ```
    
    - w powyższej powłoce, uruchom program *mongo* łącząc się do lokalnego węzła fragmentu,
    
    ```
    mongo 127.0.0.1:27018
    ```
    
    - w programie *mongo* zainicjalizuj zbiór replikacji węzłów fragmentów o nazwie *shard-a* wykonując poniższe polecenie:
    
    ```
    rs.initiate(
     {
      _id : "shard-a",
      members: [
        { _id : 0, host : "mongo-shard-a-0.mongo-shard-a:27018" }
      ]
     }
    )
    ```
    
    - opuść program *mongo* za pomocą polecenia `exit`, opuść powłokę za pomocą polecenia `exit`
    - w analogiczny sposób zainicjalizuj zbiory replikacji *shard-b* oraz *shard-c* . <mark>[Raport]</mark> 

17. Otwórz nową zakładkę terminala, którą będziemy nazywać terminalem roboczym.

18. Dodaj zbiory replikacji węzłów fragmentów do konfiguracji klastra MongoDB. W tym celu wykonaj następujące kroki: 
    
    - w terminalu roboczym uruchom powłokę w Pod *mongo-mongos-0*, który jest jedynym węzłem w zbiorze replikacji ruterów zapytań
      
      ```
      kubectl exec -it mongo-mongos-0 -- /bin/bash
      ```
    
    - w powyższej powłoce, uruchom program *mongo* łącząc się do lokalnego rutera zapytań,
      
      ```
      mongo
      ```
    
    - w programie *mongo* dodaj zbiory replikacji węzłów fragmentów do konfiguracji klastra MongoDB wykonując poniższe polecenia:
    
    ```
    sh.addShard( "shard-a/mongo-shard-a-0.mongo-shard-a:27018")
    sh.addShard( "shard-b/mongo-shard-b-0.mongo-shard-b:27018")
    sh.addShard( "shard-c/mongo-shard-c-0.mongo-shard-c:27018")
    ```

## Rozpraszanie kolekcji dokumentów na poziome fragmenty

1. W narzędziu *mongo*, które jest przyłączone do rutera zapytań przełącz się na bazę danych *test*, wykorzystaj w tym celu poniższe polecenie:
   
   ```
   use test
   ```

2. Włącz fragmentaryzację poziomą dla bazy *test*, uruchom następujące polecenie:
   
   ```
   sh.enableSharding("test")
   ```

3. Przykładowe dane, które będziemy wykorzystywać w dalszej części, opisują pomiary temperatury i są zgromadzone w 4 kolekcjach: *organizations*, *loggers*, *measurements* oraz *logger_types*. Rejestratory temperatury (ang. logger) są opisane przez ich typ, należą do określonej organizacji, zaś pomiary temperatury (ang. measurements) są zbierane przez określone rejestratory. Jako kryterium rozpraszania dokumentów w kolekcjach wybierzemy identyfikator organizacji. Jest to typowy wybór dla aplikacji udostępniającej usługi typu *Software as a Service*, gdzie dobrym kryterium rozpraszania jest identyfikator klienta takiej usługi.

4. Utwórz potrzebne kolekcje uruchamiając poniższe polecenia:
   
   ```
   db.createCollection("logger_types")
   db.createCollection("loggers")
   db.createCollection("organizations")
   db.createCollection(
    "measurements",
    {
       timeseries: {
          timeField: "me_time",
          metaField: "metadata",
          granularity: "minutes"
       }
    }
   )
   ```
   
   Polecenie utworzenia kolekcji *measurements* wymaga komentarza. Kolekcja ta została utworzona jako szereg czasowy. MongoDB optymalizuje składowanie i przetwarzanie danych składowanych w takiej kolekcji wykorzystując podane informacje za pomocą własności *timeseries*. Pole *timeField* wskazuje na pole w dokumentach kolekcji, w którym przechowywany jest czas, w naszym przypadku jest to pole *me_time*. Pole *metaField* wskazuje na pola w dokumentach kolekcji, które jednoznacznie identyfikuje szereg czasowy. W ogólności jest to identyfikator rejestratora. Jednakże w związku z tym, że będziemy chcieli fragmentaryzować poziomo tę kolekcję, to do identyfikatora rejestratora musimy dołączyć również identyfikator organizacji. Jest to wymóg mechanizmu fragmentaryzacji aby w przypadku szeregów czasowych kryterium rozpraszania bazowało na własności *metaField*. W związku z tym w dokumentach kolekcji wyodrębniono złożone pole *metadata*, które składa z pól identyfikujących rejestrator oraz organizację (*me_lo_id* i *me_or_id*). I właśnie to pole *metadata* zostało wskazane jako wartość pola *metaField* w poleceniu tworzącym kolekcję. Pole *granularity* w poleceniu określa ziarnistość wartości pola czasu *me_time*. Nasze rejestratory mierzą temperaturę najczęściej co 10 lub 15 minut, z tego powodu polu *granularity* przypisano wartość *minutes*.

5. Zdefiniuj kryterium rozpraszania kolekcji, uruchom poniższe polecenia:
   
   ```
   sh.shardCollection("test.organizations", {"_id":"hashed"})
   sh.shardCollection("test.loggers", {"lo_or_id":"hashed"})
   sh.shardCollection("test.measurements", {"metadata":"hashed"})
   ```
   
   Kolekcje *organizations* oraz *loggers* są rozpraszane wg identyfikatora organizacji z wykorzystaniem funkcji mieszającej. Kolekcja *measurements* jest rozpraszana z wykorzystaniem funkcji mieszającej wg pola *metadata*, w skład którego wchodzą pola identyfikujące rejestrator oraz organizację. Alternatywą wobec rozpraszania z wykorzystaniem funkcji mieszającej jest zastosowanie rozpraszania opartego na zakresach wartości kryterium rozpraszania. Kolekcja *logger_types* nie jest rozpraszana, ponieważ wiele organizacji może posiadać rejestratory tego samego typu, ponadto jest ona nieliczna.
   Niestety MongoDB, w odróżnieniu od rozszerzenia Citus system Postgresql, nie daje możliwości zdefiniowania kolokacji, czyli wskazania, że dokumenty pochodzące z różnych kolekcji o tej samej wartości kryterium rozpraszania będą umieszczone w tym samym węźle fragmentów.

6. W terminalu pomocniczym pobierz i rozpakuj pliki z przykładowymi dokumentami naszych kolekcji:
   
   ```
   curl www.cs.put.poznan.pl/jjezierski/RBDv2/loggers-json.tgz | tar -xzf -
   ```
   
    Zapoznaj się z zawartością plików zapisanych w katalogi *loggers-json*.

7. W terminalu pomocniczym skopiuj katalog *loggers-json* do Pod rutera zapytań:
   
   ```
   kubectl cp loggers-json mongo-mongos-0:/data
   ```

8. W terminalu roboczym opuść narzędzie *mongo* wykorzystując polecenie `exit`.

9. W terminalu roboczym zaimportuj dane z pliku */data/logger-json/logger_types.json* do kolekcji *logger_types*, wykorzystaj następujące polecenie:
   
   ```
   mongoimport --db test --collection logger_types \
    --file /data/loggers-json/logger_types.json
   ```

10. Powtórz krok 9 w celu zaimportowania dokumentów do pozostałych trzech kolekcji. <mark>[Raport]</mark>

11. W terminalu roboczym uruchom ponownie narzędzie *mongo*.

12. W narzędziu *mongo*, sprawdź status replikacji poziomej, wykorzystaj poniższe polecenie:
    
    ```
    sh.status()
    ```
    
    Fragment kolekcji składa się z części (ang. chunk), domyślna wielkość części wynosi 64 MiB. Dokumenty niefragmentowanej kolekcje są umieszczone na jednym węźle fragmentów, który jest nazywany podstawowym (ang. primary). 
    Jaki węzeł jest podstawowym dla bazy danych *test* w twoim klastrze? Na ile fragmentów są rozproszone dokumenty kolekcji znajdujących się w bazie danych *test*? Z ilu części składają się te fragmenty? <mark>[Raport]</mark>

13. Informacje o fragmentaryzowanej kolekcji można pozyskać z wykorzystaniem metody  `getShardDistribution`. Wykorzystaj ją do zaprezentowania informacji o fragmentach kolekcji *loggers*:
    
    ```
    db.loggers.getShardDistribution()
    ```
    
    Czy powyższe polecenie udostępnia dodatkowe informacje w stosunku do `sh.status()`? Jeżeli tak to jakie? <mark>[Raport]</mark> 

14. Znajdź informacje o organizacji z identyfikatorem 30:
    
    ```
    db.loggers.explain().find({lo_or_id:30})
    ```

15. Wyświetl plan zapytania odczytującego wszystkie organizacje:
    
    ```
    db.loggers.explain().find()
    ```

16. Wyświetl plan zapytania odczytującego organizację z identyfikatorem 30:
    
    ```
    db.organizations.explain().find({_id:30})
    ```
    
    Jaka jest różnica w planach z punktu 15 i 16 w kontekście odczytanych fragmentów? <mark>[Raport]</mark>

17. Wykonaj połączenie kolekcji *organizations* i *loggers*:
    
    ```
    db.organizations.aggregate([
       {
         $lookup:
           {
             from: "loggers",
             localField: "_id",
             foreignField: "lo_or_id",
             as: "loggers-of-org"
           }
      }
    ])
    ```

18. Wyświetl plan zapytania z punktu 17.

19. Wykonaj połączenie kolekcji *organizations* dla organizacji o identyfikatorze 30 i kolekcji *loggers*:
    
    ```
    db.organizations.aggregate([
      {$match: {    
        _id: 30
         }    
      },
       {
    
         $lookup:
           {
             from: "loggers",
             localField: "_id",
             foreignField: "lo_or_id",
             as: "loggers-of-org"
           }
    
      }
    ])
    ```

20. Wyświetl plan zapytania z punktu 19. Jaka jest różnica w planach z punktu 18 i 20 w kontekście odczytanych fragmentów? Czy w planach znajduje się informacja o odczytanych fragmentach z kolekcji *loggers*? Czy można domniemywać, że dokument opisujący organizację o identyfikatorze 30 znajduje się na samym węźle fragmentów co dokumenty rejestratorów należących do tej organizacji i tym samym operację połączenia system może wykonać na tylko jednym węźle fragmentów? Jeżeli nie, to jaka jest minimalna i maksymalna liczba węzłów fragmentów, które system musi wykorzystać do wykonania tego połączenia? <mark>[Raport]</mark>

21. Wykonaj połączenie kolekcji *loggers* dla organizacji o identyfikatorze 73 i kolekcji *measurements*:
    
    ```
    db.loggers.explain({executionStats:"executionStats"}).aggregate([
      {$match: {
        lo_or_id: 73
         }
      },
       {
         $lookup:
           {
             from: "logger_types",
             localField: "lo_lt_id",
             foreignField: "_id",
             as: "type-of-loggers"
           }
      }
    ])
    ```

22. Wyświetl plan zapytania z punktu 21. Jaka jest minimalna i maksymalna liczba węzłów fragmentów, które system musi wykorzystać do wykonania tego połączenia?  <mark>[Raport]</mark>

## Rozszerzenie klastra MongoDB

1. Utwórz nowy zbiór replikacji o nazwie *shrad-d*. Skorzystaj ze składni polecenia umieszczonego w punkcie 12 rozdziału *Przygotowanie środowiska*. <mark>[Raport]</mark>

2. Zainicjalizuj zbiór replikacji o nazwie *shrad-d*. Skorzystaj ze składni poleceń umieszczonych w punkcie 16 rozdziału *Przygotowanie środowiska*. <mark>[Raport]</mark>

3. Dodaj zbiór replikacji o nazwie *shrad-d* do klastra. Skorzystaj ze składni poleceń umieszczonych w punkcie 18 rozdziału *Przygotowanie środowiska*. <mark>[Raport]</mark>

4. Sprawdź rozproszenie części (chunk) kolekcji w tym celu w narzędziu `mongo` wykonaj poniższe polecenie:
   
   ```
   sh.status()
   ```
   
       Czy nowy węzeł fragmentów został wykorzystany do rozproszenia części kolekcji? <mark>[Raport]</mark>

5. Wykonaj podział części kolekcji *organizations*, w której znajduje się dokument opisujący organizację i indetyfikatorze 99:
   
   ```
   db.adminCommand( { split : "test.organizations", find : { _id : 99 } } )
   ```

6. Powtórz punkt 4.

## Skurczenie klastra MongoDB

1. Upewnij się proces równoważenia ~~~~fragmentów jest aktywny:
   
   ```
   sh.getBalancerState()
   ```

2. Zleć usunięcie węzła fragmentów o nazwie *shard-b*:
   
   ```
   db.adminCommand( { removeShard: "shard-b" } )
   ```
   
    Zwróć uwagę na pole *msg* oraz *status* wyniku zwróconego przez powyższe polecenie.

3. W celu monitorowania postępu realizacji usuwania cyklicznie powtarzaj polecenie z punktu 2 do momentu aż pole *status* przybierze wartość *completed*.

4. Sprawdź rozproszenie części (chunk) kolekcji w tym celu w narzędziu `mongo` wykonaj poniższe polecenie:
   
   ```
   sh.status()
   ```
   
   Czy węzeł fragmentów *shard-b* jest jeszcze wykorzystywany? <mark>[Raport]</mark>

5. Zwolnij zasoby wykorzystywane przez węzeł fragmentów *shard-b*, w tym celu odinstaluj instalację Helm o nazwie *mongo-shard-b*, wykonaj w terminalu pomocniczym poniższe polecenie:
   
   ```
   helm uninstall mongo-shard-b --wait
   ```

6. Helm nie usuwa kaskadowo trwałych woluminów w ramach procesu odinstalowania. W celu zwolnienia tego zasobu wykonaj w terminalu pomocniczym poniższe polecenie:
   
   ```
   kubectl delete pvc mongo-persistent-storage-mongo-shard-b-0
   ```

## Zwolnienie zasobów zajętych na potrzeby zajęć

W celu usunięcia instalacji Helm oraz trwałych woluminów, które zostały utworzone w trakcie zajęć wykonaj w terminalu pomocniczym poniższe polecenia:

```
helm uninstall mongo-mongos --wait
kubectl delete pvc mongo-persistent-storage-mongo-mongos-0
helm uninstall mongo-shard-a --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-a-0
helm uninstall mongo-shard-c --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-c-0
helm uninstall mongo-shard-d --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-d-0
helm uninstall mongo-configsvr --wait
kubectl delete pvc mongo-persistent-storage-mongo-configsvr-0
```
