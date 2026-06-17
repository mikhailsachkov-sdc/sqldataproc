drop table if exists Followers;
drop table if exists Comments;
drop table if exists Likes;
drop table if exists Photos;
drop table if exists Users;

create table Users(
	user_id serial primary key,
	user_name text not null unique);
	
create table Photos(
	photo_id serial primary key,
	photo_file text not null,
	user_id int not null,
	foreign key (user_id) references Users(user_id));

create table Likes(
	like_id serial primary key,
	photo_id int not null,
	user_id int not null,
	dt date not null,
	foreign key (photo_id) references Photos(photo_id),
	foreign key (user_id) references Users(user_id));

create table Comments(
	comment_id serial primary key,
	photo_id int not null,
	user_id int not null,
	comment_text text not null,
	foreign key (photo_id) references Photos(photo_id),
	foreign key (user_id) references Users(user_id));

create table Followers(
	user_id int not null,
	follower_id int not null,
	primary key(user_id, follower_id),
	foreign key (user_id) references Users(user_id),
	foreign key (follower_id) references Users(user_id));

----------------------------------------------------------
insert into Users(user_name) values('Jonh'), ('Mary'), ('Adrian'), ('Claire'), ('Holly');

insert into Photos(photo_file, user_id) values
('file_name1', 1), ('file_name2', 4), ('file_name3', 2),
('file_name4', 1), ('file_name5', 3), ('file_name6', 4),
('file_name7', 4), ('file_name8', 2);

insert into Likes(photo_id, user_id, dt) values
(1, 2, '01/26/2024'), (1, 3, '03/13/2024'), (1, 5, '02/04/2024'),
(2, 1, '01/25/2024'), (3, 4, '01/25/2024'), (3, 5, '03/15/2024'),
(4, 5, '03/20/2024'), (6, 2, '02/10/2024'), (7, 1, '02/19/2024'),
(7, 2, '01/26/2024'), (7, 3, '01/12/2024'), (7, 5, '03/05/2024'),
(8, 4, '03/18/2024'), (8, 3, '02/11/2024');

insert into Comments(photo_id, user_id, comment_text) values
(2, 3, 'Good'), (3, 1, 'Excellent'), (3, 5, 'Not bad'), (8, 1, 'Ok'), (8, 2, 'Cool');

insert into Followers(user_id, follower_id) values
(1, 2), (1, 3), (1, 4), (2, 1), (2, 3), (3, 2), (3, 4), (4, 1), (3, 5);

