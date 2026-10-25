-- =====================================================
-- PROJEKT DATACO | setup + import + audyt+pytania
-- Baza: supply_chain, schemat: logistics
-- Dane: DataCo Smart Supply Chain (Kaggle), 180 519 wierszy, 53 kolumny
-- =====================================================

-- dzięki temu wystarczy "from raw" (działa do końca sesji)
SET search_path TO logistics, public;


-- =====================================================
-- 1. SETUP (robione raz)
-- =====================================================
-- CREATE DATABASE supply_chain;
-- CREATE SCHEMA logistics;
-- Po utworzeniu bazy sprawdzam, czy jestem w dobrej:
SELECT current_database();   -- ma być supply_chain


-- =====================================================
-- 2. TABELA RAW + IMPORT
-- =====================================================
-- Wszystko jako TEXT. Typy ustawię dopiero w clean.
-- Uwaga: DROP kasuje też dane, po imporcie nie odpalać.
/*DROP TABLE IF EXISTS logistics.raw; */

CREATE TABLE logistics.raw (
    type TEXT,
    days_for_shipping_real TEXT,
    days_for_shipment_scheduled TEXT,
    benefit_per_order TEXT,
    sales_per_customer TEXT,
    delivery_status TEXT,
    late_delivery_risk TEXT,
    category_id TEXT,
    category_name TEXT,
    customer_city TEXT,
    customer_country TEXT,
    customer_email TEXT,
    customer_fname TEXT,
    customer_id TEXT,
    customer_lname TEXT,
    customer_password TEXT,
    customer_segment TEXT,
    customer_state TEXT,
    customer_street TEXT,
    customer_zipcode TEXT,
    department_id TEXT,
    department_name TEXT,
    latitude TEXT,
    longitude TEXT,
    market TEXT,
    order_city TEXT,
    order_country TEXT,
    order_customer_id TEXT,
    order_date TEXT,
    order_id TEXT,
    order_item_cardprod_id TEXT,
    order_item_discount TEXT,
    order_item_discount_rate TEXT,
    order_item_id TEXT,
    order_item_product_price TEXT,
    order_item_profit_ratio TEXT,
    order_item_quantity TEXT,
    sales TEXT,
    order_item_total TEXT,
    order_profit_per_order TEXT,
    order_region TEXT,
    order_state TEXT,
    order_status TEXT,
    order_zipcode TEXT,
    product_card_id TEXT,
    product_category_id TEXT,
    product_description TEXT,
    product_image TEXT,
    product_name TEXT,
    product_price TEXT,
    product_status TEXT,
    shipping_date TEXT,
    shipping_mode TEXT
);

-- Ma być 53 kolumny
SELECT COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'logistics' AND table_name = 'raw';

-- Import robię w SQL Shell (psql), nie w DBeaver:
-- \copy logistics.raw FROM 'C:/Users/Laptop/Desktop/Dane_Kaggle/archive/DataCoSupplyChainDataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'LATIN1')
-- Ma wyjść: COPY 180519
-- Importer DBeaver dopasowuje po nazwach kolumn i przy niezgodności zakłada
-- nowe kolumny, a moje zostawia puste. \copy ładuje po pozycji.

-- Kontrola po imporcie: wszystkie cztery mają być 180519
SELECT COUNT(*), COUNT(delivery_status), COUNT(order_id), COUNT(shipping_mode)
FROM raw;
-- OK, wyszło 180519 x4

-- Kontrola kodowania
SELECT DISTINCT order_state
FROM raw
WHERE order_state ILIKE '%ajast%';
-- OK: Rajastán, czyli LATIN1 jest dobre.
-- "Rajast n" z Notatnika/WPS to tylko problem wyświetlania, nie wada pliku.


-- =====================================================
-- 3. AUDYT
-- =====================================================

-- ---------- Zadanie 1: braki (NULL) ----------
-- Puste pola po \copy to NULL, a nie '' (dlatego "= ''" dawało same 0).
SELECT
    SUM(CASE WHEN order_zipcode       IS NULL THEN 1 ELSE 0 END) AS puste_order_zipcode,
    SUM(CASE WHEN product_description IS NULL THEN 1 ELSE 0 END) AS puste_opisy_produktow,
    SUM(CASE WHEN order_region        IS NULL THEN 1 ELSE 0 END) AS puste_regiony_zamowien,
    SUM(CASE WHEN customer_state      IS NULL THEN 1 ELSE 0 END) AS puste_regiony_klientow,
    SUM(CASE WHEN category_name       IS NULL THEN 1 ELSE 0 END) AS puste_nazwy_kategorii
FROM raw;
-- Wynik: 155679 / 180519 / 0 / 0 / 0
-- product_description jest pusta w 100%, wyrzucam. order_zipcode pusta w 86%.


-- ---------- Zadanie 2: spacje na brzegach ----------
SELECT COUNT(*)
FROM raw
WHERE product_name <> TRIM(product_name);
-- Wynik: 1774

SELECT product_name,
       LENGTH(product_name) - LENGTH(TRIM(product_name)) AS ile_spacji,
       COUNT(*) AS wiersze
FROM raw
WHERE product_name <> TRIM(product_name)
GROUP BY product_name
ORDER BY wiersze DESC;
-- Wynik: Toys 529, DVDs 483, Sports Books 405, Smart watch 357 (po 1 spacji).
-- To na końcu (TRIM TRAILING też daje 1774).
-- Żadna z nich nie ma czystej wersji, dlatego wcześniej wyszło 118 = 118.

-- Reszta kolumn tekstowych naraz
SELECT
    COUNT(*) FILTER (WHERE shipping_mode   <> TRIM(shipping_mode))   AS shipping_mode,
    COUNT(*) FILTER (WHERE delivery_status <> TRIM(delivery_status)) AS delivery_status,
    COUNT(*) FILTER (WHERE order_status    <> TRIM(order_status))    AS order_status,
    COUNT(*) FILTER (WHERE market          <> TRIM(market))          AS market,
    COUNT(*) FILTER (WHERE category_name   <> TRIM(category_name))   AS category_name,
    COUNT(*) FILTER (WHERE customer_city   <> TRIM(customer_city))   AS customer_city,
    COUNT(*) FILTER (WHERE order_city      <> TRIM(order_city))      AS order_city,
    COUNT(*) FILTER (WHERE customer_street <> TRIM(customer_street)) AS customer_street,
    COUNT(*) FILTER (WHERE customer_lname  <> TRIM(customer_lname))  AS customer_lname
FROM raw;
-- Wynik: 0 / 0 / 0 / 0 / 1475 / 0 / 0 / 1829 / 0
-- Osobno: order_country 0, customer_fname 0.

SELECT category_name, COUNT(*)
FROM raw
WHERE category_name <> TRIM(category_name)
GROUP BY category_name;
-- Wynik: Baby 207, Books 405, Cameras 592, CDs 271 (razem 1475)

SELECT COUNT(*) FROM raw WHERE product_image <> TRIM(product_image);
-- Wynik: 886 (to adres URL, a nie 0/1)

