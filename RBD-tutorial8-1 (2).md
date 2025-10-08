# VIII.    Przetwarzanie rozproszone w Apache Cassandra

Celem zajęć jest zapoznanie się przetwarzaniem rozproszonym w bazie danych [Apache Cassandra](https://pl.wikipedia.org/wiki/Apache_Cassandra)

###### Zagadnienia:

1. [Transparentny dostęp do rozproszonych danych](#transparent-acess)
2. [Poziomy spójności odczytu i zapisu](#consistency-levels)
3. [Dołączenie nowego węzła do klastra](#node-creation)
4. [Odporność na awarię](#robustness)
5. [Usunięcia węzła z klastra](#node-removal)

## Przygotowanie środowiska

1. Zaloguj się do maszyny wirtualnej jako użytkownik rbd używając hasła RBD#7102.

2. Otwórz okno terminala, który nazwiemy terminalem pomocniczym.

3. W pierwszym kroku pobierz plik manifestów za pomocą poniższego polecenia:
   
   ```
   wget www.cs.put.poznan.pl/jjezierski/RBDv2/rbd-cassandra.yaml
   ```

4. Otwórz plik manifestów w celu jego przeglądnięcia za pomocą polecenia:
   
   ```
   less rbd-cassandra.yaml
   ```

5. Rozpocznij wdrożenie komponentów z pliku manifestów za pomocą polecenia:
   
   ```
   kubectl apply -f rbd-cassandra.yaml
   ```

6. Obserwuj postęp wdrożenia StatefulSet wykorzystując poniższe polecenie:
   
   ```
   kubectl get sts --watch
   ```
   
   Wdrożenie wymaga pobranie obrazu kontenera z repozytorium Docker, w związku z tym zajmuje chwilę. Wdrożenie zakończy się w momencie pojawienia się na terminalu wiersza, w którym liczba działających replik będzie równa liczbie żądanych replik. W naszym przypadku liczba ta równa się dwa.

7. Sprawdź status klastra Cassandra, wykonaj w terminalu pomocniczym poniższe polecenie:   
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

8. Otwórz dwie kolejne zakładki w oknie terminala wybierając z menu File pozycję New Tab. Nazwij te zakładki nazwami kolejnych replik od rbd-cassandra-0 do rbd-cassandra-1, wykorzystaj w tym celu pozycję Set Title z menu Terminal. W terminalach rbd-cassandra-0 i rbd-cassandra-1 będziemy wykonywać operacje na węzłach bazy danych uruchomionych odpowiednio w replikach rbd-cassandra-0 1 i rbd-cassandra-1.

9. Obraz kontenera systemu Cassandra przygotowany przez Google nie posiada środowiska Python co uniemożliwia uruchomienie programu `cqlsh`, który jest interpreterem poleceń systemu Cassandra. W celu rozwiązania powyższego problemu uruchomimy oddzielny Pod o nazwie cqlsh z kontenerem opartym na oficjalnym obrazie Cassandra, który jest wyposażony w odpowiednie narzędzia. W celu uruchomienia takiego Pod wykonaj w poniższe polecenie w zakładce rbd-cassandra-0: 
   
   ```bash
   kubectl run -it cqlsh  --image cassandra:3.11 -- /bin/bash
   ```

10. W zakładce rbd-cassandra-0 przyłącz się do węzła rbd-cassandra-0 bazy danych za pomocą narzędzia `cqlsh` wykonując poniższe polecenie:
    
    ```
    cqlsh rbd-cassandra-0.rbd-cassandra
    ```

11. W zakładce rbd-cassandra-0 przyłącz się do Pod cqlsh wykonując polecenie:
    
    ```
    kubectl exec -it cqlsh -- /bin/bash
    ```

12. W zakładce rbd-cassandra-1 przyłącz się do węzła rbd-cassandra-1 bazy danych za pomocą narzędzia `cqlsh` wykonując poniższe polecenie:
    
    ```
    cqlsh rbd-cassandra-1.rbd-cassandra
    ```

## Transparentny dostęp do rozproszonych danych {#transparent-acess}

2. Na węźle rbd-cassandra-0 utwórz obiekt typu keystore o nazwie test. Obiekty te są analogiczne do schematów w relacyjnych bazach danych. Dodatkowo umożliwiają określenie parametrów replikacji tabel, które zostaną w nich umieszczone.
   
   ```sql
   CREATE KEYSPACE test WITH replication = 
   {'class':'SimpleStrategy', 'replication_factor' : 1};
   ```

3. Na węźle rbd-cassandra-0 utwórz tabelę dist_tab w keystore test. Definicja klucza podstawowego jest obowiązkowa. Może on być złożony z wielu kolumn. Pierwsza kolumna klucza jest kryterium rozpraszania wierszy na węzły klastra Cassandra.
   
   ```sql
   create table test.dist_tab(
   id int,
   tekst text,
   primary key (id));
   ```

4. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (1, 'a');
   ```

5. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

6. Na węźle rbd-cassandra-1 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
   
   ```bash
   cqlsh rsbd2
   ```

7. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

8. Na węźle rbd-cassandra-1 wstaw nowy wiersz do tabeli  test.dist_tab:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (2, 'b');
   ```

9. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab:
   
   ```sql
   select * from test.dist_tab;
   ```

## Poziomy spójności odczytu i zapisu{#consistency-levels}

1. Na węźle rbd-cassandra-0 sprawdź ustawienie domyślnego poziomu spójności.
   
   ```sql
   consistency; 
   ```

2. Zapoznaj się z dostępnymi [poziomami spójności](https://docs.datastax.com/en/archived/cassandra/3.0/cassandra/dml/dmlConfigConsistency.html).

3. Na węźle rbd-cassandra-1 opuść narzędzia cqlsh:
   
   ```sql
   exit;
   ```

4. W celu zasymulowania awarii węzła rbd-cassandra-1 przeskaluj liczbę replik StatefulSet, który obsługuje klaster Cassandra do jeden, wykonaj w terminalu pomocniczym poniższe polecenie: 
   
   ```
   kubectl  scale sts rbd-cassandra --replicas=1
   ```

6. W terminalu pomocniczym sprawdź status klastra:
   
   ```bash
   kubectl exec -it rbd-cassandra-0 -- nodetool status
   ```

7. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab [Raport]:
   
   ```sql
   select * from test.dist_tab;
   ```

8. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab [Raport]:
   
   ```sql
   insert into test.dist_tab(id, tekst) values (3, 'c');
   ```

9. Na węźle rbd-cassandra-0 przełącz poziom spójności na any:
   
   ```sql
   consistency any;
   ```

10. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab [Raport]:
    
    ```sql
    select * from test.dist_tab;
    ```

11. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test.dist_tab [Raport]:
    
    ```sql
    insert into test.dist_tab(id, tekst) values (3, 'c');
    ```

12. W terminalu pomocniczym sprawdź status klastra Cassandra:
    
    ```bash
    kubectl exec -it rbd-cassandra-0 -- nodetool status 
    ```
Skopiuj do schowka identyfikator hosta węzła, który wcześniej został zatrzymany przez zmianę liczby replik. Posiada on status DN.

12. W terminalu pomocniczym usuń zatrzymany węzeł klastra Cassandra, użyj identyfikatora ze schowka.
    ```
    kubectl exec -it rbd-cassandra-0 -- nodetool removenode "Host ID"
    ```

13. W terminalu pomocniczym sprawdź ponownie status klastra Cassandra 
13. Uruchom węzeł rbd-cassandra-1 zwiększając liczbę replik StatefulSet do dwóch. Uruchom w terminalu pomocniczym poniższe polecenie:
    
    ```bash
    kubectl scale sts rbd-cassandra --replicas=2
    ```
14. Monitoruj uruchamianie repliki wykorzystując w terminalu poniższe polecenie:
    ```
    kubectl get sts --watch
    ```
14. Na węźle rbd-cassandra-1 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
    
    ```bash
    cqlsh rbd-cassandra-1.rbd-cassandra
    ```

15. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test.dist_tab [Raport]::
    
    ```sql
    select * from test.dist_tab;
    ```

16. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab [Raport]:
    
    ```sql
    select * from test.dist_tab;
    ```

17. Na węźle rbd-cassandra-0 przełącz poziom izolacji na one:
    
    ```sql
    consistency one;
    ```
    ## Odporność na awarię {#robustness}


```
Na węźle rbd-cassandra-1 sprawdź identyfikator procesu javy, Casssandra.
    
    ```
    ps -ef | grep cassandra
    ```

27. Na węźle rbd-cassandra-1 zasymuluj awarię węzła klastra przez zabicie procesu silnika Casssandra:
    
    ```
    kill -9 pid
    ```

28. Na węźle rbd-cassandra-0 otwórz terminal pomocniczy i sprawdź status klastra:
    
    ```
    nodetool status
    ```

29. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test.dist_tab [Raport]:
    
    ```
    select * from test.dist_tab;
    ```

30. Na węźle rbd-cassandra-1 uruchom silnik Cassandra.
    
    ```
    service cassandra start
    ```

31. Na węźle rbd-cassandra-0 w terminalu pomocniczym sprawdź status klastra:
    
    ```
    nodetool status 
    ```

32. Na węźle rbd-cassandra-0 utwórz obiekt keystore o nazwie test2 z wpółczynnikiem replikacji równym dwa. 
    
    ```sql
    CREATE KEYSPACE test2 WITH replication = 
    {'class':'SimpleStrategy', 'replication_factor' : 2};
    ```

33. Na węźle rbd-cassandra-0 utwórz tabelę dist_tab2 w keystore test2. 
    
    ```sql
    create table test2.dist_tab2(
    id int,
    tekst text,
    primary key (id));
    ```

34. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test2.dist_tab2:
    
    ```sql
    insert into test2.dist_tab2(id, tekst) values (4, 'e');
    ```

35. Na węźle rbd-cassandra-1 sprawdź identyfikator procesu javy, Casssandra.
    
    ```
    ps -ef | grep cassandra 
    ```

36. Na węźle rbd-cassandra-1 zasymuluj awarię węzła klastra przez zabicie procesu silnika Casssandra:
    
    ```
    kill -9 pid
    ```

37. Na węźle rbd-cassandra-0 otwórz terminal pomocniczy i sprawdź status klastra:
    
    ```
    nodetool status
    ```

38. Na węźle rbd-cassandra-0 wstaw nowy wiersz do tabeli  test2.dist_tab2 [Raport]:
    
    ```sql
    insert into test2.dist_tab2(id, tekst) values (5, 'f');
    ```

39. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test2.dist_tab2 [Raport]:
    
    ```sql
    select * from test2.dist_tab2;
    ```

40. Na węźle rbd-cassandra-3 odczytaj zawartość tabeli  test2.dist_tab2 [Raport]:
    
    ```sql
    select * from test2.dist_tab2;
    ```

41. Na węźle rbd-cassandra-1 uruchom silnik Cassandra.
    
    ```
    service cassandra start
    ```

42. Na węźle rbd-cassandra-1 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
    
    ```
    cqlsh rsbd2
    ```

43. Na węźle rbd-cassandra-1 odczytaj zawartość tabeli  test2.dist_tab2 [Raport]:
    
    ```sql
    select * from test2.dist_tab2;
    ```    
    ## Dołączenie nowego węzła do klastra {#node-creation}

18. Uruchom kolejny terminal i połącz się w nim do maszyny rsbd3 jako użytkownik root, podaj hasło RSBD#7102.
    ssh rsbd3

19. Na węźle rbd-cassandra-3 powtórz kroki z rozdziału 2 od 4 do 12. Zwróć uwagę na zamianę zaznaczonych na czerwono cyfr 1 na 3. Ważne: w kroku 10 ustaw parametr auto_bootstrap na wartość true;

20. Na węźle rbd-cassandra-3 monitoruj przyłączanie węzła rsdb3 do klastra. W czasie przyłączania następuje rozpraszanie danych do nowo dodawanego węzeł, w środowisku produkcyjnym proces ten może silnie obciążać klaster. Poczekaj aż status węzła rsbd3 zmieni się na UN.
    
    ```bash
    nodetool status
    ```

21. Na węźle rbd-cassandra-0 w terminalu pomocniczym wyczyść węzeł rsdb1 z danych, które zostały przemieszczone do węzła rsbd3.
    
    ```bash
    nodetool  cleanup
    ```

22. Na węźle rbd-cassandra-1 opuść narzędzia cqlsh:
    
    ```sql
    exit;
    ```

23. Powtórz krok 4 dla maszyny rsbd2.

24. Na węźle rbd-cassandra-3 przyłącz się do bazy danych za pomocą narzędzia cqlsh.
    
    ```bash
    cqlsh rsbd3
    ```

25. Na węźle rbd-cassandra-3 odczytaj zawartość tabeli  test.dist_tab:
    
    ```sql
    select * from test.dist_tab;
    ```
    

    
    ## Usunięcia węzła z klastra {#node-removal}

44. Na węźle rbd-cassandra-1 opuść narzędzia cqlsh:
    
    ```sql
    exit;
    ```

45. Na węźle rbd-cassandra-1 przekaż dane węzła rsbd2 do innych węzłów klastra:
    
    ```
    nodetool decommission
    ```

46. Na węźle rbd-cassandra-0 w terminalu pomocniczym monitoruj postęp operacji:
    
    ```
    nodetool status
    ```

47. Na węźle rbd-cassandra-0 odczytaj zawartość tabeli  test2.dist_tab2 [Raport]:
    
    ```sql
    select * from test2.dist_tab2;
    ```