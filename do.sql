DROP TRIGGER capturead ON Захват;

DROP TRIGGER respawn_heal ON Проживание;

DROP TRIGGER create_work_record ON Бандит; 

drop table "Инвентарь" cascade;

drop table "Предмет" cascade;

drop table "ТипПредмета" cascade;

drop table "Проживание" cascade;

drop table "Работа" cascade;

drop table "Мастерская" cascade;

drop table "Попытка" cascade;

drop table "Бандит" cascade;

drop table "Банда" cascade;

drop table "Блок" cascade;

drop table "ЕдиницаТерритории" cascade;

drop table "Захват" cascade;

drop FUNCTION run_over(destination integer, person integer);

drop FUNCTION get_time_in(person integer);

drop FUNCTION get_capacity(plase integer);

drop FUNCTION capture_block(defense_id integer, initiator integer);

drop FUNCTION is_respawn(block_id integer);

drop FUNCTION count_probability(attack_id integer, defense_id integer);

drop FUNCTION count_characteristic(place integer, characteristic типХарактеристики);

drop FUNCTION get_block_bandits_id(place integer);

drop FUNCTION get_block_bandits_number(place integer);

drop FUNCTION knock_down(anyarray);

drop FUNCTION knock_down(bandit_id integer);

drop FUNCTION is_knock_down(bandit_id integer);

drop FUNCTION what_is_blockid_bandit(bandit_id integer);

drop FUNCTION is_ally(this_block integer, that_block integer);

drop FUNCTION heal_bandit(bandit_id integer);

drop FUNCTION remove_heal_for_block(block_id integer);

drop FUNCTION remove_item_from_bandit(item_id integer, bandit_id integer);

drop FUNCTION is_near(attack_id integer, defense_id integer);

drop FUNCTION work(worker integer,  type_of_product integer, name varchar(45), characteristic integer);

drop type color;

drop type "типХарактеристики";