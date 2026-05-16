-- ============================================================
-- ROZWIĄZANIA ZADAŃ PL/SQL
-- Baza danych uczelni: siedziba (BYDGOSZCZ) + filia (SZCZECIN)
-- ============================================================

SET SERVEROUTPUT ON;

-- ============================================================
-- ZADANIE 1. Pierwszy blok PL/SQL
-- ============================================================

DECLARE
  v_kursanci   NUMBER;
  v_kursy      NUMBER;
  v_wykladowcy NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_kursanci   FROM kursanci;
  SELECT COUNT(*) INTO v_kursy      FROM kursy;
  SELECT COUNT(*) INTO v_wykladowcy FROM wykladowcy;

  DBMS_OUTPUT.PUT_LINE('Liczba kursantów: '    || v_kursanci);
  DBMS_OUTPUT.PUT_LINE('Liczba kursów: '       || v_kursy);
  DBMS_OUTPUT.PUT_LINE('Liczba wykładowców: '  || v_wykladowcy);
END;
/

-- ============================================================
-- ZADANIE 2. Łączna wartość umów dla Bydgoszczy
-- ============================================================

DECLARE
  v_suma NUMBER;
BEGIN
  SELECT SUM(r.cena)
  INTO v_suma
  FROM umowy u
  JOIN kursy k   ON u.kurs_id    = k.kurs_id
  JOIN rodzaje r ON k.rodzaj_id  = r.rodzaj_id
  WHERE u.miasto = 'BYDGOSZCZ';

  DBMS_OUTPUT.PUT_LINE('Łączna wartość umów dla BYDGOSZCZY: ' || v_suma || ' zł');
END;
/

-- ============================================================
-- ZADANIE 3. Ocena liczby umów dla miasta
-- ============================================================

DECLARE
  v_miasto VARCHAR2(30) := 'BYDGOSZCZ';
  v_liczba NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_liczba
  FROM umowy
  WHERE miasto = v_miasto;

  IF v_liczba = 0 THEN
    DBMS_OUTPUT.PUT_LINE('Brak umów dla miasta');
  ELSIF v_liczba < 50 THEN
    DBMS_OUTPUT.PUT_LINE('Mała liczba umów');
  ELSIF v_liczba <= 100 THEN
    DBMS_OUTPUT.PUT_LINE('Średnia liczba umów');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Duża liczba umów');
  END IF;
END;
/

-- ============================================================
-- ZADANIE 4. Lista kursów w siedzibie
-- ============================================================

BEGIN
  FOR r IN (
    SELECT k.kurs_id,
           ro.nazwa,
           ro.godz,
           ro.cena,
           w.imie || ' ' || w.nazwisko AS prowadzacy
    FROM kursy k
    JOIN rodzaje    ro ON k.rodzaj_id     = ro.rodzaj_id
    JOIN wykladowcy w  ON k.wykladowca_id = w.wykladowca_id
    ORDER BY k.kurs_id
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      'Kurs ' || r.kurs_id || ': ' || r.nazwa || ', ' ||
      r.godz  || 'h, '             || r.cena  || ' zł, prowadzący: ' || r.prowadzacy
    );
  END LOOP;
END;
/

-- ============================================================
-- ZADANIE 5. Procedura raportująca umowy dla miasta
-- ============================================================

CREATE OR REPLACE PROCEDURE raport_umow_miasto(p_miasto IN VARCHAR2) IS
  v_liczba NUMBER;
  v_suma   NUMBER;
  v_srednia NUMBER;
BEGIN
  SELECT COUNT(*), SUM(r.cena), AVG(r.cena)
  INTO v_liczba, v_suma, v_srednia
  FROM umowy u
  JOIN kursy k   ON u.kurs_id   = k.kurs_id
  JOIN rodzaje r ON k.rodzaj_id = r.rodzaj_id
  WHERE u.miasto = p_miasto;

  DBMS_OUTPUT.PUT_LINE('Raport dla miasta: '       || p_miasto);
  DBMS_OUTPUT.PUT_LINE('Liczba umów: '             || v_liczba);
  DBMS_OUTPUT.PUT_LINE('Łączna wartość umów: '     || v_suma             || ' zł');
  DBMS_OUTPUT.PUT_LINE('Średnia wartość umowy: '   || ROUND(v_srednia, 2) || ' zł');
END;
/

BEGIN
  raport_umow_miasto('BYDGOSZCZ');
END;
/

-- ============================================================
-- ZADANIE 6. Funkcja zwracająca cenę kursu
-- ============================================================

CREATE OR REPLACE FUNCTION wartosc_kursu(p_kurs_id IN NUMBER)
RETURN NUMBER IS
  v_cena NUMBER;
