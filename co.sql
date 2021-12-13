create type characteristicType as enum('HEAL','PROTECT','DAMAGE');
create type color as enum('GREEN','RED','YELLOW','PURPLE');


create table Gang (
	id serial primary key ,
	name varchar(45) not null unique,
	color color not null unique	
);

create table Bandit (
	id serial primary key,
	name varchar(45) not null,
	lastname varchar(45),		
	age integer check(age>0),
	Gang_id serial not null references Gang(id),
	isKnockDown time not null
);

create table "user" (
	Bandit_id serial primary key references Bandit(id),
	username varchar(45) not null,
	password text not null,
	role varchar(45),
	refresh_token text not null,
	status varchar(45),
	lastAccessTime timestamp
);


create table ItemType (
	id serial primary key,
	characteristicType characteristicType not null,
	class varchar(75)
);


create table AreaUnit(
	id serial primary key,
	x integer not null check (x < 64),
	y integer not null check (y < 64)
);

create table Block(
	AreaUnit_id serial references AreaUnit(id),
	capacity integer not null,
	isRespawn boolean not null,
	Gang_id integer references Gang(id),
	primary key(AreaUnit_id)
);

create table Accommodation(
	id serial primary key,
	Block_AreaUnit_id serial not null references Block(AreaUnit_id),
	Bandit_id serial not null references Bandit(id),
	checkInTime timestamp not null,
	checkOutTime timestamp check(checkInTime < checkOutTime)

);

create table Workshop(
	Block_AreaUnit_id serial references Block(AreaUnit_id),
	name varchar(100) not null,
	primary key(Block_AreaUnit_id)

);

create table Work(
	id serial primary key,
	Bandit_id serial not null references Bandit(id),
	Workshop_Block_AreaUnit_id serial not null references Workshop(Block_AreaUnit_id),
	interactionTime timestamp not null 
);


create table Item (
	id serial primary key,
	name varchar(45) not null,
	characteristic int not null check(characteristic <= 10 and characteristic >=1),
	ItemType_id serial not null references ItemType(id),
	Work_id integer references Work(id)
);

create table Inventory(
	Bandit_id serial not null references Bandit(id),
	Item_id serial not null references Item(id)
);

create table Capture(
	id serial primary key,
	time timestamp not null
);

create table CaptureTry (
	id serial primary key,
	Attack_id serial not null references Block(AreaUnit_id),
	Defence_id serial not null references Block(AreaUnit_id),
	Bandit_id serial not null references Bandit(id),
	Capture_id integer references Capture(id),
	time timestamp not null
);