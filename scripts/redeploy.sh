#!/bin/sh

cd ~/kapi-eia/
sudo docker compose down --remove-orphans
cd ~/eia-carob/
git pull
cd ~/kapi-eia/
sudo docker compose build --no-cache
sudo docker compose up -d

exit