-- Podsumowanie: product_name 1774, product_image 886, category_name 1475,
-- customer_street 1829.
-- Decyzja: w clean daję TRIM na wszystkich kolumnach tekstowych.


-- ---------- Zadanie 3: ziarno danych ----------
WITH calc AS (
    SELECT
        COUNT(order_id)               AS ilosc_wierszy_order_id,
        COUNT(order_item_id)          AS ilosc_wierszy_item_id,
        COUNT(DISTINCT order_id)      AS unikalne_zamowienia,
        COUNT(DISTINCT order_item_id) AS unikalne_pozycje
    FROM raw
)
SELECT
    ilosc_wierszy_order_id - unikalne_zamowienia AS nadmiarowe_wiersze_order_id,
    ilosc_wierszy_item_id  - unikalne_pozycje    AS duplikaty_order_item_id
FROM calc;
-- Wynik: 114767 / 0
-- order_item_id jest unikalny, order_id się powtarza.
-- Czyli 1 wiersz = 1 pozycja zamówienia, a zamówień jest 65 752.
-- Zamówienia liczę przez COUNT(DISTINCT order_id), nie COUNT(*).

-- Czy data wysyłki różni się w obrębie jednego zamówienia?
SELECT order_id, COUNT(DISTINCT shipping_date) AS liczba_dat_wysylki
FROM raw
WHERE order_id IS NOT NULL
GROUP BY order_id
HAVING COUNT(DISTINCT shipping_date) > 1;
-- Wynik: 0 wierszy, czyli data wysyłki jest stała w zamówieniu.
-- (Test na product_name nie zrobiony, więc to zero bierzę z ostrożnością.)


-- ---------- Zadanie 4: wartości kategorialne ----------
SELECT shipping_mode, COUNT(*) AS wiersze FROM raw GROUP BY shipping_mode ORDER BY wiersze DESC;
SELECT delivery_status, COUNT(*) AS wiersze FROM raw GROUP BY delivery_status ORDER BY wiersze DESC;
SELECT order_status, COUNT(*) AS wiersze FROM raw GROUP BY order_status ORDER BY wiersze DESC;
SELECT market, COUNT(*) AS wiersze FROM raw GROUP BY market ORDER BY wiersze DESC;
-- Sumy = 180519, brak NULL-i, brak wariantów zapisu i spacji.
-- shipping_mode: Standard 107752, Second 35216, First 27814, Same Day 9737
-- delivery_status: Late 98977, Advance 41592, On time 32196, Canceled 7754
-- order_status: COMPLETE 59491, PENDING_PAYMENT 39832, PROCESSING 21902,
--   PENDING 20227, CLOSED 19616, ON_HOLD 9804, SUSPECTED_FRAUD 4062,
--   CANCELED 3692, PAYMENT_REVIEW 1893
-- market: LATAM 51594, Europe 50252, Pacific Asia 41260, USCA 25799, Africa 11614
-- PENDING i PROCESSING to różne etapy, nie łączę (definicji statusów nie mam).

SELECT order_status, delivery_status, COUNT(*) AS wiersze
FROM raw
GROUP BY order_status, delivery_status
ORDER BY order_status, wiersze DESC;
-- Wynik: "Shipping canceled" jest tylko przy CANCELED (3692) i SUSPECTED_FRAUD (4062),
-- razem 7754. Reszta statusów ma tylko Late / Advance / On time,
-- nawet PENDING_PAYMENT czy ON_HOLD (zamówienie niedostarczone, a ma status dostawy).


-- ---------- Zadanie 5: spójność logiczna ----------
SELECT delivery_status,
       COUNT(*) AS wszystkie_zamowienia,
       COUNT(*) FILTER (WHERE CAST(days_for_shipping_real AS INTEGER)
                              > CAST(days_for_shipment_scheduled AS INTEGER)) AS ile_spelnia_warunek
FROM raw
GROUP BY delivery_status;
-- Wynik: Late 98977 | 98977, Advance 41592 | 0, On time 32196 | 0, Canceled 7754 | 4423

SELECT delivery_status,
       CAST(days_for_shipping_real AS INTEGER)
         - CAST(days_for_shipment_scheduled AS INTEGER) AS roznica_dni,
       late_delivery_risk,
       COUNT(*) AS wiersze
FROM raw
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
-- Wynik:
--   Advance: różnica -2 (20873) i -1 (20719), ryzyko 0
--   On time: różnica 0 (32196), ryzyko 0
--   Late: różnica 1 (57957), 2 (27551), 3 (6772), 4 (6697), ryzyko 1
--   Canceled: różnica od -2 do 4, ryzyko zawsze 0
-- Wnioski:
--   delivery_status jest wyliczony z real vs scheduled, bez wyjątków.
--   late_delivery_risk to kopia statusu Late (dla anulowanych 0), nie niezależne ryzyko.
--   Anulowane mają wypełnione dni (4423 "spóźnione"), ale to nie ma sensu biznesowego.

SELECT COUNT(*) FROM raw WHERE days_for_shipping_real LIKE '%.%';
-- Wynik: 0, czyli dni mogą być INTEGER.


-- ---------- Zadanie 6: daty ----------
-- Format w pliku: M/D/YYYY HH:MI (np. 1/31/2018 22:56).
-- CAST na timestamp wywalił błąd 22008, bo zgaduje format. Używam TO_TIMESTAMP.
WITH zmiana AS (
    SELECT
        TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI')::TIMESTAMP AS data_zamowienia,
        TO_TIMESTAMP(shipping_date, 'MM/DD/YYYY HH24:MI')::TIMESTAMP AS data_wysylki
    FROM raw
)
SELECT COUNT(*) AS wysylka_przed_zamowieniem
FROM zmiana
WHERE data_zamowienia > data_wysylki;
-- Wynik: 0, i zapytanie przeszło bez błędu, więc format jest dobry we wszystkich wierszach.

-- MIN/MAX (na tym samym CTE):
-- Zamówienia: 2015-01-01 do 2018-01-31
-- Wysyłki:    2015-01-03 do 2018-02-06
-- Ponad 3 lata danych, więc MoM i YoY są możliwe.

-- Czy różnica dat zgadza się z days_for_shipping_real?
with daty as(
SELECT
cast(days_for_shipping_real as int) as trwanie_wysylki,
to_timestamp(order_date,  'mm-dd-yyyy HH24:MI')::DATE as data_zamowienia,
to_timestamp(shipping_date, 'mm-dd-yyyy HH24:MI')::DATE as data_wyslania
from raw),
liczba_dni as (
select
trwanie_wysylki,
data_wyslania - data_zamowienia as trwanie_wysylkiv2
from daty
where trwanie_wysylki = (data_wyslania - data_zamowienia) ),
bledy as(
select
trwanie_wysylki,
data_wyslania - data_zamowienia as trwanie_wysylkiv2
from daty
where trwanie_wysylki <> (data_wyslania - data_zamowienia))
select
COUNT(*) as prawidlowy_shipping_real,
(SELECT COUNT(*) from bledy) as bledny_shipping_real
from liczba_dni;
-- Wynik: 180519 zgodnych, 0 niezgodnych (suma się domyka, więc brak NULL-i).
-- days_for_shipping_real to po prostu różnica dat, nie osobny pomiar.


