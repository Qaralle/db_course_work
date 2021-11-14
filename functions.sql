/*Функция смены проживания, проверяет прошло ли достаточно времени с момента заселения
после чего заполняет время выселения и создает новую запись в проживание. Также чекает банду*/

CREATE OR REPLACE FUNCTION run_over(destination integer, person integer)
RETURNS BOOLEAN AS $RES$
DECLARE 
	RES BOOLEAN;
	DIFF TIME;
	CAP INTEGER;
	PBAND INTEGER;
	BBAND INTEGER;
	PL INTEGER;
	ID INTEGER;
	CRRPLASE INTEGER;
BEGIN
	DIFF := NOW() - get_time_in(person);
	IF (DIFF > '00:05:00' and (NOT is_knock_down(person)))
	THEN

		SELECT "Банда_id" INTO PBAND FROM "Бандит" WHERE "Бандит"."id" = person;
		SELECT "Блок_ЕдиницаТерритории_id" INTO CRRPLASE FROM "Проживание" WHERE "Бандит_id" = person and "времяВыселения" is null;
		SELECT "Банда_id" INTO BBAND FROM "Блок" WHERE "ЕдиницаТерритории_id"= destination;

		IF (PBAND = BBAND OR BBAND is null)
		THEN
			SELECT get_capacity(destination) INTO PL;
			IF (PL > 0)
			THEN
			RES:= true;
			UPDATE "Проживание" SET "времяВыселения" = NOW() WHERE "Блок_ЕдиницаТерритории_id" = CRRPLASE and "Бандит_id" = person and "времяВыселения" is null ;
			insert into "Проживание" values (NEXTVAL('Проживание_id_seq'), destination ,person, NOW());
			ELSE
			RES:= false;
			END IF;
		ELSE
		RES:= false;
		END IF;			
	ELSE
	RES:= false;
	END IF;
	RETURN RES;

END;
$RES$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_time_in(person integer)
RETURNS TIMESTAMP AS $RES$
DECLARE 
	RES TIMESTAMP;
BEGIN
	SELECT "времяЗаселения" INTO RES FROM "Проживание" WHERE "Бандит_id"=person and "времяВыселения" IS NULL;
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_capacity(plase integer)
RETURNS INTEGER AS $RES$
DECLARE 
	RES INTEGER;
	A INTEGER;
BEGIN
	SELECT COUNT(*) INTO RES FROM "Проживание" WHERE "Блок_ЕдиницаТерритории_id"=plase and "времяВыселения" IS NULL;
	SELECT "вместительность" INTO A FROM "Блок" WHERE "ЕдиницаТерритории_id"=plase;
	RES:= A -RES;
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;

/*Функция захвата территории*/
CREATE OR REPLACE FUNCTION capture_block(defense_id integer, initiator integer) RETURNS BOOLEAN AS $$
DECLARE
	DIFF TIME;
	LAST_TIME TIME;
	attack_id INTEGER;
	PROB REAL;
	RAND REAL;
	ID_CAPTURE INTEGER;
	ID_TRY INTEGER;
	ID_LIVING INTEGER;
	ID_B INTEGER;
	ROWP RECORD;
	ROW RECORD;
	FLAG BOOLEAN;

BEGIN
	SELECT what_is_blockid_bandit(initiator) INTO attack_id;

	select max(время) INTO LAST_TIME from Попытка where Инициатор_id = initiator;

	IF (LAST_TIME is null)
	THEN	
		FLAG := true;
	ELSE
		DIFF := NOW() - LAST_TIME;
		IF (DIFF > '00:05:00')
		THEN
			FLAG := true;
		ELSE
			FLAG := false;
		END IF;
	END IF;

	IF (not FLAG or is_ally(attack_id, defense_id) or is_respawn(defense_id) or NOT is_near(attack_id, defense_id) or is_knock_down(initiator))
	THEN
		RETURN false;
	END IF;

	SELECT count_probability(attack_id,defense_id) INTO PROB;
	SELECT random() INTO RAND;

	INSERT INTO Попытка VALUES(DEFAULT, attack_id, defense_id, initiator, NULL, now()) RETURNING id INTO ID_TRY ;

	IF(RAND<PROB)
	THEN
		SELECT NEXTVAL('Захват_id_seq') INTO ID_CAPTURE;
		INSERT INTO Захват VALUES(ID_CAPTURE, now());
		UPDATE Попытка SET Захват_id = ID_CAPTURE WHERE id = ID_TRY;

		UPDATE Блок SET Банда_id = (SELECT Банда_id FROM Блок WHERE ЕдиницаТерритории_id = attack_id) WHERE ЕдиницаТерритории_id = defense_id;

		PERFORM remove_heal_for_block(attack_id);
		
		RETURN true;
	ELSE
		PERFORM remove_heal_for_block(defense_id);
		PERFORM remove_heal_for_block(attack_id);

		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_respawn(block_id integer) RETURNS BOOLEAN AS $RES$
