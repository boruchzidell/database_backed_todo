create table lists (
  id serial primary key,
  name text unique not null
);

create table todos (
  id serial primary key,
  name text not null,
  list_id integer references lists(id) on delete cascade not null,
  completed boolean default false
);