-- =====================================================
-- 4. DECYZJE DO CLEAN
-- =====================================================
-- Ziarno: 1 wiersz = 1 pozycja zamówienia, klucz order_item_id.
-- TRIM na wszystkich kolumnach tekstowych.
-- Wyrzucam product_description (100% pusta),order_zipcode (86% pusta),
-- customer_email i customer_password (zamaskowane)
-- Typy: ID, dni, ilości -> INTEGER; kwoty, marże, rabaty -> NUMERIC;
--   daty -> TO_TIMESTAMP(x, 'MM/DD/YYYY HH24:MI')::TIMESTAMP; reszta TEXT.
-- Flaga: is_cancelled = order_status IN ('CANCELED', 'SUSPECTED_FRAUD').
-- Opóźnienie = days_for_shipping_real - days_for_shipment_scheduled,
--   liczone tylko dla zamówień nieanulowanych.
-- late_delivery_risk zostaje tylko jako kontrola.
-- przy analizie zysku tez wykluczamy 'is_cancelled'
-- usunieta kolumna benefit_per_order, 
-- wyniki w niej zawarte sa takie same jak w order_profit_per_order
-- nazwa kolumny zostala zmieniona na profit_per_item co mocniej ukazuje co naprawde
--  jest w kolumnie

-- =====================================================
-- 4A. LISTA PROBLEMOW Z DANYMI (problem | co zrobilem)
-- =====================================================
-- 1) zbedne kolumny: product_description 100% puste, order_zipcode ok. 86% puste,
--    haslo i mail zamaskowane | usunalem
-- 2) spacje na koncu tekstu: product_name 1774, category_name 1475,
--    customer_street 1829, product_image 886 | TRIM na calym tekscie
-- 3) daty jako tekst (M/D/YYYY) | TO_TIMESTAMP z formatem
-- 4) 5 zdublowanych kolumn i product_status (same 0) | usunalem, zostala jedna z pary
-- 5) 7754 anulowane pozycje maja policzone dni dostawy | flaga is_cancelled, wykluczam z analiz
-- 6) 391 klientow ma tylko anulowane pozycje | wypadaja z analiz razem z anulowanymi
-- 7) delivery_status i late_delivery_risk wyliczone z planu, plan staly w trybie wysylki |
--    nie porownuje trybow po odsetku spoznien
-- 8) customer_country tylko 2 wartosci, order_country 164 po hiszpansku |
--    zostawilem, uzywam market i order_region
-- 9) Electronics ma 2 category_id (dwa dzialy) | grupuje po nazwie, wiem o tym
-- 10) market ma dane w blokach miesiecy (61 par z 185) | MoM tylko w srodku bloku, YoY niemozliwe
-- 11) dane wygladaja na syntetyczne (stale plany, rowne grupy rabatu, od 2017-10 ok. 1 pozycja
--     na zamowienie zamiast 3) | nie wyciagam wnioskow o prawdziwym biznesie
-- 12) 18,7% pozycji ma strate (32295), nie wiem jak liczony jest profit_per_item | zostawiam bez zmian



---- clean: gotowa, czas 3,5 s
-- 180519 wierszy, 65752 zamówień, 7754 anulowanych, 45 kolumn
-- zakresy dat: zamówienia 2015-01-01 do 2018-01-31, wysyłki 2015-01-03 do 2018-02-06
-- product_status: 1 wartość (0), usunięta
-- spacje po TRIM: 0 w product_name, category_name, customer_street, product_image
-- typy sprawdzone w information_schema
 --=======================================================================
-- 05. TWORZENIE TABELI CLEAN--
--=======================================================================
 
DROP TABLE IF EXISTS logistics.clean;
CREATE TABLE logistics.clean AS
select
-- grupa 1: identyfikatory zamówienia i daty
CAST(trim(order_id) as INT) as order_id,
CAST(trim(order_item_id) as INT) as order_item_id,
TO_TIMESTAMP(order_date, 'mm/dd/yyyy hh24:mi') :: TIMESTAMP as order_date,
TO_TIMESTAMP(shipping_date, 'mm/dd/yyyy hh24:mi') :: TIMESTAMP as shipping_date,
-- grupa 2: dostawa i status
CAST(trim(days_for_shipping_real) as INT) as days_for_shipping_real,
CAST(trim(days_for_shipment_scheduled) as int) as days_for_shipment_scheduled,
(CAST(trim(days_for_shipping_real) as INT) -CAST(trim(days_for_shipment_scheduled) as int)) as delay_days,
CAST(trim(delivery_status) as text) as delivery_status,
cast(trim(order_status) as  text) as order_status,
order_status in ('CANCELED', 'SUSPECTED_FRAUD') AS is_cancelled,
CAST(trim(late_delivery_risk) as int) as late_delivery_risk,
-- grupa 3: ilości, kwoty, wspolrzedne
CAST(trim(order_item_quantity) as Int) as order_item_quantity,
CAST(trim(sales) as numeric(12,2)) as sales,
cast(trim(order_item_total) as numeric(12,2)) as order_item_total,
CAST(trim(order_profit_per_order) as numeric(12,2)) as profit_per_item,
cast(trim(order_item_discount) as numeric(12,2)) as order_item_discount,
cast(trim(order_item_product_price) as numeric(12,2)) as order_item_product_price,
cast(trim(product_price) as numeric(12,2)) as product_price,
CAST(trim(order_item_discount_rate) as numeric(8,4)) as order_item_discount_rate,
cast(trim(order_item_profit_ratio) as numeric(8,4)) as order_item_profit_ratio,
cast(trim(latitude) as numeric(10,6)) as latitude,
cast(trim(longitude) as numeric(10,6)) as longitude,
-- grupa 4: tekst z TRIM
cast(trim(type) as text) as type,
cast(trim(category_name) as text) as category_name,
cast(trim(customer_city) as text) as customer_city,
cast(trim(customer_country) as text) as customer_country,
cast(trim(customer_fname) as text) as customer_fname,
cast(trim(customer_lname) as text) as customer_lname,
cast(trim(customer_segment) as text) as customer_segment,
cast(trim(customer_state) as text) as customer_state,
cast(trim(customer_street) as text) as customer_street,
cast(trim(customer_zipcode) as text) as customer_zipcode,
cast(trim(department_name) as text) as department_name,
cast(trim(market) as text) as market,
cast(trim(order_city) as text) as order_city,
cast(trim(order_country) as text) as order_country,
cast(trim(order_region) as text) as order_region,
cast(trim(order_state) as text) as order_state,
cast(trim(product_image) as text) as product_image,
cast(trim(product_name) as text) as product_name,
cast(trim(shipping_mode) as text) as shipping_mode,
-- grupa 5: identyfikatory jako INT
cast(trim(category_id) as int) as category_id,
cast(trim(customer_id) as int) as customer_id,
cast(trim(department_id) as int) as department_id,
cast(trim(product_card_id) as int) as product_card_id
from raw;

