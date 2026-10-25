# DataCo: analiza zamówień i dostaw w SQL

To mój pierwszy projekt na surowym pliku z danymi. Chciałem przejść cały proces: import, sprawdzenie danych, czyszczenie, pytania i wnioski. To projekt do nauki. Nie mam doświadczenia komercyjnego jako analityk.

## Dane
Zbiór DataCo Smart Supply Chain z Kaggle (180 519 wierszy, 53 kolumny):
https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis

Pliku z danymi tu nie wrzucam, trzeba go pobrać samemu.

## Narzędzia
PostgreSQL i DBeaver.

## Co zrobiłem
- wczytałem surowy plik do tabeli `raw` (wszystko jako tekst)
- sprawdziłem dane: puste kolumny, spacje na końcu tekstu, daty jako tekst, zdublowane kolumny, anulowane zamówienia z policzonymi dniami dostawy
- zrobiłem tabelę `clean` (45 kolumn) z poprawnymi typami
- odpowiedziałem na 5 pytań, każde z testem kontrolnym (sumy sprawdzałem z wynikiem)
- spisałem listę problemów z danymi i wnioski

## Pytania i wnioski
1. **Tryby wysyłki.** Plan dostawy jest stały w każdym trybie, więc odsetek spóźnień pokazuje ustawienie planu, a nie jakość dostaw.
2. **Markety i zysk.** Dane mają przerwy w miesiącach, więc porównanie miesiąc do miesiąca ma sens tylko w środku bloków. Zysk marketu zależy też od tego, jak długo był aktywny (hipoteza).
3. **Straty.** Ok. 19% pozycji przynosi stratę w prawie każdej kategorii. Strata idzie za liczbą sprzedanych pozycji, a nie za jedną kategorią.
4. **Rabat.** Rabat nie zwiększa strat, ale obniża zysk z pozycji dodatnich (z ok. 60 zł do ok. 45 zł przy rabacie 25%).
5. **Segmenty klientów.** Zysk segmentu wynika z liczby klientów. Zysk na klienta jest podobny (182–189 zł).

Dane wyglądają na syntetyczne, więc to są wnioski z tego zbioru, a nie o prawdziwym biznesie.

## Czego użyłem w SQL
CTE, LAG z PARTITION BY, FILTER, CASE, NULLIF, DATE_TRUNC, TO_TIMESTAMP, INTERVAL, GROUP BY i HAVING, EXCEPT, information_schema.

## Jak uruchomić
Plik `setup.sql` uruchamiam po sekcjach, a nie w całości. Dane wczytuję przez `\copy` w psql, bo importer w DBeaverze dopasowuje kolumny po nazwach i psuł mi import.

## Co dalej
Planuję raport w Excelu z trzema wnioskami, a potem Power BI.
