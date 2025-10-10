# Przetwarzanie rozproszone w MongoDB

Celem zajęć jest zapoznanie się z własnościami [MongoDB](https://www.mongodb.com/) umożliwiającymi przetwarzanie rozproszone. MongoDB udostępnia asynchroniczną replikację danych typu single master z automatycznym przełączaniem awaryjnym. Niniejsze ćwiczenia jest poświęcone konfiguracji i testowaniu tego mechanizmu.

## Przygotowanie środowiska

1. Zaloguj się do maszyny wirtualnej jako użytkownik *rbd* używając hasła *RBD#7102*.

2. Otwórz okno terminala, który nazwiemy terminalem pomocniczym.

3. Zainstaluj narzędzie `git`, w tym celu wykonaj w terminalu pomocniczym następujące polecenie:
   
   ```
   sudo yum -y install git
   ```

4. Pobierz źródła operatora Kubernetes dla MongoDB w wersji Community, uruchom w terminalu poniższe polecenie:
   
   ```
   git clone https://github.com/mongodb/mongodb-kubernetes-operator.git
   ```

5. Zmień katalog roboczy na katalog z pobranymi w poprzednim kroku źródłami:
   
   ```
   cd mongodb-kubernetes-operator
   ```

6. Zainstaluj zasoby operatora wydając w terminalu pomocniczym następujące polecenie:
   
   ```
   kubectl apply -f \
     config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
   ```

7. Zainstaluj dodatkowe role uruchamiając poniższe polecenie:
   
   ```
   kubectl apply -k config/rbac/
   ```

8. Zainstaluj operator wydając w terminalu pomocniczym następujące polecenie:
   
   ```
   kubectl create -f config/manager/manager.yaml
   ```

9. W pierwszym kroku pobierz plik manifestów za pomocą poniższego polecenia:
   
   ```
   wget www.cs.put.poznan.pl/jjezierski/RBDv2/rbd-mongodb.yaml
   ```

10. Otwórz plik manifestów w celu jego przeglądnięcia za pomocą polecenia:
    
    ```
    less rbd-mongodb.yaml
    ```

11. Rozpocznij wdrożenie komponentów z pliku manifestów za pomocą następującego polecenia:
    
    ```
    kubectl apply -f rbd-mongodb.yaml
    ```

12. Obserwuj postęp wdrożenia StatefulSet wykorzystując poniższe polecenie:
    
    ```
    kubectl get sts --watch
    ```
    
    Wdrożenie wymaga pobrania obrazu kontenera z repozytorium Docker, w związku z tym zajmuje chwilę. Wdrożenie zakończy się w momencie pojawienia się na terminalu wiersza, w którym liczba działających replik będzie równa liczbie żądanych replik. W naszym przypadku liczba ta równa się trzy.

13. Otwórz trzy kolejne zakładki w terminalu, wybierając z menu File pozycję New Tab. Nazwij te zakładki nazwami kolejnych replik od rbd-mongodb-0 do rbd-mongodb-2, wykorzystaj w tym celu pozycję Set Title z menu Terminal. W terminalach rbd-mongodb-0, rbd-mongodb-1, rbd-mongodb-2 będziemy wykonywać operacje na węzłach bazy danych uruchomionych odpowiednio w replikach rbd-mongodb-0, rbd-mongodb-1 i rbd-mongodb-2.

14. W zakładce rbd-mongodb-0 przyłącz się do repliki Pod rbd-mongodb-0, wykorzystaj poniższe polecenie:
    
    ```
    kubectl exec -it rbd-mongodb-0 --container mongod -- /bin/bash
    ```
    
    Zauważ, że przyłączenie zostało wykonane do kontenera *mongodb*. Każda replika tego Pod zawiera dwa działające kontenery. Kontener *mongodb*  zawiera instancję bazy danych MongoDB, natomiast kontener *mongodb-agent* zawiera agenta bazy danych, który monitoruje jej działanie. 

15. W zakładce *rbd-mongo-0* przyłącz się do węzła *rbd-mongo-0* bazy danych jako użytkownik *rbd-admin* za pomocą narzędzia `mongo` wykonując poniższe polecenie:
    
    ```
    mongo --username rbd-admin --password rbd-mongo
    ```

16. W  węźle *rbd-mongo-0*, sprawdź role poszczególnych baz danych, wykorzystaj poniższe polecenie <mark>[Raport]</mark>:
    
    ```js
    rs.status().members.forEach( 
      function(z){ 
        printjson(z.name);
        printjson(z.stateStr);
      } 
    );
    ```

17. Użytkownik *rbd-admin* nie posiada uprawnień do tworzenia kolekcji dokumentów i nie może przyznać sobie odpowiednich uprawnień. W związku z tym w węźle *rbd-mongo-0* utwórz użytkownika *rbd-user* z rolą *root*:
    
    ```js
    use admin;
    db.createUser(
        {
          user: "rbd-user",
          pwd: "rbd-mongo",
          roles: [
             { role: "readWrite", db: "test" }
          ]
        }
    );
    ```

18. W zakładce *rbd-mongo-0* opuść narzędzie `mongo`:
    
    ```
    exit;
    ```

19. W zakładce *rbd-mongo-0* przyłącz się do węzła *rbd-mongo-0* bazy danych jako użytkownik *rbd-user* za pomocą narzędzia `mongo` wykonując poniższe polecenie:
    
    ```
    mongo --username rbd-user --password rbd-mongo
    ```

20. Powtórz odpowiednio zmodyfikowane kroki z punktu 14 i 19 dla węzłów *rbd-mongo-1* i *rbd-mongo-2*.

## Testowanie mechanizmu replikacji danych

1. W powłoce Mongo repliki *rbd-mongo-0* utwórz przykładowy dokument w kolekcji *pracownicy*.
   
   ```
   db.pracownicy.insertOne({nazwisko: "Kowalski", etat: "Stazysta",placa: 2222})
   ```

2. W powłoce Mongo repliki *rbd-mongo-1* spróbuj odczytać zawartość kolekcji *pracownicy*. <mark>[Raport]</mark>
   
   ```
   db.pracownicy.find()
   ```

3. W powłoce Mongo repliki *rbd-mongo-1* uaktywnij opcję odczyt danych, opcja jest aktywna na czas działania sesji:
   
   ```
   rs.secondaryOk()
   ```

4. Powtórz krok 2.

5. Powtórz kroki 3 i 2 w powłoce Mongo repliki *rbd-mongo-2*.

6. W powłoce Mongo repliki *rbd-mongo-1* spróbuj dodać nowy dokument do kolekcji *pracownicy*. <mark>[Raport]</mark>

## Testowanie mechanizmu przełączenia awaryjnego

1. Otwórz nową zakładkę w oknie terminala, będziemy ja nazywać terminalem monitora.

2. W terminalu monitora uruchom poniższe polecenie aby monitorować zdarzenia klastra Kuberneters:
   
   ```
   kubectl get events --watch
   ```

3. W terminalu pomocniczym zasymuluj awarię repliki *rbd-mongo-1* typu *secondary*, wysyłając sygnał SIGTERM do procesu o identyfikatorze 1, którym jest proces *mongod*:
   
   ```
   kubectl exec -it rbd-mongodb-1 --container mongod -- /usr/bin/kill 1
   ```

4. W powłoce Mongo repliki *rbd-mongo-0* utwórz kolejny dokument w kolekcji *pracownicy*. <mark>[Raport]</mark>
   
   ```
   db.pracownicy.insertOne({nazwisko: "Malińska", etat: "Asystent",placa: 3222})
   ```

5. W powłoce Mongo repliki *rbd-mongo-2* spróbuj odczytać zawartość kolekcji *pracownicy*. <mark>[Raport]</mark>
   
   ```
   db.pracownicy.find()
   ```

6. W terminalu monitora sprawdź postęp ponownego uruchomienia repliki *rbd-mongo-1*, po zakończeniu procesu uruchamiania w odpowiedniej zakładce ponownie połącz się do repliki *rbd-mongo-1*, następnie uruchom powłokę `mongo` i sprawdź zawartość kolekcji *pracownicy*. Nie zapomnij o poleceniu `rs.secondaryOk()`. <mark>[Raport]</mark>

7. W terminalu pomocniczym zasymuluj awarię repliki *rbd-mongo-1* i *rbd-mongo-2* typu *secondary*:
   
   ```
   kubectl exec -it rbd-mongodb-1 --container mongod -- /usr/bin/kill 1
   kubectl exec -it rbd-mongodb-2 --container mongod -- /usr/bin/kill 1
   ```

8. W powłoce Mongo repliki *rbd-mongo-0* spróbuj utworzyć kolejny dokument w kolekcji *pracownicy*. <mark>[Raport]</mark>
   
   ```
   db.pracownicy.insertOne({nazwisko: "Nowak", etat: "Dyrektor",placa: 4222})
   ```

9. W powłoce Mongo repliki *rbd-mongo-0* odczytaj zawartość kolekcji *pracownicy*. <mark>[Raport]</mark>
   
   ```
   db.pracownicy.find()
   ```

10. W terminalu monitora sprawdź postęp ponownego uruchomienia replik *rbd-mongo-1* i rbd-mongo-2, po zakończeniu procesu uruchamiania odzyskaj powłoki replik *rbd-mongo-1* i *rbd-mongo-2*. Następnie sprawdź w nich zawartość  kolekcji *pracownicy*. Nie zapomnij o poleceniu `rs.secondaryOk()`. <mark>[Raport]</mark>

11. W zakładce *rbd-mongo-1* opuść powłokę `mongo`:
    
    ```
    exit;
    ```

12. W zakładce *rbd-mongo-1* uruchom powłokę `mongo` przyłączając się do bazy danych jako użytkownik `rbd-admin`
    
    ```
    mongo --username rbd-admin --password rbd-mongo
    ```

13. W terminalu pomocniczym zasymuluj awarię repliki *rbd-mongo-0* typu *primary*:
    
    ```
    kubectl exec -it rbd-mongodb-0 --container mongod -- /usr/bin/kill 1
    ```

14. W węźle *rbd-mongo-1*, sprawdź role poszczególnych baz danych, wykorzystaj poniższe polecenie <mark>[Raport]</mark>:
    
    ```js
    rs.status().members.forEach( 
      function(z){ 
        printjson(z.name);
        printjson(z.stateStr);
      } 
    );
    ```

15. W terminalu monitora sprawdź postęp ponownego uruchomienia repliki *rbd-mongo-0* , po zakończeniu procesu uruchamiania odzyskaj powłokę replikę *rbd-mongo-0* . Następnie sprawdź w niej zawartość kolekcji *pracownicy*. Nie zapomnij o poleceniu `rs.secondaryOk()`. <mark>[Raport]</mark>

## Dodanie arbitra do zbioru replikacji

Zadaniem arbitra jest zwiększenie liczby węzłów zapewniających kworum w głosowaniu przy ustalaniu statusu replikacji. Arbiter nie replikuje danych w związku z tym nie jest mocno obciążony i może być skonfigurowany na maszynie, która pełni inne funkcje np. wspiera serwer aplikacji.

1. Wersja 0.7.2 operatora Kubernetes dla MongoDB nie wspiera poprawnie rekonfiguracji przez dodanie do klastra nowych węzłów, które są arbitrami. Z tego powodu usuniemy obiekty utworzone w pierwszym punkcie i po modyfikacji manifestu wdrożymy je ponownie. Oczywiście taka operacja wiąże się z utratą danych.
   
   ```
   kubectl delete -f rbd-mongodb.yaml
   kubectl delete pvc data-volume-rbd-mongodb-0
   kubectl delete pvc data-volume-rbd-mongodb-1
   kubectl delete pvc data-volume-rbd-mongodb-2
   kubectl delete pvc logs-volume-rbd-mongodb-0
   kubectl delete pvc logs-volume-rbd-mongodb-1
   kubectl delete pvc logs-volume-rbd-mongodb-2
   ```

2. Użyj ulubionego edytora tekstu w celu modyfikacji pliku manifestu *rbd-mongodb.yaml*. Dodaj poniższy wpis bezpośrednio pod kluczem *spec*, zwróć uwagę na cztery wiodące spacje:
   
   ```yaml
     arbiters: 2
   ```
   
   Zwiększ liczbę replik do pięciu, zmień klucz *members*
   
   ```yaml
     members: 5
   ```
   
   Powyższa konfiguracja utworzy pięć węzłów, w tym dwa z nich będą arbitrami.

3. Wykonaj wdrożenie zmodyfikowanego manifestu:
   
   ```
   kubectl apply -f rbd-mongodb.yaml
   ```

4. Obserwuj postęp wdrożenia StatefulSet wykorzystując poniższe polecenie:
   
   ```
   kubectl get sts --watch
   ```
   
    Wdrożenie zakończy się w momencie pojawienia się na terminalu wiersza, w którym liczba działających replik będzie równa liczbie żądanych replik. W naszym przypadku liczba ta równa się pięć.

5. Przywróć połączenie do repliki *rbd-mongo-2* jako użytkownik *rbd-admin* i sprawdź role poszczególnych węzłów:
   
   ```js
   rs.status().members.forEach( 
     function(z){ 
       printjson(z.name);
       printjson(z.stateStr);
     } 
   );
   ```

6. W terminalu pomocniczym zasymuluj awarię repliki *rbd-mongo-3* i *rbd-mongo-4* typu *secondary*:
   
   ```
   kubectl exec -it rbd-mongodb-3 --container mongod -- /usr/bin/kill 1
   kubectl exec -it rbd-mongodb-4 --container mongod -- /usr/bin/kill 1
   ```

7. W węźle *rbd-mongo-2*, sprawdź role poszczególnych baz danych.

8. W terminalu monitora sprawdź postęp ponownego uruchomienia replik *rbd-mongo-3* i  *rbd-mongo-4*, po zakończeniu procesu uruchamiania sprawdź role poszczególnych baz danych. <mark>[Raport]</mark>

## Zwolnienie zasobów zajętych na potrzeby zajęć

W celu usuniecia StatefulSet oraz trwałych woluminów, które zostały utworzone w trakcie zajęć wykonaj w terminalu pomocniczym poniższe polecenia:

```
kubectl delete -f rbd-mongodb.yaml
kubectl delete pvc data-volume-rbd-mongodb-0
kubectl delete pvc data-volume-rbd-mongodb-1
kubectl delete pvc data-volume-rbd-mongodb-2
kubectl delete pvc data-volume-rbd-mongodb-3
kubectl delete pvc data-volume-rbd-mongodb-4
kubectl delete pvc logs-volume-rbd-mongodb-0
kubectl delete pvc logs-volume-rbd-mongodb-1
kubectl delete pvc logs-volume-rbd-mongodb-2
kubectl delete pvc logs-volume-rbd-mongodb-3
kubectl delete pvc logs-volume-rbd-mongodb-4
```
