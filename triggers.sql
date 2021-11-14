CREATE OR REPLACE FUNCTION capturead_results() RETURNS trigger AS $TRIGGER$
DECLARE
	BLOCK_ID INTEGER;
	DEF_BANDITS_ID INTEGER[];
	ID_BLOCK_RESP INTEGER;
	ID_B INTEGER;
	SIZE INTEGER;
BEGIN
	IF (OLD.Защита_id = NEW.Защита_id)
	THEN
		SELECT array_agg(id) INTO DEF_BANDITS_ID FROM get_block_bandits_id(NEW.Защита_id) AS id;
		SELECT ЕдиницаТерритории_id INTO ID_BLOCK_RESP FROM Блок WHERE Блок.Банда_id = (SELECT Банда_id FROM Блок WHERE ЕдиницаТерритории_id = NEW.Защита_id) AND респа = true;
	
		PERFORM knock_down(DEF_BANDITS_ID);
	
		SELECT ARRAY_LENGTH(DEF_BANDITS_ID,1) INTO SIZE;
		IF (SIZE>0)
		THEN
			FOREACH ID_B IN ARRAY DEF_BANDITS_ID
			LOOP
				UPDATE "Проживание" SET "времяВыселения" = NOW() WHERE "Бандит_id" = ID_B and "времяВыселения" is null ;
				insert into "Проживание" values (NEXTVAL('Проживание_id_seq'), ID_BLOCK_RESP  ,ID_B, NOW(),null);
			END LOOP;
		END IF;
	END;	
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION respawn_heal() RETURNS trigger AS $TRIGGER$
DECLARE
	BLOCK_ID INTEGER;
	IS_RESPA BOOLEAN;

BEGIN
	SELECT респа INTO IS_RESPA FROM Блок WHERE ЕдиницаТерритории_id = NEW.Блок_ЕдиницаТерритории_id;
	IF (IS_RESPA and is_knock_down(NEW.Бандит_id))
	THEN
		PERFORM heal_bandit(NEW.Бандит_id);
	END IF;
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION add_to_inventory() RETURNS trigger AS $TRIGGER$
DECLARE
	ID_BLOCK_RESP INTEGER;
	ID_WORKER INTEGER;
BEGIN
	SELECT Бандит_id INTO ID_WORKER FROM Работа WHERE id = NEW.Работа_id;
	insert into Инвентарь values(ID_WORKER, NEW.id);
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_data() RETURNS trigger AS $TRIGGER$
DECLARE
	TIME_1 TIME;
	TIME_2 TIME;

BEGIN
	SELECT время INTO TIME_1 FROM Захват WHERE id = NEW.Захват_id;
	TIME_2:=NEW.время;

	IF (TIME_1 < TIME_2)
	THEN
		RAISE EXCEPTION 'Захват не может произойти до попытки';
	END IF;
		
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS capturead ON Попытка;

DROP TRIGGER IF EXISTS respawn_heal ON Проживание;

DROP TRIGGER IF EXISTS add_to_inventory ON Предмет;

DROP TRIGGER IF EXISTS check_data ON Попытка;

CREATE TRIGGER capturead AFTER UPDATE ON Попытка
    FOR EACH ROW EXECUTE PROCEDURE capturead_results();

CREATE TRIGGER respawn_heal AFTER INSERT ON Проживание
    FOR EACH ROW EXECUTE PROCEDURE respawn_heal();

CREATE TRIGGER add_to_inventory AFTER INSERT ON Предмет
    FOR EACH ROW EXECUTE PROCEDURE add_to_inventory();

CREATE TRIGGER check_data BEFORE INSERT OR UPDATE ON Попытка
    FOR EACH ROW EXECUTE PROCEDURE check_data();


