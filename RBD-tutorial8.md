# VIII. Przetwarzanie rozproszone w Apache Cassandra

Celem zajęć jest zapoznanie się z przetwarzaniem rozproszonym w bazie danych Apache Cassandra.
System ten zorientowany jest na szybkie wyszukiwanie i modyfikację wartości danych na podstawie ich klucza
(klucz->wartość). Wartości danych mogą być typu prostego lub złożonego.
Typy proste mogą reprezentować teksty, liczby, wartości logiczne, daty, czas, identyfikatory UUID
i obiekty binarne. Typy złożone obejmują krotki, zbiory, listy oraz odwzorowania (ang maps).
Klucz powinien być wartością prostą lub złożeniem takich wartości, analogicznie jak klucz
podstawowy w modelu relacyjnym.

Wszystkie wartości 
Rozpraszanie poziome danych jest wykonywane na postawie funkcji haszującej,
której argumentem jest klucz danych. Wynik  funkcji haszującej
jest nazywany jest tokenem. Dziedzina wartości tokenów jest podzielona na przedziały. 
Zbiór danych, których tokeny mieszczą się jednym stanowią partycję danych. Partycje są rozpraszane
między węzła klastra. Li

## Przygotowanie środowiska

1. Zaloguj się do maszyny wirtualnej jako użytkownik rbd używając hasła RBD#7102.

2. Otwórz okno terminala, który nazwiemy terminalem pomocniczym.

3. W pierwszym kroku pobierz plik manifestów za pomocą poniższego polecenia:
   
   ```
   wget www.cs.put.poznan.pl/jjezierski/RBDv3/rbd-cassandra.yaml
   ```

4. Otwórz plik manifestów w celu jego przeglądnięcia za pomocą polecenia:
   
   ```
   less rbd-cassandra.yaml
   ```
   
   Repliki *Pod* typu *StatefulSet* wykorzystują obraz z systemem Cassandra rozszerzonym przez Google. Rozszerzenie to integruje system Cassandra z Kubernetes. Dzięki temu nie ma potrzeby ręcznego tworzenia klastra Cassandra i przydziału do niego węzłów. Kubernetes automatycznie dodaje kolejne repliki do klastra Cassandra jako jego węzły.

5. Rozpocznij wdrożenie komponentów z pliku manifestów za pomocą następującego polecenia:
   
   ```
   kubectl apply -f rbd-cassandra.yaml
   ```

6. Obserwuj postęp wdrożenia StatefulSet wykorzystując poniższe polecenie:
   
   ```
   kubectl get sts --watch
   ```
   
   Wdrożenie wymaga pobrania obrazu kontenera z repozytorium Docker, w związku z tym zajmuje chwilę. Wdrożenie zakończy się w momencie pojawienia się na terminalu wiersza, w którym liczba działających replik będzie równa liczbie żądanych replik. W naszym przypadku liczba ta równa się dwa.

7. Sprawdź status klastra Cassandra, wykonaj w terminalu pomocniczym poniższe polecenie:   
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

8. Otwórz dwie kolejne zakładki w oknie terminala wybierając z menu File pozycję New Tab. Nazwij te zakładki nazwami kolejnych replik od rbd-cassandra-0 do rbd-cassandra-1, wykorzystaj w tym celu pozycję Set Title z menu Terminal. W terminalach rbd-cassandra-0 i rbd-cassandra-1 będziemy wykonywać operacje na węzłach bazy danych uruchomionych odpowiednio w replikach rbd-cassandra-0 1 i rbd-cassandra-1.

9. Obraz kontenera systemu Cassandra przygotowany przez Google nie posiada środowiska Python co uniemożliwia uruchomienie programu `cqlsh`, który jest interpreterem poleceń systemu Cassandra. W celu rozwiązania powyższego problemu uruchomimy oddzielny Pod o nazwie cqlsh z kontenerem opartym na oficjalnym obrazie Cassandra, który jest wyposażony w odpowiednie narzędzia. W celu uruchomienia takiego Pod wykonaj w poniższe polecenie w zakładce rbd-cassandra-0: 
   
   ```bash
   kubectl run -it cqlsh --image cassandra:3.11 -- /bin/bash
   ```

10. W zakładce rbd-cassandra-0 przyłącz się do węzła rbd-cassandra-0 bazy danych za pomocą narzędzia `cqlsh` wykonując poniższe polecenie:
    
    ```
    cqlsh rbd-cassandra-0.rbd-cassandra
    ```

11. W zakładce rbd-cassandra-1 przyłącz się do Pod cqlsh wykonując polecenie:
    
    ```
    kubectl exec -it cqlsh -- /bin/bash
    ```

12. W zakładce rbd-cassandra-1 przyłącz się do węzła rbd-cassandra-1 bazy danych za pomocą narzędzia `cqlsh` wykonując poniższe polecenie:
    
    ```
    cqlsh rbd-cassandra-1.rbd-cassandra
    ```

