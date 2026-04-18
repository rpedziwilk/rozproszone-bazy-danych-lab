-- 3
CREATE DATABASE LINK dblinkFilia
CONNECT TO RBDN1_ST10
IDENTIFIED BY start123
USING 'rpedziwilkb';

-- 4
SELECT * FROM kursanci@dblinkFilia;

-- 5
CREATE SYNONYM kursanciSiedziba   FOR kursanci;
CREATE SYNONYM wykladowcySiedziba FOR wykladowcy;
CREATE SYNONYM kursySiedziba      FOR kursy;
CREATE SYNONYM rodzajeSiedziba    FOR rodzaje;

CREATE SYNONYM kursanciFilia      FOR kursanci@dblinkFilia;
CREATE SYNONYM wykladowcyFilia    FOR wykladowcy@dblinkFilia;
CREATE SYNONYM kursyFilia         FOR kursy@dblinkFilia;
CREATE SYNONYM rodzajeFilia       FOR rodzaje@dblinkFilia;

-- 6
CREATE OR REPLACE VIEW kursanciAll AS
    SELECT imie, nazwisko FROM kursanciSiedziba
    UNION
    SELECT imie, nazwisko FROM kursanciFilia;

CREATE OR REPLACE VIEW wykladowcyAll AS
    SELECT imie, nazwisko FROM wykladowcySiedziba
    UNION
    SELECT imie, nazwisko FROM wykladowcyFilia;

-- 7
CREATE OR REPLACE VIEW kursyAll AS
    SELECT r.nazwa                                AS nazwa_kursu,
           w.imie || ' ' || w.nazwisko            AS prowadzacy,
           COUNT(u.umowa_id)                      AS liczba_uczestnikow
    FROM kursySiedziba k
    JOIN rodzajeSiedziba r    ON k.rodzaj_id      = r.rodzaj_id
    JOIN wykladowcySiedziba w ON k.wykladowca_id  = w.wykladowca_id
    LEFT JOIN umowy u         ON k.kurs_id        = u.kurs_id
    GROUP BY r.nazwa, w.imie, w.nazwisko
    UNION ALL
    SELECT r.nazwa                                AS nazwa_kursu,
           w.imie || ' ' || w.nazwisko            AS prowadzacy,
           COUNT(u.umowa_id)                      AS liczba_uczestnikow
    FROM kursyFilia k
    JOIN rodzajeFilia r       ON k.rodzaj_id      = r.rodzaj_id
    JOIN wykladowcyFilia w    ON k.wykladowca_id  = w.wykladowca_id
    LEFT JOIN umowy u         ON k.kurs_id        = u.kurs_id
    GROUP BY r.nazwa, w.imie, w.nazwisko;

-- 8
SELECT SUM(przychod) AS przychod_lacznie
FROM (
    SELECT r.cena AS przychod
    FROM umowy u
    JOIN kursySiedziba k   ON u.kurs_id   = k.kurs_id
    JOIN rodzajeSiedziba r ON k.rodzaj_id = r.rodzaj_id
    UNION ALL
    SELECT r.cena AS przychod
    FROM umowy u
    JOIN kursyFilia k   ON u.kurs_id   = k.kurs_id
    JOIN rodzajeFilia r ON k.rodzaj_id = r.rodzaj_id
);

-- 9
SELECT SUM(koszt) AS koszty_lacznie
FROM (
    SELECT w.stawka * r.godz AS koszt
    FROM kursySiedziba k
    JOIN wykladowcySiedziba w ON k.wykladowca_id = w.wykladowca_id
    JOIN rodzajeSiedziba r    ON k.rodzaj_id     = r.rodzaj_id
    UNION ALL
    SELECT w.stawka * r.godz AS koszt
    FROM kursyFilia k
    JOIN wykladowcyFilia w ON k.wykladowca_id = w.wykladowca_id
    JOIN rodzajeFilia r    ON k.rodzaj_id     = r.rodzaj_id
);

-- 10
SELECT r.nazwa                                         AS nazwa_kursu,
       COUNT(u.umowa_id) * r.cena                      AS przychod,
       w.stawka * r.godz                               AS koszt,
       COUNT(u.umowa_id) * r.cena - w.stawka * r.godz AS zysk
FROM kursySiedziba k
JOIN rodzajeSiedziba r    ON k.rodzaj_id     = r.rodzaj_id
JOIN wykladowcySiedziba w ON k.wykladowca_id = w.wykladowca_id
LEFT JOIN umowy u         ON k.kurs_id       = u.kurs_id
GROUP BY r.nazwa, r.cena, w.stawka, r.godz
UNION ALL
SELECT r.nazwa                                         AS nazwa_kursu,
       COUNT(u.umowa_id) * r.cena                      AS przychod,
       w.stawka * r.godz                               AS koszt,
       COUNT(u.umowa_id) * r.cena - w.stawka * r.godz AS zysk
FROM kursyFilia k
JOIN rodzajeFilia r       ON k.rodzaj_id     = r.rodzaj_id
JOIN wykladowcyFilia w    ON k.wykladowca_id = w.wykladowca_id
LEFT JOIN umowy u         ON k.kurs_id       = u.kurs_id
GROUP BY r.nazwa, r.cena, w.stawka, r.godz;

-- 11
SELECT SUM(zysk) AS laczny_zysk
FROM (
    SELECT COUNT(u.umowa_id) * r.cena - w.stawka * r.godz AS zysk
    FROM kursySiedziba k
    JOIN rodzajeSiedziba r    ON k.rodzaj_id     = r.rodzaj_id
    JOIN wykladowcySiedziba w ON k.wykladowca_id = w.wykladowca_id
    LEFT JOIN umowy u         ON k.kurs_id       = u.kurs_id
    GROUP BY r.cena, w.stawka, r.godz
    UNION ALL
    SELECT COUNT(u.umowa_id) * r.cena - w.stawka * r.godz AS zysk
    FROM kursyFilia k
    JOIN rodzajeFilia r       ON k.rodzaj_id     = r.rodzaj_id
    JOIN wykladowcyFilia w    ON k.wykladowca_id = w.wykladowca_id
    LEFT JOIN umowy u         ON k.kurs_id       = u.kurs_id
    GROUP BY r.cena, w.stawka, r.godz
);