DECLARE
	RES BOOLEAN;
BEGIN
	SELECT "респа" INTO RES FROM "Блок" WHERE "ЕдиницаТерритории_id" = block_id;
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION count_probability(attack_id integer, defense_id integer) RETURNS REAL AS $RES$
DECLARE
	ATTACK_FACTOR_DMG INTEGER;
	DEFENSE_FACTOR_DMG INTEGER;
	DEFENSE_FACTOR INTEGER;
	ATTACK_COUNT INTEGER;
	DEFENSE_COUNT INTEGER;
	A INTEGER;
	B INTEGER;
	PROB REAL;
	BAND INTEGER;
	SIZE INT;
BEGIN

	SELECT Банда_id INTO BAND FROM Блок WHERE ЕдиницаТерритории_id = defense_id;
	IF (BAND is null)
	THEN
		PROB := 1.0;
		RETURN PROB;
	ELSE
		SELECT get_block_bandits_number(defense_id) INTO SIZE;

		IF (SIZE>0)
		THEN

			ATTACK_FACTOR_DMG:= count_characteristic(attack_id, 'DAMAGE');
			DEFENSE_FACTOR_DMG:= count_characteristic(defense_id, 'DAMAGE');
			DEFENSE_FACTOR:= count_characteristic(defense_id, 'PROTECT');

			SELECT COUNT(*) INTO ATTACK_COUNT FROM get_block_bandits_id(attack_id);
			SELECT COUNT(*) INTO DEFENSE_COUNT FROM get_block_bandits_id(defense_id);

			A := ATTACK_FACTOR_DMG + ATTACK_COUNT;
			B := DEFENSE_FACTOR_DMG + DEFENSE_COUNT + DEFENSE_FACTOR;

			PROB := (cast(A as REAL) /(cast(A as REAL) +cast(B as REAL)));
			RETURN PROB;
		ELSE
			PROB := 1.0;
			RETURN PROB;
		END IF;
	END IF;
END;
$RES$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_characteristic(place integer, characteristic типХарактеристики) RETURNS INTEGER AS $RES$
DECLARE
	RES INTEGER;
BEGIN
	SELECT SUM(Предмет.характеристика) INTO RES FROM Инвентарь INNER JOIN Предмет ON Предмет.id = Инвентарь.Предмет_id 
		INNER JOIN ТипПредмета ON ТипПредмета.id = Предмет.ТипПредмета_id 
		WHERE ТипПредмета.типХарактеристики = characteristic AND Инвентарь.Бандит_id IN (SELECT * FROM get_block_bandits_id(place));
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_block_bandits_id(place integer) RETURNS SETOF INTEGER AS $$
		SELECT id as id FROM Бандит WHERE id IN (SELECT Бандит_id FROM Проживание WHERE Блок_ЕдиницаТерритории_id = place AND "времяВыселения" is null); 
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_block_bandits_number(place integer) RETURNS BIGINT AS $$
		SELECT count(*) FROM Бандит WHERE id IN (SELECT Бандит_id FROM Проживание WHERE Блок_ЕдиницаТерритории_id = place AND "времяВыселения" is null); 
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION knock_down(anyarray) RETURNS BOOLEAN AS $$
DECLARE 
	ID_B INTEGER;
BEGIN
	FOR ID_B IN SELECT $1[i] FROM generate_subscripts($1,1) g(i)
	LOOP
		PERFORM knock_down(ID_B);
	END LOOP;
	
	RETURN true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION knock_down(bandit_id integer) RETURNS INTEGER AS $$

BEGIN
	IF(NOT is_knock_down(bandit_id))
	THEN	
		UPDATE Бандит SET безСознания = '00:05:00' WHERE id = bandit_id;
	END IF;
	RETURN bandit_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_knock_down(bandit_id integer) RETURNS BOOLEAN AS $$
DECLARE
	KNOCK TIME;
BEGIN
	SELECT безСознания INTO KNOCK FROM Бандит WHERE id = bandit_id;
	IF(KNOCK = '00:00:00')
	THEN
		RETURN false;
	ELSE
		RETURN true;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION what_is_blockid_bandit(bandit_id integer) RETURNS INTEGER AS $$
DECLARE
	RES INTEGER;
BEGIN
	SELECT Блок_ЕдиницаТерритории_id INTO RES FROM Проживание WHERE Бандит_id = bandit_id and "времяВыселения" is null ;
	RETURN RES;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_ally(this_block integer, that_block integer) RETURNS BOOLEAN AS $$
DECLARE
	GANG1_ID INTEGER;
	GANG2_ID INTEGER;
BEGIN
	SELECT Банда_id INTO GANG1_ID FROM Блок WHERE ЕдиницаТерритории_id = this_block;
	SELECT Банда_id INTO GANG2_ID FROM Блок WHERE ЕдиницаТерритории_id = that_block;

	IF(GANG1_ID = GANG2_ID)
	THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;