ALTER TABLE logistics.clean ADD PRIMARY KEY (order_item_id);


-- =====================================================
-- 6. KONTROLE PO UTWORZENIU CLEAN
-- =====================================================
-- COUNT(*) 180519, COUNT(DISTINCT order_id) 65752, is_cancelled true 7754
-- spacje w product_name, category_name, customer_street, product_image: 0
-- liczba kolumn: 45

select
min(order_date) as pierwsze_zamowienie,
max(order_date) as ostatnie_zamowienie,
min(shipping_date) as pierwsza_wysylka,
max(shipping_date) as ostatnia_wysylka
from clean;
-- wynik: 2015-01-01 00:00 | 2018-01-31 23:38 | 2015-01-03 00:00 | 2018-02-06 22:14


-- porównanie raw i clean przez EXCEPT (nazwy kolumn)
-- raw minus clean: 8 nazw (7 usuniętych + order_profit_per_order przemianowana)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'logistics' AND table_name = 'raw'
EXCEPT
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'logistics' AND table_name = 'clean';
-- clean minus raw: 3 nazwy (delay_days, profit_per_item, is_cancelled)
-- 8 - 3 = 5 = 53 - 48 w momencie sprawdzania; dziś clean ma 45 kolumn


-- =====================================================
-- 7. TESTY DUPLIKATÓW KOLUMN (wyniki w komentarzach sekcji 5)
-- =====================================================
/*select
COUNT(*) filter(where sales_per_customer <> order_item_total) as rozne,
count(*) filter(where sales_per_customer = order_item_total) as takie_same,
count(*) filter(where sales_per_customer is null) as puste_sales,
count(*) filter(where order_item_total is null) as puste_order
from clean;
-- wynik: 0 | 180519 | 0 | 0   (wykonane przed usunięciem sales_per_customer)

select
count(*) FILTER(where customer_id = order_customer_id) as takie_same,
count(*) filter(where customer_id <> order_customer_id) as rozne,
count(*) filter(where customer_id is null and order_customer_id is null) oba_puste,
count(*) filter(where customer_id is null) customer_pusty,
count(*) filter (where order_customer_id is null) order_pusty
from clean;
-- wynik: 180519 | 0 | 0 | 0 | 0

select
count(distinct category_id) as category,
count(distinct product_category_id) as product_category,
count(*) filter(where category_id = product_category_id) as takie_same,
count(*) filter(where category_id <> product_category_id) as rozne,
count(*) filter(where category_id is null and product_category_Id is null) oba_null,
count(*) filter (where category_Id is null) category_puste,
count(*) filter(where product_category_id is null) as product_category_pusty
from clean;
-- wynik: 51 | 51 | 180519 | 0 | 0 | 0 | 0

select
count(distinct order_item_cardprod_id) as item_cardprod,
count(distinct product_card_id) as product_card,
count(*) filter(where order_item_cardprod_id = product_card_id) as takie_same,
count(*) filter(where order_item_cardprod_id <> product_card_id) as rozne
from clean;*/
-- wynik: 118 | 118 | 180519 | 0   (bez sprawdzenia NULL-i, domknięte sumą)
-- uwaga: te cztery testy działają tylko na wersji clean, w której kolumny jeszcze były;
-- po usunięciu kolumn z SELECT zapytania zwrócą błąd (kolumny nie istnieją)
--////////TESTY PO IMPORCIE NA DRUGIEGO LAPTOPA///////////////////////////
--            --test1

--SELECT
--COUNT(*) AS wiersze, --180,519
--COUNT(DISTINCT order_id) AS zamowienia, -- 65,752
--COUNT(*) FILTER (WHERE is_cancelled) AS anulowane, --7754
--SUM(profit_per_item) FILTER (WHERE NOT is_cancelled) AS zysk_nieanulowane --3,806,420,63
--FROM logistics.clean;
              -- test2
                
--SELECT COUNT(*) FROM information_schema.columns
--WHERE table_schema = 'logistics' AND table_name = 'clean';  --oczekiwane 45
             -- test3

--SELECT constraint_name FROM information_schema.table_constraints
--WHERE table_schema = 'logistics' AND table_name = 'clean' AND constraint_type = 'PRIMARY KEY';  --1 wiersz


--SELECT MIN(order_date), MAX(order_date), MIN(shipping_date), MAX(shipping_date),
--COUNT(*) FILTER (WHERE product_name <> TRIM(product_name)) AS spacje_product_name
--FROM logistics.clean;
 ---Oczekiwane: 2015-01-01 00:00 | 2018-01-31 23:38 | 2015-01-03 00:00 | 2018-02-06 22:14 | 0.---



-- =====================================================
-- PROJEKT DATACO 04_questions
-- Tabela: clean (45 kolumn, 180519 wierszy)
-- Zawsze wykluczam anulowane (WHERE NOT is_cancelled): 172765 wierszy
-- =====================================================

-- =====================================================
-- PYTANIE 1: który tryb wysyłki ma największy odsetek spóźnień
-- pytanie: który tryb wysyłki ma największy odsetek spóźnień (bez anulowanych)
-- wynik: First Class 100% (26513), Second 79,83%, Same Day 47,93%, Standard 39,77%
-- test: spóźnione 98977 = Late delivery z audytu; wszystkie 172765
-- scheduled stałe w trybie: SD 0, FC 1, SC 2, Std 4
-- FC: real zawsze 2 -> reguła w danych, odsetek zależy od ustawienia planu

-- krok 1: średnie opóźnienie na tryb
-- ziarno: 1 wiersz = tryb wysyłki
select
shipping_mode as tryb_wysylki,
ROUND(AVG(delay_days),2) as srednie_opoznienie
from clean
where not is_cancelled
group by shipping_mode;
-- wynik: First Class 1,00 | Same Day 0,48 | Second Class 1,99 | Standard Class -0,01
-- średnia dni to nie odsetek: wysyłka o 2 dni wcześniej kasuje w średniej spóźnioną o 2 dni

-- krok 2: odsetek spóźnień (pozycje zamówień, nie zamówienia)
-- pierwsza wersja bez WHERE NOT is_cancelled dawała 103400 spóźnionych
-- (98977 + 4423 anulowanych) -> błąd, anulowane muszą być wykluczone
with tryby_wysylki as(
select
distinct shipping_mode,
count(*) as lacznie_wysylek,
count(*) filter(where delay_days >0) spoznione
from clean
where not is_cancelled
group by distinct shipping_mode)
select
shipping_mode,
lacznie_wysylek,
spoznione,
ROUND(100.0*spoznione/lacznie_wysylek , 2) as odsetek_spoznionych_pct
from tryby_wysylki;
-- wynik: First Class 26513 | 26513 | 100,00
--        Same Day 9293 | 4454 | 47,93
--        Second Class 33806 | 26987 | 79,83
--        Standard Class 103153 | 41023 | 39,77
-- test: spóźnione 26513 + 4454 + 26987 + 41023 = 98977 (zgodne z audytem)
-- test: wszystkie 172765 = nieanulowane

