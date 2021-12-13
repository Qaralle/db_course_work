

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

		SELECT Gang_id INTO PBAND FROM Bandit WHERE Bandit.id = person;
		SELECT Block_AreaUnit_id INTO CRRPLASE FROM Accommodation WHERE Bandit_id = person and checkOutTime is null;
		SELECT Gang_id INTO BBAND FROM Block WHERE AreaUnit_id= destination;

		IF (PBAND = BBAND OR BBAND is null)
		THEN
			SELECT get_capacity(destination) INTO PL;
			IF (PL > 0)
			THEN
			RES:= true;
			UPDATE Accommodation SET checkOutTime = NOW() WHERE Block_AreaUnit_id = CRRPLASE and Bandit_id = person and checkOutTime is null ;
			insert into Accommodation values (NEXTVAL('Accommodation_id_seq'), destination ,person, NOW());
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
	SELECT checkInTime INTO RES FROM Accommodation WHERE Bandit_id=person and checkOutTime IS NULL; RETURN RES;
END;
$RES$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_capacity(plase integer)
RETURNS INTEGER AS $RES$
DECLARE 
	RES INTEGER;
	A INTEGER;
BEGIN
	SELECT COUNT(*) INTO RES FROM Accommodation WHERE Block_AreaUnit_id=plase and checkOutTime IS NULL;
	SELECT capacity INTO A FROM Block WHERE AreaUnit_id=plase;
	RES:= A -RES;
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;

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

	select max(time) INTO LAST_TIME from CaptureTry where Bandit_id = initiator;

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

	INSERT INTO CaptureTry VALUES(DEFAULT, attack_id, defense_id, initiator, NULL, now()) RETURNING id INTO ID_TRY ;

	IF(RAND<PROB)
	THEN
		SELECT NEXTVAL('Capture_id_seq') INTO ID_CAPTURE;
		INSERT INTO Capture VALUES(ID_CAPTURE, now());
		UPDATE CaptureTry SET Capture_id = ID_CAPTURE WHERE id = ID_TRY;

		UPDATE Block SET Gang_id = (SELECT Gang_id FROM Block WHERE AreaUnit_id = attack_id) WHERE AreaUnit_id = defense_id;

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
	SELECT isRespawn INTO RES FROM Block WHERE AreaUnit_id = block_id;
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

	SELECT Gang_id INTO BAND FROM Block WHERE AreaUnit_id = defense_id;
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

CREATE OR REPLACE FUNCTION inventary_add(bandid integer, itemid integer) RETURNS BOOLEAN AS $RES$
DECLARE
	RES BOOLEAN;
	CHARACT_TT characteristicType;
BEGIN
	insert into Inventory values(bandid, itemid);
	RETURN true;
END;
$RES$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_characteristic(place integer, charact text) RETURNS INTEGER AS $RES$
DECLARE
	RES INTEGER;
	CHARACT_TT characteristicType;
BEGIN
	SELECT CAST(charact AS characteristicType) INTO CHARACT_TT;
	SELECT SUM(Item.characteristic) INTO RES FROM Inventory INNER JOIN Item ON Item.id = Inventory.Item_id 
		INNER JOIN ItemType ON ItemType.id = Item.ItemType_id 
		WHERE ItemType.characteristicType = CHARACT_TT AND Inventory.Bandit_id IN (SELECT * FROM get_block_bandits_id(place));
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION count_characteristic_bandit(banditid integer, charact text) RETURNS INTEGER AS $RES$
DECLARE
	RES INTEGER;
	CHARACT_TT characteristicType;
BEGIN
	SELECT CAST (charact AS characteristicType) INTO CHARACT_TT;
	SELECT SUM(Item.characteristic) INTO RES FROM Inventory INNER JOIN Item ON Item.id = Inventory.Item_id 
		INNER JOIN ItemType ON ItemType.id = Item.ItemType_id 
		WHERE ItemType.characteristicType = CHARACT_TT AND Inventory.Bandit_id = banditid;
	RETURN RES;
END;
$RES$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_block_bandits_id(place integer) RETURNS SETOF INTEGER AS $$
		SELECT id as id FROM Bandit WHERE id IN (SELECT Bandit_id FROM Accommodation WHERE Block_AreaUnit_id = place AND checkOutTime is null); 
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_block_bandits_number(place integer) RETURNS BIGINT AS $$
		SELECT count(*) FROM Bandit WHERE id IN (SELECT Bandit_id FROM Accommodation WHERE Block_AreaUnit_id = place AND checkOutTime is null); 
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



CREATE OR REPLACE FUNCTION get_respawn(gangId integer) RETURNS INTEGER AS $$
DECLARE 
	ID_R INTEGER;
BEGIN
	SELECT AreaUnit_id into ID_R FROM Block WHERE Block.Gang_id in (SELECT Gang_id FROM Block WHERE Gang_id = gangId) AND isRespawn = true;
	RETURN ID_R;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION knock_down(bandit_id integer) RETURNS INTEGER AS $$