BEGIN
  SELECT r.cena
  INTO v_cena
  FROM kursy k
  JOIN rodzaje r ON k.rodzaj_id = r.rodzaj_id
  WHERE k.kurs_id = p_kurs_id;

  RETURN v_cena;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
END;
/

DECLARE
  v_cena NUMBER;
BEGIN
  v_cena := wartosc_kursu(1);
  DBMS_OUTPUT.PUT_LINE('Cena kursu: ' || v_cena);
END;
/

-- ============================================================
-- ZADANIE 7. Obsługa wyjątków: wyszukiwanie kursanta
-- ============================================================

CREATE OR REPLACE PROCEDURE pokaz_kursanta(p_kursant_id IN NUMBER) IS
  v_imie    VARCHAR2(20);
  v_nazwisko VARCHAR2(30);
BEGIN
  SELECT imie, nazwisko
  INTO v_imie, v_nazwisko
  FROM kursanci
  WHERE kursant_id = p_kursant_id;

  DBMS_OUTPUT.PUT_LINE(v_imie || ' ' || v_nazwisko);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Nie znaleziono kursanta o ID: ' || p_kursant_id);
END;
/

BEGIN
  pokaz_kursanta(1);
  pokaz_kursanta(9999);
END;
/

-- Wariant dodatkowy: wyszukiwanie po nazwisku
CREATE OR REPLACE PROCEDURE pokaz_kursanta_nazwisko(p_nazwisko IN VARCHAR2) IS
  v_imie    VARCHAR2(20);
  v_nazwisko VARCHAR2(30);
BEGIN
  SELECT imie, nazwisko
  INTO v_imie, v_nazwisko
  FROM kursanci
  WHERE nazwisko = p_nazwisko;

  DBMS_OUTPUT.PUT_LINE(v_imie || ' ' || v_nazwisko);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Nie znaleziono kursanta o nazwisku: ' || p_nazwisko);
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('Znaleziono więcej niż jednego kursanta o nazwisku: ' || p_nazwisko);
END;
/

BEGIN
  pokaz_kursanta_nazwisko('NOWAK');
END;
/

-- ============================================================
-- ZADANIE 8. Kursor jawny: szczegółowy raport umów
-- ============================================================

DECLARE
  CURSOR c_umowy IS
    SELECT u.umowa_id,
           ka.imie || ' ' || ka.nazwisko AS kursant,
           r.nazwa                        AS kurs_nazwa,
           r.cena
    FROM umowy u
    JOIN kursanci   ka ON u.kursant_id  = ka.kursant_id
    JOIN kursy      k  ON u.kurs_id     = k.kurs_id
    JOIN rodzaje    r  ON k.rodzaj_id   = r.rodzaj_id
    WHERE u.miasto = 'BYDGOSZCZ'
    ORDER BY u.umowa_id;

  v_rec c_umowy%ROWTYPE;
BEGIN
  OPEN c_umowy;
  LOOP
    FETCH c_umowy INTO v_rec;
    EXIT WHEN c_umowy%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(
      'Umowa ' || v_rec.umowa_id || ' | ' || v_rec.kursant ||
      ' | '   || v_rec.kurs_nazwa || ' | ' || v_rec.cena || ' zł'
    );
  END LOOP;
  CLOSE c_umowy;
END;
/

-- ============================================================
-- ZADANIE 9. Raport umów ze Szczecina
-- ============================================================

CREATE OR REPLACE PROCEDURE raport_umow_szczecin IS
BEGIN
  FOR r IN (
    SELECT u.umowa_id,
           k.imie  || ' ' || k.nazwisko AS kursant,
           ro.nazwa                      AS kurs_nazwa,
           ro.cena,
           u.miasto
    FROM umowy u
    JOIN mv_kursanci_filia k  ON u.kursant_id = k.kursant_id
    JOIN mv_kursy_filia    ks ON u.kurs_id    = ks.kurs_id
    JOIN mv_rodzaje_filia  ro ON ks.rodzaj_id = ro.rodzaj_id
    WHERE u.miasto = 'SZCZECIN'
    ORDER BY u.umowa_id
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      'Umowa ' || r.umowa_id || ' | ' || r.kursant ||
      ' | '   || r.kurs_nazwa || ' | ' || r.cena || ' zł | ' || r.miasto
    );
  END LOOP;
END;
/

BEGIN
  raport_umow_szczecin;
END;
/

-- ============================================================
-- ZADANIE 10. Raport całej uczelni
-- ============================================================