-- krok 3: średnie real vs scheduled na tryb
select
distinct shipping_mode,
ROUND(AVG(days_for_shipping_real), 2) as sredni_czas_dostawy,
AVG(days_for_shipment_scheduled) as planowany_czas_dostawy
from clean
where not is_cancelled
group by shipping_mode;
-- wynik: First Class 2,00 vs 1 | Same Day 0,48 vs 0 | Second Class 3,99 vs 2 | Standard 3,99 vs 4

-- krok 4: rozkład real i scheduled w trybie (dowód, że scheduled jest stałe)
select
count(*),
shipping_mode,
days_for_shipping_real,
days_for_shipment_scheduled
from clean
where not is_cancelled
group by
distinct shipping_mode,
days_for_shipping_real,
days_for_shipment_scheduled
order by shipping_mode,
days_for_shipment_scheduled;
-- wynik (pozycje | tryb | real | scheduled):
--   26513 First Class 2 | 1
--   4839 Same Day 0 | 0, 4454 Same Day 1 | 0
--   Second Class (plan 2): real 2: 6819, 3: 6759, 4: 6759, 5: 6772, 6: 6697
--   Standard Class (plan 4): real 2: 20873, 3: 20719, 4: 20538, 5: 20231, 6: 20792
-- test: suma 172765 (żaden wiersz nie wypadł)

-- WNIOSEK: scheduled jest stałe w każdym trybie (SD 0, FC 1, SC 2, Std 4),
-- a First Class ma real = 2 w 26513 z 26513 pozycji, więc zawsze +1 dzień.
-- Odsetek spóźnień mierzy głównie ustawienie planu, a nie jakość dostaw.
-- Rozkład real jest niemal równomierny (np. Standard 5 wartości po ok. 20000),
-- co sugeruje dane syntetyczne.
-- W danych każdy tryb wysyłki ma stały planowany czas
-- (0, 1, 2 i 4 dni), więc First Class jest spóźniony w 100% pozycji (26513),
-- a Standard w 39,77%. Różnica wynika z ustawienia planu, a nie koniecznie
-- z jakości dostaw.



-- PYTANIE 2: --pytanie drugie--
--Ktory market ma najwiekszy zysk bez anulowanych pozycji----
--zysk per market miesiac do miesiaca, ze zmiana---
--2A
select
market,
COUNT(distinct order_id) as orders,
COUNT(order_id) as positions,
SUM(profit_per_item) as total_profit,
ROUND(COUNT(order_id)::numeric / COUNT(DISTINCT order_id), 2) AS position_per_order,
ROUND(SUM(profit_per_item)/count(distinct order_id),2) as profit_per_order,
ROUND(sum(profit_per_item)/count(order_id), 2) as profit_per_position
from clean
where not is_cancelled
group by market
order by total_profit desc;
-- wyniki: Europe 1131937,91 | LATAM 1069050,79 |
-- Pacific Asia 826167,16 | USCA 539223,29 | Africa 240041,48
-- wnioski: najwiekszy zysk generuje europa, dodatkowo ciekawa sytuacja miedzy azja a Latam
-- bardzo podobna ilosc zamowien przy duzo mniejszym zysku azji
-- Pacific Asia vs LATAM: zysk/zamówienie 49,02 vs 65,13 (różnica 16,11)
-- roznica wynika glownie z mniejszej sredniej ilosci pozycji w koszyku
-- koszyk 2,35 vs 3,00 pozycji -> ok. 13,6 zł; zysk/pozycję 20,87 vs 21,68 -> ok. 2,4 zł

-- ---------- 2B: zysk miesiąc do miesiąca per market ----------
-- 2B krok 1: czy dane są kompletne (czy w każdym miesiącu była sprzedaż)
-- uwaga: to zapytanie jest bez WHERE NOT is_cancelled, to tylko test kompletności
select
market,
date_trunc('month' , order_date):: date as miesiac,
SUM(profit_per_item) as miesieczny_zysk
from clean
group by
market,
date_trunc('month', order_date)
order by 
market,
date_trunc('month', order_date);
-- wynik: 61 wierszy zamiast przewidywanych 185 (5 marketów x 37 miesięcy)
-- każdy market ma bloki miesięcy z przerwami, żaden nie ma sprzedaży w każdym miesiącu

-- 2B krok 2: zmiana miesiąc do miesiąca (3 etapy: zysk miesięczny, LAG, procent)
-- ziarno: 1 wiersz = market i miesiąc
with miesieczny as(select
market,
date_trunc('month' , order_date):: date as miesiac,
SUM(profit_per_item) as miesieczny_zysk
from clean
where not is_cancelled
group by
market,
date_trunc('month', order_date)
order by 
market,
date_trunc('month', order_date)),
poprzedni as(
select
market,
miesiac,
miesieczny_zysk,
LAG(miesiac) over(partition by market order by miesiac) as poprzedni_miesiac,
lag(miesieczny_zysk) over(partition by market order by miesiac) as poprzedni_zysk
from miesieczny)
select
market,
miesiac,
miesieczny_zysk,
poprzedni_miesiac,
poprzedni_zysk,
case
	when miesiac - interval '1 month' = poprzedni_miesiac
	then ROUND((miesieczny_zysk - poprzedni_zysk)*100/ NULLIF(poprzedni_zysk, 0),2)
end as zmiana_pct
from poprzedni
order by market,
miesiac;
-- test: 61 wierszy, suma zysków 3806420,63
--   poprzedni_miesiac NULL: 5 (po jednym na market)
--   zmiana_pct NULL: 10 (5 początków bloków + 5 przerw: Europe 2, LATAM 1, Pacific Asia 2)
--   zmiana_pct policzona: 51
-- LAG bierze poprzedni wiersz, nie poprzedni miesiąc, dlatego warunek na datach w CASE
-- skrajne procenty: od -98,09 (USCA 2016-09) do +3571,26 (Europe 2015-06)
-- w środku bloków zmiany są małe (np. Europe 2015-07 do 2015-09: +5,48, +2,02, -3,54)