BEGIN
	IF(NOT is_knock_down(bandit_id))
	THEN	
		UPDATE Bandit SET isKnockDown = '00:05:00' WHERE id = bandit_id;
	END IF;
	RETURN bandit_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_knock_down(bandit_id integer) RETURNS BOOLEAN AS $$
DECLARE
	KNOCK TIME;
BEGIN
	SELECT isKnockDown INTO KNOCK FROM Bandit WHERE id = bandit_id;
	IF(KNOCK = '00:00:00')
	THEN
		RETURN false;
	ELSE
		RETURN true;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION what_is_blockid_bandit(bandit integer) RETURNS INTEGER AS $$
DECLARE
	RES INTEGER;
BEGIN
	SELECT Block_AreaUnit_id INTO RES FROM Accommodation WHERE Bandit_id = bandit and checkOutTime is null ;
	RETURN RES;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_ally(this_block integer, that_block integer) RETURNS BOOLEAN AS $$
DECLARE
	GANG1_ID INTEGER;
	GANG2_ID INTEGER;
BEGIN
	SELECT Gang_id INTO GANG1_ID FROM Block WHERE AreaUnit_id = this_block;
	SELECT Gang_id INTO GANG2_ID FROM Block WHERE AreaUnit_id = that_block;

	IF(GANG1_ID = GANG2_ID)
	THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION heal_bandit(banditid integer) RETURNS BOOLEAN AS $$
DECLARE 
	DEL TIME;
	FAK_NUMB INT;
	HOURS INT;
	MIN INT;
	SEC INT;
	ROW RECORD;
BEGIN
	IF(is_knock_down(banditid))
	THEN
		SELECT isKnockDown INTO DEL FROM Bandit WHERE id = banditid;
		
	
		FOR ROW IN SELECT Item.id, Item.characteristic FROM Inventory 
						INNER JOIN Item ON Inventory.Item_id = Item.id 
						INNER JOIN ItemType ON Item.ItemType_id = ItemType.id 
						WHERE Inventory.Bandit_id = banditid 
						and ItemType.characteristicType = 'HEAL'
		LOOP
			FAK_NUMB = ROW.characteristic; 
	
			HOURS := FAK_NUMB/3600;
			MIN := (FAK_NUMB%3600)/60;
			SEC := (FAK_NUMB%3600)%60;
			DEL := DEL - make_time(HOURS, MIN, SEC);
	
	
			PERFORM remove_item_from_bandit(ROW.id, banditid);
	
		END LOOP;
	
		UPDATE Bandit SET isKnockDown = DEL WHERE id = banditid;
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
		FOR ROW IN SELECT Item.id FROM Inventory 
						INNER JOIN Item ON Inventory.Item_id = Item.id 
						INNER JOIN ItemType ON Item.ItemType_id = ItemType.id 
						WHERE Inventory.Bandit_id = ROWP.get_block_bandits_id 
						and ItemType.characteristicType = 'HEAL'
		LOOP
	
			PERFORM remove_item_from_bandit(ROW.id, ROWP.get_block_bandits_id);
	
		END LOOP;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_item_from_bandit(itemid integer, bandit integer) RETURNS void AS $$
BEGIN
	DELETE FROM Inventory WHERE Bandit_id = bandit AND Item_id = itemid;
	DELETE FROM Item WHERE id = itemid;	
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
	SELECT X,Y INTO X_1,Y_1 FROM AreaUnit WHERE id= attack_id;
	SELECT X,Y INTO X_2,Y_2 FROM AreaUnit WHERE id= defense_id;

	SELECT |/((X_2-X_1)^2 + (Y_2-Y_1)^2) INTO DEC;
	IF (DEC <= |/(2))
	THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_last_time(worker integer) RETURNS TIMESTAMP AS $$
DECLARE
	LAST_TIME TIMESTAMP;
BEGIN
	SELECT max(interactionTime) INTO LAST_TIME FROM Work WHERE  Bandit_id = worker;
	RETURN LAST_TIME;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION work(worker integer,  type_of_product integer, name varchar(45), characteristic integer) RETURNS BOOLEAN AS $$
DECLARE 
	RES BOOLEAN;
	DIFF TIME;
	LAST_TIME TIMESTAMP;
	ID INTEGER;
	FLAG BOOLEAN;
	ID_BLOCK_RESP INTEGER;

BEGIN
	SELECT max(interactionTime) INTO LAST_TIME FROM Work WHERE  Bandit_id = worker;
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
		SELECT AreaUnit_id INTO ID_BLOCK_RESP FROM Block WHERE Block.Gang_id = (SELECT Gang_id FROM Bandit WHERE  Bandit.id = worker) AND isRespawn = true;
		ID := NEXTVAL('Work_id_seq');
		insert into Work values(ID,worker,ID_BLOCK_RESP, now());
		insert into Item values (NEXTVAL('Item_id_seq'), name, characteristic ,type_of_product, ID);
		RETURN true;
	ELSE
		RETURN false;
	END IF;

END;
$$ LANGUAGE plpgsql;