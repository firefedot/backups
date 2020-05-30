#!/bin/bash

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

sudo apt install update -y
sudo apt install postgresql-9.6 postgresql-contrib-9.6 openjdk-8-jdk-headless

# create user db root root

echo "create role root login superuser password 'root';" | sudo -u postgres psql