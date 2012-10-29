drop table if exists relationship;
drop table if exists post;
drop table if exists photo;
drop table if exists role;
drop table if exists "user";

create table "user"
(
  id int not null primary key,
  name varchar(128) not null,
  email varchar(256)
);

create table post
(
  id int not null primary key,
  user_id int not null,
  status varchar(256) not null,
  posted_at datetime not null,
  latitude decimal(11, 7),
  longitude decimal(11,7),
  grouping foreign key (user_id) references "user"
);

create table role
(
  user_id int not null,
  role_name varchar(64) not null,
  primary key(user_id, role_name),
  grouping foreign key (user_id) references "user"
);

create table photo
(
  id int not null primary key,
  user_id int not null,
  state varchar(64) not null,
  date_added datetime,
  path varchar(256) not null,
  grouping foreign key (user_id) references "user"
);

create table relationship
(
  follower_id int not null,
  followed_id int not null,
  primary key(follower_id, followed_id),
  grouping foreign key (follower_id) references "user"
);