-- 2B krok 3: test, czy skrajne wartości wynikają z niepełnych miesięcy
-- ziarno: 1 wiersz = market i miesiąc
with test as (select
market,
date_trunc('month', order_date):: date as miesiac,
COUNT(distinct order_date ::date) as ilosc_dni,
SUM(profit_per_item) as zysk_miesiac,
MIN(order_date)::date as pierwszy_dzien,
MAX(order_date):: date as ostatni_dzien,
ROUND(SUM(profit_per_item)/COUNT(distinct order_date ::date), 2) as zysk_dzienny
from clean
where not is_cancelled
group by
market,
date_trunc('month' ,order_date)
order by
market,
miesiac)
select
sum(zysk_miesiac)
from test;
-- test: suma 3806420,63 (zgodna z sumą marketów z 2A)
-- (ten sam SELECT bez końcowego sum() pokazuje wiersze: market, miesiąc, dni, zysk,
--  pierwszy i ostatni dzień, zysk dzienny)
-- wyniki, które mają znaczenie:
--   Europe 2015-05: 1 dzień (2015-05-31), zysk dzienny 2957,45 vs 3671,57 w czerwcu
--     -> artefakt niepełnego miesiąca, +3571% to porównanie 1 dnia z 30
--   Europe 2016-08: 7 dni (25-31.08), zysk dzienny 170,61 vs 663,25 we wrześniu
--     -> dni tego nie tłumaczą, zysk dzienny jest ok. 4 razy niższy
--   USCA 2016-08: 29 dni, zysk dzienny 3396,88; USCA 2016-09: 18 dni, 96,51
--     -> zmiana poziomu zysku na dzień (ok. 35 razy niżej), nie niepełny miesiąc
--   część skrajnych zmian tłumaczą niepełne miesiące, ale nie wszystkie
-- obserwacja (do sprawdzenia, nie fakt): markety działają jak "sztafeta".
--   od 2016-08-25 do 2017-01-18 działają cztery markety naraz (każdy z niskim zyskiem na dzień)
-- wniosek: MoM jest wiarygodny tylko w środku bloków, YoY niemożliwe
--   (żaden market nie ma tego samego miesiąca w dwóch latach)
--   MoM da się policzyć w 51
--   przypadkach, ale dane mają przerwy (1-3 bloki miesięcy na market) i skrajne
--   wartości na brzegach bloków (od -98% do +3571%). Część wynika z niepełnych
--   miesięcy, część ze zmiany poziomu zysku na dzien


-- ---------- 2C: łączny zysk na dzień (wszystkie markety razem) ----------
-- ziarno: 1 wiersz = miesiąc
select
date_trunc('month' , order_date):: date as miesiac,
COUNT(distinct order_date:: date) as ilosc_dni,
SUM(profit_per_item) as zysk_miesiac,
SUM(profit_per_item)/COUNT(distinct order_date :: date) as zysk_dzienny
from clean
where not is_cancelled
group by date_trunc('month' , order_date);
-- wynik: 37 miesięcy, suma zysków 3806420,63 (sprawdzona ręcznie)
-- zysk dzienny łącznie: od ok. 2860 (2016-02) do ok. 4090 (2017-08) w okresie
-- ostatnie trzy miesiące są niżej: 2017-11: 2236, 2017-12: 2097, 2018-01: 1044
--   w tych miesiącach działa tylko Pacific Asia
--    Przyczyny nie znamy
--   (hipotezy do sprawdzenia: niepełny koniec danych, mniej zamówień, niższy zysk na pozycję)
-- hipoteza do sprawdzenia: łączny zysk na dzień jest mniej więcej stały,
--   a markety tylko dzielą go między siebie w różnych okresach
--   (Pacific Asia sam w 2015-11: ok. 3481 na dzień, w oknie z czterema marketami: ok. 1210)
-- wniosek na teraz: ranking z 2A (Europe największy zysk) w dużej mierze odzwierciedla
--   to, jak długo i w jakich okresach market był aktywny. Uczciwsze porównanie
--   to zysk na dzień aktywności i udział w łącznym zysku.

-- 2C test: ile marketów miało sprzedaż w 2016-10 i 2017-03
with test as (select
market,
date_trunc('month', order_date):: date as miesiac,
COUNT(distinct order_date ::date) as ilosc_dni,
SUM(profit_per_item) as zysk_miesiac,
MIN(order_date)::date as pierwszy_dzien,
MAX(order_date):: date as ostatni_dzien,
ROUND(SUM(profit_per_item)/COUNT(distinct order_date ::date), 2) as zysk_dzienny
from clean
where not is_cancelled
group by
market,
date_trunc('month' ,order_date)
order by
market,
miesiac)
select
count(distinct market) filter(where zysk_miesiac >0 and miesiac >= '2016-10-01' and miesiac < '2016-11-01') as markety_pazdziernik,
count(distinct market) filter(where zysk_miesiac >0 and miesiac >= '2017-03-01' and miesiac < '2017-04-01') as markety_marzec
from test;
-- wynik: 4 (2016-10: Africa, Europe, Pacific Asia, USCA) i 1 (2017-03: tylko LATAM)
-- zgadza się z tabelą market x miesiąc z 2B
-- wniosek: w 2016-10 działały cztery markety, w 2017-03 jeden, więc zysk na market
--   w miesiącu nie jest porównywalny między okresami


select
date_trunc('month', order_date):: date as miesiac,
COUNT(distinct market) as liczba_marketow,
COUNT(distinct order_date :: date) as ilosc_dni,
SUM(profit_per_item) as zysk_miesieczny,
ROUND(SUM(profit_per_item)/COUNT(distinct order_date:: date) , 2) as zysk_dzienny
from clean
where not is_cancelled
group by date_trunc('month' , order_date)
order by date_trunc('month' , order_date);

-- 2C wynik: 37 miesięcy, suma zysków 3806420,63
-- liczba aktywnych marketów w miesiącu: 1 (28 miesięcy), 2 (5), 4 (5), 5 (1: 2017-01)
-- łączny zysk na dzień: 1 market 2863-4086, 4-5 marketów 3193-4058 -> brak zależności
-- wniosek: markety dzielą mniej więcej stałą pulę, zysk marketu zależy od okresu aktywności
-- 2017-11 do 2018-01: 2236 | 2097 | 1044 -> wyraźnie niżej, 3 punkty, przyczyny nie znamy

                        -- szukanie przyczyny spadku--
select
date_trunc('month' , order_date) :: date as miesiac,
COUNT(distinct order_id) as ilosc_zamowien,
COUNT(distinct order_item_id) as ilosc_pozycji,
COUNT(distinct order_id) filter(where is_cancelled) as anulowane_zamowienia,
ROUND(SUM(profit_per_item)/COUNT(distinct order_id :: numeric), 2) as sredni_zysk_na_zamowienie,
ROUND(100.0*COUNT(distinct order_id) filter(where is_cancelled)/COUNT(distinct order_id), 2) as anulowane_pct
from clean
group by date_trunc('month' , order_date) :: date
order by miesiac;

---                       wnioski:----------
-- zysk w ostatnich miesiącach spada, bo od 2017-10 zamówienia mają prawie 1 pozycję
-- (wcześniej ok. 3), a zamówień jest o ok. 20% więcej; liczba pozycji spadła ponad dwukrotnie
-- anulowane zamówienia: 3,4-5,5% w każdym miesiącu, więc to nie one
-- test: suma pozycji 180519, suma zamówień 65752, anulowane zamówienia 2855
-- uwaga: to zapytanie jest bez WHERE NOT is_cancelled
-- hipoteza, niesprawdzona: zmiana w danych (syntetyczne), a nie w biznesie;
--   przez to koszyk Europe (2,71) i Pacific Asia (2,35) z 2A może być artefaktem końcówki danych



-- =====================================================
-- PYTANIE 3: czy straty sa w kilku kategoriach, czy wszedzie
-- =====================================================
-- ziarno: 1 wiersz = kategoria
-- przewidywanie: straty beda wyzsze w kilku kategoriach