CREATE OR REPLACE PROCEDURE raport_uczelni IS
  v_liczba_bydg  NUMBER;
  v_suma_bydg    NUMBER;
  v_max_bydg     VARCHAR2(30);
  v_pop_bydg     VARCHAR2(30);

  v_liczba_szcz  NUMBER;
  v_suma_szcz    NUMBER;
  v_max_szcz     VARCHAR2(30);
  v_pop_szcz     VARCHAR2(30);
BEGIN
  -- ---- BYDGOSZCZ ----
  SELECT COUNT(*), SUM(r.cena)
  INTO v_liczba_bydg, v_suma_bydg
  FROM umowy u
  JOIN kursy k   ON u.kurs_id   = k.kurs_id
  JOIN rodzaje r ON k.rodzaj_id = r.rodzaj_id
  WHERE u.miasto = 'BYDGOSZCZ';

  SELECT ro.nazwa INTO v_max_bydg
  FROM (
    SELECT ro2.nazwa, ro2.cena
    FROM umowy u
    JOIN kursy k    ON u.kurs_id   = k.kurs_id
    JOIN rodzaje ro2 ON k.rodzaj_id = ro2.rodzaj_id
    WHERE u.miasto = 'BYDGOSZCZ'
    ORDER BY ro2.cena DESC
  ) ro
  WHERE ROWNUM = 1;

  SELECT ro.nazwa INTO v_pop_bydg
  FROM (
    SELECT ro2.nazwa, COUNT(*) AS cnt
    FROM umowy u
    JOIN kursy k     ON u.kurs_id   = k.kurs_id
    JOIN rodzaje ro2 ON k.rodzaj_id = ro2.rodzaj_id
    WHERE u.miasto = 'BYDGOSZCZ'
    GROUP BY ro2.nazwa
    ORDER BY cnt DESC
  ) ro
  WHERE ROWNUM = 1;

  -- ---- SZCZECIN ----
  SELECT COUNT(*), SUM(r.cena)
  INTO v_liczba_szcz, v_suma_szcz
  FROM umowy u
  JOIN mv_kursy_filia   k  ON u.kurs_id   = k.kurs_id
  JOIN mv_rodzaje_filia r  ON k.rodzaj_id = r.rodzaj_id
  WHERE u.miasto = 'SZCZECIN';

  SELECT ro.nazwa INTO v_max_szcz
  FROM (
    SELECT ro2.nazwa, ro2.cena
    FROM umowy u
    JOIN mv_kursy_filia   k    ON u.kurs_id   = k.kurs_id
    JOIN mv_rodzaje_filia ro2  ON k.rodzaj_id = ro2.rodzaj_id
    WHERE u.miasto = 'SZCZECIN'
    ORDER BY ro2.cena DESC
  ) ro
  WHERE ROWNUM = 1;

  SELECT ro.nazwa INTO v_pop_szcz
  FROM (
    SELECT ro2.nazwa, COUNT(*) AS cnt
    FROM umowy u
    JOIN mv_kursy_filia   k    ON u.kurs_id   = k.kurs_id
    JOIN mv_rodzaje_filia ro2  ON k.rodzaj_id = ro2.rodzaj_id
    WHERE u.miasto = 'SZCZECIN'
    GROUP BY ro2.nazwa
    ORDER BY cnt DESC
  ) ro
  WHERE ROWNUM = 1;

  -- ---- WYDRUK ----
  DBMS_OUTPUT.PUT_LINE('RAPORT UCZELNI');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Miasto: BYDGOSZCZ');
  DBMS_OUTPUT.PUT_LINE('Liczba umów: '          || v_liczba_bydg);
  DBMS_OUTPUT.PUT_LINE('Łączna wartość umów: '  || v_suma_bydg  || ' zł');
  DBMS_OUTPUT.PUT_LINE('Najdroższy kurs: '      || v_max_bydg);
  DBMS_OUTPUT.PUT_LINE('Najpopularniejszy kurs: ' || v_pop_bydg);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Miasto: SZCZECIN');
  DBMS_OUTPUT.PUT_LINE('Liczba umów: '          || v_liczba_szcz);
  DBMS_OUTPUT.PUT_LINE('Łączna wartość umów: '  || v_suma_szcz  || ' zł');
  DBMS_OUTPUT.PUT_LINE('Najdroższy kurs: '      || v_max_szcz);
  DBMS_OUTPUT.PUT_LINE('Najpopularniejszy kurs: ' || v_pop_szcz);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('PODSUMOWANIE');
  DBMS_OUTPUT.PUT_LINE('Liczba wszystkich umów: '         || (v_liczba_bydg + v_liczba_szcz));
  DBMS_OUTPUT.PUT_LINE('Łączna wartość wszystkich umów: ' || (v_suma_bydg   + v_suma_szcz) || ' zł');
END;
/

BEGIN
  raport_uczelni;
END;
/
