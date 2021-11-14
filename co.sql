create type типХарактеристики as enum('HEAL','PROTECT','DAMAGE');
create type color as enum('GREEN','RED','YELLOW','PURPLE');


create table "Банда" (
	"id" serial primary key ,
	"название" varchar(45) not null unique,
	"цвет" color not null unique	
);

create table "Бандит" (
	"id" serial primary key,
	"имя" varchar(45) not null,
	"фамилия" varchar(45),		
	"возраст" integer,
	"Банда_id" serial not null references "Банда"("id"),
	"безСознания" time not null
);

create table "ТипПредмета" (
	"id" serial primary key,
	"типХарактеристики" типХарактеристики not null,
	"класс" varchar(75)
);


create table "ЕдиницаТерритории"(
	"id" serial primary key,
	"x" integer not null check ("x" < 64),
	"y" integer not null check ("y" < 64)

);

create table "Блок"(
	"ЕдиницаТерритории_id" serial references "ЕдиницаТерритории"("id"),
	"вместительность" integer not null,
	"респа" boolean not null,
	"Банда_id" integer references "Банда"("id"),
	primary key(ЕдиницаТерритории_id)
);

create table "Проживание"(
	"id" serial primary key,
	"Блок_ЕдиницаТерритории_id" serial not null references "Блок"("ЕдиницаТерритории_id"),
	"Бандит_id" serial not null references "Бандит"("id"),
	"времяЗаселения" timestamp not null,
	"времяВыселения" timestamp check("времяЗаселения" < "времяВыселения")

);

create table "Мастерская"(
	"Блок_ЕдиницаТерритории_id" serial references "Блок"("ЕдиницаТерритории_id"),
	"название" varchar(100) not null,
	primary key(Блок_ЕдиницаТерритории_id)

);

create table "Работа"(
	"id" serial primary key,
	"Бандит_id" serial not null references "Бандит"("id"),
	"Мастерская_Блок_ЕдиницаТерритории_id" serial not null references "Мастерская"("Блок_ЕдиницаТерритории_id"),
	"времяВзаимодействия" timestamp not null 
);


create table "Предмет" (
	"id" serial primary key,
	"название" varchar(45) not null,
	"характеристика" int not null check("характеристика" <= 10 and "характеристика" >=1),
	"ТипПредмета_id" serial not null references "ТипПредмета"("id"),
	"Работа_id" integer references "Работа"("id")
);

create table "Инвентарь"(
	"Бандит_id" serial not null references "Бандит"("id"),
	"Предмет_id" serial not null references "Предмет"("id")
);

create table "Захват"(
	"id" serial primary key,
	"время" timestamp not null
);

create table "Попытка" (
	"id" serial primary key,
	"Атака_id" serial not null references "Блок"("ЕдиницаТерритории_id"),
	"Защита_id" serial not null references "Блок"("ЕдиницаТерритории_id"),
	"Инициатор_id" serial not null references "Бандит"("id"),
	"Захват_id" integer references "Захват"("id"),
	"время" timestamp not null
);