select
category_name,
SUM(profit_per_item) as zysk_kategorii,
-1*SUM(profit_per_item) filter(where profit_per_item <0) as strata,
COUNT(*) as liczba_pozycji,
COUNT(*) FILTER(where profit_per_item <0) as pozycje_ze_strata,
ROUND(100.0*COUNT(*) filter(where profit_per_item <0)/COUNT(*) , 2) as pozycje_ze_strata_pct
from clean
where not is_cancelled
group by category_name
order by strata desc;

-- test: suma pozycji 172765, suma pozycji ze strata 32295
-- test sumy zysku (ma byc 3806420,63) suma sie zgadza
 with test as(select
category_name,
SUM(profit_per_item) as zysk_kategorii,
-1*SUM(profit_per_item) filter(where profit_per_item <0) as strata,
COUNT(*) as liczba_pozycji,
COUNT(*) FILTER(where profit_per_item <0) as pozycje_ze_strata,
ROUND(100.0*COUNT(*) filter(where profit_per_item <0)/COUNT(*) , 2) as pozycje_ze_strata_pct
from clean
where not is_cancelled
group by category_name
order by strata desc)
select
sum(zysk_kategorii) as kontrola
from test;

-- wnioski:
-- w prawie kazdej kategorii strate ma 15-20% pozycji, czyli podobnie wszedzie
-- najwiecej strat procentowo ma Men's Clothing (24%), najmniej Golf Bags & Carts (9,84%)
-- ale to male kategorie, wiec ten wynik moze byc przypadkiem
-- najwieksze straty maja te kategorie, ktore sprzedaja najwiecej pozycji
-- (okolo 8 najwiekszych kategorii to wiekszosc pozycji i wiekszosc strat),
-- czyli strata idzie za wolumenem, a nie za konkretna kategoria
-- zadna kategoria nie ma ujemnego zysku,
-- ogolnie strata to mniej wiecej polowa zysku z pozycji dodatnich
-- to jest cecha calego asortymentu, a nie jednej kategorii

-- okolo 19% pozycji przynosi strate i dotyczy to prawie kazdej
-- kategorii, wiec problem nie lezy w jednej kategorii. Straty to mniej wiecej polowa
-- zysku z pozostalych pozycji.

-- do sprawdzenia:
-- 1) category_id jest 51, a category_name 50, sprawdzone ponizej

select
distinct category_name,
count(distinct category_id)
from clean
group by distinct category_name
having count(distinct category_id) > 1;
-- wynik: Electronics ma 2 rozne category_id
-- czyli GROUP BY category_name polaczyl dwie grupy w jeden wiersz
-- do sprawdzenia: czy to dwie rozne kategorie czy jedna zapisana dwa razy
select
category_id,
department_name,
count(*) as liczba_pozycji,
Count(*) filter(where profit_per_item <0) as pozycje_ze_strata
from clean
where category_name = 'Electronics' and not is_cancelled
group by category_id,
department_name;
-- sprawdzone: 51 category_id, a nazw 50, bo Electronics ma dwa id
-- id 13 (dzial Footwear): 1070 pozycji, 202 ze strata, ok. 18,9%
-- id 37 (dzial Outdoors): 1954 pozycje, 346 ze strata, ok. 17,7%
-- wniosek: to dwie rozne kategorie z ta sama nazwa, obie blisko sredniej strat


-- =====================================================
-- PYTANIE 4: czy rabat ma wplyw na straty (bez anulowanych)
-- =====================================================
-- rabat to ulamek (0,25 = 25%), w zapytaniu mnoze razy 100
-- rabatow jest 18 roznych, od 0% do 25%, w kazdej grupie ok. 9600 pozycji
-- ziarno: 1 wiersz = wartosc rabatu
-- przewidywanie: zysk spada z rabatem, srednia cena podobna w kazdej grupie (sprawdzilo sie)

-- sprawdzam jaki jest najmniejszy i najwiekszy rabat i ile jest roznych wartosci
select
Min(order_item_discount_rate) as minimalny_rabat,
MAX(order_item_discount_rate) as maksymalny_rabat,
COUNT(distinct order_item_discount_rate) as ilosc_roznych_rabatow
from clean;

-- glowne zapytanie: dla kazdego rabatu licze pozycje, straty, zyski, srednie i sumy
select
distinct(order_item_discount_rate)*100 as rabat_pct,
COUNT(*) as liczba_pozycji,
ROUND(AVG(order_item_product_price), 2) as srednia_cena_pozycji,
COUNT(*) Filter(where profit_per_item <0) as pozycje_ze_strata,
COUNT(*) filter(where profit_per_item >0) as pozycje_ze_zyskiem,
COUNT(*) filter(where profit_per_item  = 0) pozycje_neutralne,
ROUND(AVG(profit_per_item), 2) as sredni_zysk_pozycji,
ROUND(AVG(profit_per_item) filter(where profit_per_item >0), 2)as sredni_zysk_pozycji_ze_zyskiem,
ROUND(-1*AVG(profit_per_item) filter(where profit_per_item <0), 2) as srednia_strata_na_pozycje_ze_strata,
ROUND(100.0*COUNT(*) Filter(where profit_per_item <0)/ COUNT(*) , 2) as pozycje_ze_strata_pct,
-1*SUM(profit_per_item) filter(where profit_per_item <0) as suma_strat,
SUM(profit_per_item) filter(where profit_per_item >0) as suma_zyskow
from clean
where not is_cancelled
group by distinct (order_item_discount_rate)
order by rabat_pct asc;

-- test: to samo zapytanie w CTE, sumuje pozycje i zysk po wszystkich grupach
with test as (select
distinct(order_item_discount_rate)*100 as rabat_pct,
COUNT(*) as liczba_pozycji,
ROUND(AVG(order_item_product_price), 2) as srednia_cena_pozycji,
COUNT(*) Filter(where profit_per_item <0) as pozycje_ze_strata,
COUNT(*) filter(where profit_per_item >0) as pozycje_ze_zyskiem,
COUNT(*) filter(where profit_per_item  = 0) pozycje_neutralne,
ROUND(AVG(profit_per_item), 2) as sredni_zysk_pozycji,
ROUND(AVG(profit_per_item) filter(where profit_per_item >0), 2)as sredni_zysk_pozycji_ze_zyskiem,
ROUND(-1*AVG(profit_per_item) filter(where profit_per_item <0), 2) as srednia_strata_na_pozycje_ze_strata,
ROUND(100.0*COUNT(*) Filter(where profit_per_item <0)/ COUNT(*) , 2) as pozycje_ze_strata_pct,
-1*SUM(profit_per_item) filter(where profit_per_item <0) as suma_strat,
SUM(profit_per_item) filter(where profit_per_item >0) as suma_zyskow
from clean
where not is_cancelled
group by distinct (order_item_discount_rate)
order by rabat_pct asc)
select
SUM(liczba_pozycji) as pozycje,
SUM(pozycje_ze_strata) + SUM(pozycje_ze_zyskiem) + SUM(pozycje_neutralne) as kontrola_pozycji,
SUM(suma_zyskow) - SUM(suma_strat) as kontrola_zysku
from test;
-- wynik testu: 172765 | 172765 | 3806420,63 (zgadza sie)
-- suma strat 3708393,18, suma zyskow dodatnich 7514813,81 (policzone), straty to ok. 49% zyskow