## Transparentny dostęp do rozproszonych danych {#transparent-acess}

1. Na węźle rbd-cassandra-0 utwórz obiekt typu keyspace o nazwie test. Obiekty te są analogiczne do schematów w relacyjnych bazach danych. Dodatkowo umożliwiają określenie parametrów replikacji tabel, które zostaną w nich umieszczone.
   
   ```sql
   CREATE KEYSPACE test WITH replication = 
   {'class':'SimpleStrategy', 'replication_factor' : 1};
   ```

2. Na węźle rbd-cassandra-0 utwórz tabelę dist_tab w keyspace test. Definicja klucza podstawowego jest obowiązkowa. Może on być złożony z wielu kolumn. Pierwsza kolumna klucza jest kryterium rozpraszania wierszy na węzły klastra Cassandra.
   
   ```sql
   create table test.dist_tab(
   id int,
   tekst text,
   primary key (id));
   ```

3. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (1, 'a');
   ```

4. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

5. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

6. Na węźle rbd-cassandra-1 wstaw nowy wiersz do tabeli  test.dist_tab:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (2, 'b');
   ```

7. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

## Poziomy spójności odczytu i zapisu{#consistency-levels}

1. Na węźle rbd-cassandra-0 sprawdź ustawienie domyślnego poziomu spójności.
   
   ```sql
   consistency; 
   ```

