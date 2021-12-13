CREATE OR REPLACE FUNCTION capturead_results() RETURNS trigger AS $TRIGGER$
DECLARE
	BLOCK_ID INTEGER;
	DEF_BANDITS_ID INTEGER[];
	ID_BLOCK_RESP INTEGER;
	ID_B INTEGER;
	SIZE INTEGER;
BEGIN
	IF (OLD.Defence_id = NEW.Defence_id)
	THEN
		SELECT array_agg(id) INTO DEF_BANDITS_ID FROM get_block_bandits_id(NEW.Defence_id) AS id;
		SELECT AreaUnit_id INTO ID_BLOCK_RESP FROM Block WHERE Block.Gang_id = (SELECT Gang_id FROM Block WHERE AreaUnit_id = NEW.Defence_id) AND isRespawn = true;
	
		PERFORM knock_down(DEF_BANDITS_ID);
	
		SELECT ARRAY_LENGTH(DEF_BANDITS_ID,1) INTO SIZE;
		IF (SIZE>0)
		THEN
			FOREACH ID_B IN ARRAY DEF_BANDITS_ID
			LOOP
				UPDATE Accommodation SET checkOutTime = NOW() WHERE Bandit_id = ID_B and checkOutTime is null ;
				insert into Accommodation values (NEXTVAL('Accommodation_id_seq'), ID_BLOCK_RESP  ,ID_B, NOW(),null);
			END LOOP;
		END IF;
	END IF;	
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION respawn_heal() RETURNS trigger AS $TRIGGER$
DECLARE
	BLOCK_ID INTEGER;
	IS_RESPA BOOLEAN;

BEGIN
	SELECT isRespawn INTO IS_RESPA FROM Block WHERE AreaUnit_id = NEW.Block_AreaUnit_id;
	IF (IS_RESPA and is_knock_down(NEW.Bandit_id))
	THEN
		PERFORM heal_bandit(NEW.Bandit_id);
	END IF;
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION add_to_inventory() RETURNS trigger AS $TRIGGER$
DECLARE
	ID_BLOCK_RESP INTEGER;
	ID_WORKER INTEGER;
BEGIN
	
	SELECT Bandit_id INTO ID_WORKER FROM Work WHERE id = NEW.Work_id;
	IF (ID_WORKER IS NOT NULL)
	THEN
	insert into Inventory values(ID_WORKER, NEW.id);
	END IF;
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_data() RETURNS trigger AS $TRIGGER$
DECLARE
	TIME_1 TIME;
	TIME_2 TIME;

BEGIN
	SELECT time INTO TIME_1 FROM Capture WHERE id = NEW.Capture_id;
	TIME_2:=NEW.time;

	IF (TIME_1 < TIME_2)
	THEN
		RAISE EXCEPTION 'Захват не может произойти до попытки';
	END IF;
		
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION work_time() RETURNS trigger AS $TRIGGER$
DECLARE
	BLOCK_ID INTEGER;
	IS_RESPA BOOLEAN;

BEGIN
	IF (NEW.interactionTime is null)
	THEN
		NEW.interactionTime:= '0000-00-00 00:00:00';
	END IF;
	RETURN NEW;	
END;
$TRIGGER$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS capturead ON CaptureTry;

DROP TRIGGER IF EXISTS respawn_heal ON Accommodation;

DROP TRIGGER IF EXISTS add_to_inventory ON Work;

DROP TRIGGER IF EXISTS check_data ON CaptureTry;

DROP TRIGGER IF EXISTS work_time ON Work;

CREATE TRIGGER capturead AFTER UPDATE ON CaptureTry
    FOR EACH ROW EXECUTE PROCEDURE capturead_results();

CREATE TRIGGER respawn_heal AFTER INSERT ON Accommodation
    FOR EACH ROW EXECUTE PROCEDURE respawn_heal();

CREATE TRIGGER add_to_inventory AFTER INSERT ON Item
    FOR EACH ROW EXECUTE PROCEDURE add_to_inventory();

CREATE TRIGGER work_time BEFORE INSERT OR UPDATE ON Work
    FOR EACH ROW EXECUTE PROCEDURE work_time();

CREATE TRIGGER check_data BEFORE INSERT OR UPDATE ON CaptureTry
    FOR EACH ROW EXECUTE PROCEDURE check_data();