-- wyniki (0% -> 25%):
-- odsetek pozycji ze strata: w kazdej grupie 18-19,6%
-- sredni zysk na pozycje: 26,42 -> 19,64
-- sredni zysk z pozycji dodatnich: 60,39 -> 45,15
-- srednia strata na pozycje ze strata: 120,19 -> 93,16
-- suma strat: najwieksza przy rabatach 1-4% (ok. 229 tys.), najmniejsza przy 25% (163 tys.)
-- srednia cena pozycji: ok. 141 w kazdej grupie (140,75-142,18)
-- pozycji z zyskiem 0 jest malo (54-73 w grupie)

-- wnioski:
-- rabat nie zwieksza liczby pozycji ze strata (zawsze ok. 18-19%)
-- wiekszy rabat obniza sredni zysk, ale przez pozycje dodatnie (zarabiaja mniej),
-- a nie przez straty, bo straty z rabatem sa mniejsze
-- cena produktu jest taka sama w kazdej grupie, wiec to nie ona tlumaczy spadek
-- zysk z pozycji dodatnich spada mniej wiecej o tyle %, ile wynosi rabat, wyglada na
-- zaleznosc danych (prawdopodobnie syntetyczne)
-- rabat nie zwieksza liczby pozycji ze strata (ok. 18-19% w kazdej grupie),
-- ale obniza zysk z pozycji dodatnich z ok. 60 zl bez rabatu do ok. 45 zl przy 25%,
-- a srednia cena produktow jest taka sama (ok. 141 zl).
-- wiec nie wyciagam wnioskow o zachowaniu klientow.
-- =====================================================
-- PYTANIE 5: ktory segment klientow daje najwiekszy zysk (bez anulowanych)
-- =====================================================
-- ziarno: 1 wiersz = segment klientow
-- przewidywanie: segmenty podobne na klienta, najwiekszy zysk ma Consumer,
-- bo ma najwiecej klientow (sprawdzilo sie)

-- ile jest klientow i segmentow
select
COUNT(distinct customer_id) as liczba_klientow,
COUNT(distinct customer_segment) as liczba_segmentow
from clean;
-- wynik: 20652 klientow, 3 segmenty (cala tabela, z anulowanymi)

-- czy klient moze byc w wiecej niz jednym segmencie
select
distinct customer_id,
COUNT(distinct customer_segment) as segment_count
from clean
group by distinct customer_id
having COUNT(distinct customer_segment) >1;

-- czyli kazdy klient jest w jednym segmencie

-- glowne zapytanie: klienci, pozycje, zamowienia, zysk i srednie na segment
select
customer_segment,
Count(distinct customer_id) as liczba_klientow,
COUNT(*) as liczba_pozycji,
COUNT(distinct order_id) as liczba_zamowien,
SUM(profit_per_item) as zysk_segmentu,
ROUND(sum(profit_per_item):: numeric/count(distinct order_id) , 2) as zysk_na_zamowienie,
ROUND(SUM(profit_per_item):: numeric/COUNT(*),2) as zysk_na_pozycje,
ROUND(SUM(profit_per_item):: numeric/COUNT(distinct customer_id), 2) as zysk_na_klienta,
ROUND(Count(*)::numeric / COUNT(distinct customer_id), 2) as pozycji_na_klienta,
ROUND(count(distinct order_id):: numeric/count(distinct customer_id), 2) zamowienia_na_klienta
from clean
where not is_cancelled
group by customer_segment
order by zysk_segmentu desc;
-- wyniki: Consumer 10487 klientow, zysk 1982863,62, 189,08 na klienta
--         Corporate 6120 klientow, zysk 1157821,04, 189,19 na klienta
--         Home Office 3654 klientow, zysk 665735,97, 182,19 na klienta
-- test: pozycje 172765, zysk 3806420,63, zamowienia 62897 (wszystko sie zgadza)
-- zamowienia razem 62897 tak jak po marketach, czyli zamowienie jest w jednym segmencie

-- wnioski:
-- zysk na klienta (182-189), na zamowienie (59-61) i na pozycje (21,6-22,2) jest podobny
-- w kazdym segmencie, pozycji na klienta (8,4-8,6) i zamowien na klienta (ok. 3,1) tez
-- zysk segmentu zalezy od liczby klientow (Consumer ma ok. 52% klientow i ok. 52% zysku)
-- dane wygladaja na syntetyczne, wiec nie wyciagam wnioskow o zachowaniu klientow
-- Consumer daje ok. 52% zysku, bo ma ok. 52% klientow, a zysk na klienta
-- jest podobny w kazdym segmencie (ok. 182-189 zl)
-- do sprawdzenia: 1) klientow po segmentach razem 20261, a w calej tabeli 20652 roznica 391
-- sprawdzone: 391 klientow ma tylko anulowane pozycje (20652 - 20261)

-- sprawdzam ilu klientow ma tylko anulowane pozycje (roznica 20652 vs 20261)
select
COUNT(distinct customer_id) as wszyscy_klienci,
COUNT(distinct customer_id) filter(where not is_cancelled) as klienci_z_nieanulowana_pozycja,
COUNT(distinct customer_id) - COUNT(distinct customer_id) filter(where not is_cancelled) as roznica
from clean;
-- wynik: 20652 | 20261 | 391
-- drugi test (GROUP BY customer_id + HAVING bez nieanulowanych pozycji) tez dal 391
-- czyli 391 klientow (ok. 2%) ma tylko anulowane pozycje, stad roznica w liczbie klientow

-- =====================================================
-- WNIOSKI KONCOWE (DataCo, bez anulowanych)
-- =====================================================
-- 1) tryby wysylki: plan dostawy jest staly w kazdym trybie (0, 1, 2 i 4 dni),
--    wiec odsetek spoznien (First Class 100%, Standard 40%) pokazuje ustawienie planu,
--    a nie jakosc dostaw
-- 2) straty: ok. 19% pozycji ma strate w prawie kazdej kategorii, razem ok. 3,7 mln zl,
--    czyli ok. polowy zysku z pozostalych pozycji. To cecha calego asortymentu, a nie jednej kategorii
-- 3) rabat nie zwieksza strat (ok. 18-19% pozycji ze strata w kazdej grupie), ale obniza
--    zysk z pozycji dodatnich z ok. 60 zl do ok. 45 zl przy rabacie 25%
-- 4) zysk segmentu zalezy od liczby klientow (Consumer ok. 52% klientow i ok. 52% zysku),
--    a zysk na klienta jest podobny (182-189 zl). Zysk marketu zalezy tez od tego,
--    jak dlugo market byl aktywny (hipoteza)
-- uwaga: dane wygladaja na syntetyczne, wiec to wnioski z tego zbioru, a nie o prawdziwym biznesie