2. Zapoznaj się z dostępnymi [poziomami spójności](https://docs.datastax.com/en/archived/cassandra/3.0/cassandra/dml/dmlConfigConsistency.html).

3. Na węźle rbd-cassandra-1 opuść narzędzie `cqlsh`:
   
   ```sql
   exit;
   ```

4. W celu zasymulowania awarii węzła rbd-cassandra-1 przeskaluj liczbę replik StatefulSet, który obsługuje klaster Cassandra do jednej, wykonaj w terminalu pomocniczym poniższe polecenie: 
   
   ```
   kubectl scale sts rbd-cassandra --replicas=1
   ```

5. W terminalu pomocniczym sprawdź status klastra:
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

6. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab <mark>\[Raport\]</mark>:
   
   ```sql
   select * from test.dist_tab;
   ```

7. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab <mark>\[Raport\]</mark>:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (3, 'c');
   ```

8. Na węźle rbd-cassandra-0 przełącz poziom spójności na *any*:
   
   ```sql
   consistency any;
   ```

9. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab <mark>\[Raport\]</mark>:
   
   ```sql
   select * from test.dist_tab;
   ```

10. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab <mark>\[Raport\]</mark>:
    
    ```sql
    insert into test.dist_tab(id, tekst) values (3, 'c');
    ```

11. W terminalu pomocniczym sprawdź status klastra Cassandra:
    
    ```bash
    kubectl exec -it rbd-cassandra-0 -- nodetool status 
    ```
    
    Skopiuj do schowka identyfikator hosta węzła, który wcześniej został zatrzymany przez zmianę liczby replik. Posiada on status DN.

12. W terminalu pomocniczym usuń zatrzymany węzeł klastra Cassandra, użyj identyfikatora ze schowka.
    
    ```
    kubectl exec -it rbd-cassandra-0 -- nodetool removenode "Host ID"
    ```

13. W terminalu pomocniczym sprawdź ponownie status klastra Cassandra 

14. Uruchom węzeł rbd-cassandra-1 zwiększając liczbę replik StatefulSet do dwóch. Uruchom w terminalu pomocniczym poniższe polecenie:
    
    ```bash
    kubectl scale sts rbd-cassandra --replicas=2
    ```

15. Monitoruj uruchamianie repliki wykorzystując w terminalu poniższe polecenie:
    
    ```
    kubectl get sts --watch
    ```

16. Na węźle rbd-cassandra-1 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
    
    ```bash
    cqlsh rbd-cassandra-1.rbd-cassandra
    ```

17. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test.dist_tab <mark>\[Raport\]</mark>:
    
    ```sql
    select * from test.dist_tab;
    ```
18. Na węźle rbd-cassandra-0 przełącz poziom izolacji na *one*:
    
    ```sql
    consistency one;
    ```
19. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab <mark>\[Raport\]</mark>:
    
    ```sql
    select * from test.dist_tab;
    ```
	
## Odporność na awarię {#robustness}

1. Na węźle rbd-cassandra-0 utwórz obiekt keyspace o nazwie test2 z współczynnikiem replikacji równym dwa. 
   
   ```sql
   CREATE KEYSPACE test2 WITH replication = 
   {'class':'SimpleStrategy', 'replication_factor' : 2};
   ```

2. Na węźle rbd-cassandra-0 utwórz tabelę dist_tab2 w keyspace test2. 
   
   ```sql
   create table test2.dist_tab2(
   id int,
   tekst text,
   primary key (id));
   ```

3. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli test2.dist_tab2:
   
   ```sql
   insert into test2.dist_tab2(id, tekst) values (4, 'e');
   ```

4. W celu zasymulowania awarii węzła rbd-cassandra-1 przeskaluj liczbę replik StatefulSet, który obsługuje klaster Cassandra do jeden, wykonaj w terminalu pomocniczym poniższe polecenie: 
   
   ```
   kubectl scale sts rbd-cassandra --replicas=1
   ```

5. W terminalu pomocniczym sprawdź status klastra:
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

6. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test2.dist_tab2 <mark>\[Raport\]</mark>:
   
   ```sql
   insert into test2.dist_tab2(id, tekst) values (5, 'f');
   ```

7. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test2.dist_tab2 <mark>\[Raport\]</mark>:
   
   ```sql
   select * from test2.dist_tab2;
   ```

8. W terminalu pomocniczym sprawdź status klastra Cassandra:
   
   ```bashcreate
   kubectl exec -it rbd-cassandra-0 -- nodetool status 
   ```
   
    Skopiuj do schowka identyfikator hosta węzła, który wcześniej został zatrzymany przez zmianę liczby replik. Posiada on status DN.

9. W terminalu pomocniczym usuń zatrzymany węzeł klastra Cassandra, użyj identyfikatora ze schowka.
   
   ```
   kubectl exec -it rbd-cassandra-0 -- nodetool removenode "Host ID"
   ```

10. W terminalu pomocniczym sprawdź ponownie status klastra Cassandra.

11. Uruchom węzeł rbd-cassandra-1 zwiększając liczbę replik StatefulSet do dwóch. Uruchom w terminalu pomocniczym poniższe polecenie:
    
    ```bash
    kubectl scale sts rbd-cassandra --replicas=2
    ```

12. Monitoruj uruchamianie repliki wykorzystując w terminalu poniższe polecenie:
    
    ```
    kubectl get sts --watch
    ```

13. Na węźle rbd-cassandra-1 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
    
    ```
    cqlsh rbd-cassandra-1.rbd-cassandra
    ```

14. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test2.dist_tab2 <mark>\[Raport\]</mark>:
    
    ```sql
    select * from test2.dist_tab2;
    ```

## Dołączenie nowego węzła do klastra {#node-creation}

1. Uruchom węzeł rbd-cassandra-2 zwiększając liczbę replik StatefulSet do trzech. Uruchom w terminalu pomocniczym poniższe polecenie:
   
   ```bash
   kubectl scale sts rbd-cassandra --replicas=3
   ```

2. Monitoruj uruchamianie repliki wykorzystując w terminalu poniższe polecenie:
   
   ```
   kubectl get sts --watch
   ```

3. W terminalu pomocniczym sprawdź status klastra:
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

4. Otwórz nową zakładkę terminala, nazwij ją rbd-cassandra-2. W zakładce rbd-cassandra-2 przyłącz się do Pod cqlsh:
   
   ```bash
   kubectl exec -it cqlsh -- /bin/bash
   ```

5. W zakładce rbd-cassandra-2 przyłącz się do węzła rbd-cassandra-2 klastra Cassandra:
   
   ```
   cqlsh rbd-cassandra-2.rbd-cassandra
   ```

6. Na węźle rbd-cassandra-2 odczytaj zawartość tabeli  test2.dist_tab2 <mark>\[Raport\]</mark>:
   
   ```sql
   select * from test2.dist_tab2;
   ```

7. W terminalu pomocniczym wyczyść węzeły rbd-cassandra-0 i rbd-cassandra-1 z danych, które zostały przemieszczone do węzła rbd-cassandra-2.
   
   ```
   kubectl exec -it rbd-cassandra-0 -- nodetool cleanup
   kubectl exec -it rbd-cassandra-1 -- nodetool cleanup
   ```

## Usunięcia węzła z klastra {#node-removal}

1. Na węźle rbd-cassandra-2 opuść narzędzia cqlsh:
   
   ```sql
   exit;
   ```

2. W terminalu pomocniczym przekaż dane węzła rbd-cassandra-2 do innych węzłów klastra:
   
   ```
   kubectl exec -it rbd-cassandra-2 -- nodetool decommission
   ```

3. W terminalu pomocniczym monitoruj postęp operacji:
   
   ```
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

4. W terminalu pomocniczym usuń Pod rbd-cassandra-2 zmniejszając liczbę replik StatefulSet rbd-cassandra do dwóch:
   
   ```
   kubectl scale sts rbd-cassandra --replicas=2
   ```

5. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test2.dist_tab2 <mark>\[Raport\]</mark>:
   
   ```sql
   select * from test2.dist_tab2;
   ```