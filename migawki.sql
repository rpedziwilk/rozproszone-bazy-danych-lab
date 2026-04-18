-- ============================================================
-- MIGAWKI FAST (zadania 1-4)
-- ============================================================

-- Przed zad. 1: w SIEDZIBIE (rpedziwilka) - dziennik migawki dla kursanci
-- (wymagany do odswiezania przyrostowego FAST)
CREATE MATERIALIZED VIEW LOG ON kursanci
WITH PRIMARY KEY
INCLUDING NEW VALUES;

-- 1 (w FILII - rpedziwilkb)
-- Dblink z filii do siedziby (jesli nie istnieje)
CREATE DATABASE LINK dblinkSiedziba
CONNECT TO RBDN1_ST10
IDENTIFIED BY start123
USING 'rpedziwilka';

CREATE MATERIALIZED VIEW kursanci_rep
REFRESH FAST ON DEMAND
START WITH SYSDATE
NEXT SYSDATE + 1
AS SELECT * FROM kursanci@dblinkSiedziba;

-- 2 (w SIEDZIBIE - rpedziwilka)
CREATE MATERIALIZED VIEW kursanci_local_rep
REFRESH FAST ON COMMIT
AS SELECT * FROM kursanci;

-- 3 (w SIEDZIBIE - rpedziwilka)
CREATE MATERIALIZED VIEW przychod_all
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT przychod_lacznie,
       ROUND(przychod_lacznie * 0.19, 2) AS podatek_19proc
FROM (
    SELECT SUM(cena_kursu) AS przychod_lacznie
    FROM (
        SELECT r.cena AS cena_kursu
        FROM umowy u
        JOIN kursy k              ON u.kurs_id   = k.kurs_id
        JOIN rodzaje r            ON k.rodzaj_id = r.rodzaj_id
        UNION ALL
        SELECT r.cena AS cena_kursu
        FROM umowy u
        JOIN kursy@dblinkFilia k   ON u.kurs_id   = k.kurs_id
        JOIN rodzaje@dblinkFilia r ON k.rodzaj_id = r.rodzaj_id
    )
);

-- 4 (w SIEDZIBIE - sprawdzenie mozliwosci FAST dla migawki z zad. 3)
-- Najpierw nalezy uruchomic skrypt utlxmv.sql (jednorazowo):
-- @?/rdbms/admin/utlxmv.sql

EXECUTE DBMS_MVIEW.EXPLAIN_MVIEW(
    'SELECT SUM(cena_kursu) AS przychod_lacznie
     FROM (
         SELECT r.cena AS cena_kursu
         FROM umowy u
         JOIN kursy k              ON u.kurs_id   = k.kurs_id
         JOIN rodzaje r            ON k.rodzaj_id = r.rodzaj_id
         UNION ALL
         SELECT r.cena AS cena_kursu
         FROM umowy u
         JOIN kursy@dblinkFilia k   ON u.kurs_id   = k.kurs_id
         JOIN rodzaje@dblinkFilia r ON k.rodzaj_id = r.rodzaj_id
     )',
    'test_fast_przychod'
);

SELECT capability_name, possible, msgtxt
FROM mv_capabilities_table
WHERE statement_id = 'test_fast_przychod';
-- Migawka ze zlozonym UNION ALL i funkcja agregujaca SUM
-- nie moze byc odswiezana w trybie FAST ON COMMIT.

-- ============================================================
-- MIGAWKI COMPLETE
-- ============================================================

-- 5 (w SIEDZIBIE - rpedziwilka)
-- Migawka REP_wykladowcy na bazie tabeli wykladowcy z filii,
-- odswiezana pelnnie (COMPLETE), na zadanie (ON DEMAND)
CREATE MATERIALIZED VIEW REP_wykladowcy
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM wykladowcy@dblinkFilia;

-- 6 (w FILII - rpedziwilkb)
-- Dodanie nowego wykladowcy
INSERT INTO wykladowcy (wykladowca_id, imie, nazwisko, stawka)
VALUES (115, 'NOWA', 'WYKLADOWCA', 110);
COMMIT;

-- 7 (w SIEDZIBIE - rpedziwilka)
-- Odczyt zawartosci migawki przed odswiezeniem (nowy wykladowca nie jest widoczny)
SELECT * FROM REP_wykladowcy;

-- 8 (w SIEDZIBIE - rpedziwilka)
-- Reczne odswiezenie migawki REP_wykladowcy w trybie COMPLETE
EXECUTE DBMS_MVIEW.REFRESH('REP_wykladowcy', 'C');

-- 9 (w SIEDZIBIE - rpedziwilka)
-- Odczyt zawartosci migawki po odswiezeniu (nowy wykladowca juz widoczny)
SELECT * FROM REP_wykladowcy;

-- 10 (w SIEDZIBIE - rpedziwilka)
-- Migawka REP_godz_wykladowcy_godziny: imiona, nazwiska wykladowcow z filii
-- + laczna liczba godzin prowadzonych kursow
-- Pierwsze zapelnienie ostatniego dnia biezacego miesiaca, potem co godzine
CREATE MATERIALIZED VIEW REP_godz_wykladowcy_godziny
BUILD DEFERRED
REFRESH COMPLETE
START WITH LAST_DAY(SYSDATE)
NEXT SYSDATE + 1/24
AS
SELECT w.imie,
       w.nazwisko,
       SUM(r.godz) AS laczna_liczba_godz
FROM wykladowcy@dblinkFilia w
JOIN kursy@dblinkFilia k    ON k.wykladowca_id = w.wykladowca_id
JOIN rodzaje@dblinkFilia r  ON k.rodzaj_id     = r.rodzaj_id
GROUP BY w.imie, w.nazwisko;

-- 11 (w SIEDZIBIE - rpedziwilka)
-- Migawka REP_kursy: kursy aktualnie prowadzone w filii
-- (nazwa kursu, prowadzacy, godz, oplata), zapelniana natychmiast, odswiezana co tydzien
CREATE MATERIALIZED VIEW REP_kursy
BUILD IMMEDIATE
REFRESH COMPLETE
START WITH SYSDATE
NEXT SYSDATE + 7
AS
SELECT r.nazwa                           AS nazwa_kursu,
       w.imie || ' ' || w.nazwisko       AS prowadzacy,
       r.godz                            AS liczba_godz,
       r.cena                            AS oplata
FROM kursy@dblinkFilia k
JOIN rodzaje@dblinkFilia r    ON k.rodzaj_id     = r.rodzaj_id
JOIN wykladowcy@dblinkFilia w ON k.wykladowca_id = w.wykladowca_id;

-- 12 (w SIEDZIBIE - rpedziwilka)
-- Perspektywa (zwykly widok) laczaca kursy z filii (z migawki REP_kursy)
-- oraz kursy z siedziby
CREATE OR REPLACE VIEW kursy_all_view AS
SELECT nazwa_kursu, prowadzacy, liczba_godz, oplata
FROM REP_kursy
UNION ALL
SELECT r.nazwa                        AS nazwa_kursu,
       w.imie || ' ' || w.nazwisko    AS prowadzacy,
       r.godz                         AS liczba_godz,
       r.cena                         AS oplata
FROM kursy k
JOIN rodzaje r    ON k.rodzaj_id     = r.rodzaj_id
JOIN wykladowcy w ON k.wykladowca_id = w.wykladowca_id;

-- 13 (w SIEDZIBIE - rpedziwilka)
-- Wyswietlenie informacji o utworzonych migawkach
SELECT mview_name, refresh_method, refresh_mode, last_refresh_date
FROM user_mviews;