/*Функция лечения*/
CREATE OR REPLACE FUNCTION heal_bandit(bandit_id integer) RETURNS BOOLEAN AS $$
DECLARE 
	DEL TIME;
	FAK_NUMB INT;
	HOURS INT;
	MIN INT;
	SEC INT;
	ROW RECORD;
BEGIN
	IF(is_knock_down(bandit_id))
	THEN
		SELECT безСознания INTO DEL FROM Бандит WHERE id = bandit_id;
		
	
		FOR ROW IN SELECT Предмет.id, Предмет.характеристика FROM Инвентарь 
						INNER JOIN Предмет ON Инвентарь.Предмет_id = Предмет.id 
						INNER JOIN ТипПредмета ON Предмет.ТипПредмета_id = ТипПредмета.id 
						WHERE Инвентарь.Бандит_id = bandit_id 
						and ТипПредмета.типХарактеристики = 'HEAL'
		LOOP
			FAK_NUMB = ROW.характеристика; 
	
			HOURS := FAK_NUMB/3600;
			MIN := (FAK_NUMB%3600)/60;
			SEC := (FAK_NUMB%3600)%60;
			DEL := DEL - make_time(HOURS, MIN, SEC);
	
	
			PERFORM remove_item_from_bandit(ROW.id, bandit_id);
	
		END LOOP;
	
		UPDATE Бандит SET безСознания = DEL WHERE id = bandit_id;
		RETURN true;
	END IF;
	
	RETURN false;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_heal_for_block(block_id integer) RETURNS void AS $$
DECLARE
	ROWP RECORD;
	ROW RECORD;
BEGIN
	FOR ROWP IN SELECT get_block_bandits_id FROM get_block_bandits_id(block_id)

	LOOP
		FOR ROW IN SELECT Предмет.id FROM Инвентарь 
						INNER JOIN Предмет ON Инвентарь.Предмет_id = Предмет.id 
						INNER JOIN ТипПредмета ON Предмет.ТипПредмета_id = ТипПредмета.id 
						WHERE Инвентарь.Бандит_id = ROWP.get_block_bandits_id 
						and ТипПредмета.типХарактеристики = 'HEAL'
		LOOP
	
			PERFORM remove_item_from_bandit(ROW.id, ROWP.get_block_bandits_id);
	
		END LOOP;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_item_from_bandit(item_id integer, bandit_id integer) RETURNS void AS $$
BEGIN
	DELETE FROM Инвентарь WHERE Бандит_id = bandit_id AND Предмет_id = item_id;
	DELETE FROM Предмет WHERE id = item_id;	
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_near(attack_id integer, defense_id integer) RETURNS BOOLEAN AS $$
DECLARE
	X_1 INTEGER;
	X_2 INTEGER;
	Y_1 INTEGER;
	Y_2 INTEGER;
	DEC REAL;
BEGIN
	SELECT X,Y INTO X_1,Y_1 FROM ЕдиницаТерритории WHERE id= attack_id;
	SELECT X,Y INTO X_2,Y_2 FROM ЕдиницаТерритории WHERE id= defense_id;

	SELECT |/((X_2-X_1)^2 + (Y_2-Y_1)^2) INTO DEC;
	IF (DEC <= |/(2))
	THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION work(worker integer,  type_of_product integer, name varchar(45), characteristic integer) RETURNS BOOLEAN AS $$
DECLARE 
	RES BOOLEAN;
	DIFF TIME;
	LAST_TIME TIME;
	ID INTEGER;
	FLAG BOOLEAN;
	ID_BLOCK_RESP INTEGER;

BEGIN
	SELECT max(времяВзаимодействия) INTO LAST_TIME FROM Работа WHERE  Бандит_id = worker;
	IF (LAST_TIME is null)
	THEN	
		FLAG := true;
	ELSE
		DIFF := NOW() - LAST_TIME;
		IF (DIFF > '00:05:00')
		THEN
			FLAG := true;
		ELSE
			FLAG := false;
		END IF;
	END IF;
		
	IF (FLAG and (NOT is_knock_down(worker)))
	THEN
		SELECT ЕдиницаТерритории_id INTO ID_BLOCK_RESP FROM Блок WHERE Блок.Банда_id = (SELECT Банда_id FROM Бандит WHERE  Бандит.id = worker) AND респа = true;
		ID := NEXTVAL('Работа_id_seq');
		insert into "Работа" values(ID,worker,ID_BLOCK_RESP, now());
		insert into "Предмет" values (NEXTVAL('Предмет_id_seq'), name, characteristic ,type_of_product, ID);
		RETURN true;
	ELSE
		RETURN false;
	END IF;

END;
$$ LANGUAGE plpgsql;