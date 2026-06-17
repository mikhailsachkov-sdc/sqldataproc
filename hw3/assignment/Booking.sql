drop table if exists Booking_guest;
drop table if exists Booking;
drop table if exists Guest;
drop table if exists Room_facility;
drop table if exists Facility;
drop table if exists Hotel_room;
drop table if exists Hotel;

create table Hotel(
	hotel_id serial primary key,
	hotel_name text unique
);

create table Hotel_room(
	room_id serial primary key,
	hotel_id int not null,
	room_size int not null,
	room_capacity int, --how many people can accomodate in a room
	foreign key (hotel_id) references Hotel(hotel_id)	
);

create table Facility(
	facility_id serial primary key,
	name text not null unique); --wifi, friedg, airconditioner
	
create table Room_facility(
	room_facility_id serial primary key,
	room_id int not null,
	facility_id int not null,
	foreign key (room_id) references Hotel_room(room_id),
	foreign key (facility_id) references Facility(facility_id));

create table Guest(
	guest_id serial primary key,
	guest_name text not null unique,
	birthday date not null);

create table Booking(
	booking_id serial primary key,
	room_id int not null,
	guest_id int not null,
	start_date date not null,
	end_date date not null,	
	notes text,
	foreign key (room_id) references Hotel_room(room_id),
	foreign key (guest_id) references Guest(guest_id)
);

create table Booking_guest(
	booking_guest_id serial primary key,
	booking_id int not null,
	guest_id int not null,
	foreign key (booking_id) references Booking(booking_id),
	foreign key (guest_id) references Guest(guest_id)
);

---------------------------------------------------
insert into Hotel(hotel_name) values('Redisson'), ('Park Inn');

insert into Hotel_room(hotel_id, room_size, room_capacity)
values(1, 30, 1), (1, 50, 3), (1, 45, 2), (2, 70, 4), (2, 40, 1);

insert into Facility(name) values('TV'), ('WiFi'), ('Minibar');
	
insert into Room_facility(room_id, facility_id)
values(4, 1), (4, 2), (4, 3), (1, 2), (1, 1), (2, 1), (3, 3), (3, 2), (5, 1);

insert into Guest(guest_name, birthday)
values('Hamilton', '1980-01-01'), ('Gery', '2005-03-02'), ('Enrika', '1985-10-10'), ('Alisa', '2010-03-08'), ('Lucas', '2000-06-01');

insert into Booking(room_id, guest_id, start_date, end_date, notes)
values(1, 5, '2024-01-01', '2024-01-07', null), (4, 1, '2024-02-20', '2024-02-29', 'with a cat'), (3, 3, '2024-05-01', '2024-05-05', 'additional pillow');
	
insert into Booking_guest(booking_id, guest_id)
values(2, 2), (2, 4), (2, 3), (3, 5);