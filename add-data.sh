#!/bin/bash

##Install docker
set -o errexit
set -o nounset

IFS=$(printf '\n\t')

# Docker
sudo apt remove --yes docker docker-engine docker.io containerd runc
sudo apt update
sudo apt --yes --no-install-recommends install apt-transport-https ca-certificates
wget --quiet --output-document=- https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable"
sudo apt update
sudo apt --yes --no-install-recommends install docker-ce docker-ce-cli containerd.io
sudo usermod --append --groups docker "$USER"
sudo systemctl enable docker
printf '\nDocker installed successfully\n\n'

printf 'Waiting for Docker to start...\n\n'
sleep 5

# Docker Compose
sudo wget --output-document=/usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/$(wget --quiet --output-document=- https://api.github.com/repos/docker/compose/releases/latest | grep --perl-regexp --only-matching '"tag_name": "\K.*?(?=")')/run.sh"
sudo chmod +x /usr/local/bin/docker-compose
sudo wget --output-document=/etc/bash_completion.d/docker-compose "https://raw.githubusercontent.com/docker/compose/$(docker-compose version --short)/contrib/completion/bash/docker-compose"
printf '\nDocker Compose installed successfully\n\n'


## Start Containers

docker-compose -f t2-compose.yml up -d


## Add Data to Mysql
tail -n +2 $1 | while IFS=',' read -r worker data duration
do
printf -v Item '{ "worker_id": "'%s'", "date_1_start": "'%s'", "duration": "'%s'" }' "$worker" "$data" "$duration"
#curl -H "Content-Type:application/json" -X POST -d "$Item" $2
docker exec -t t2-api wget -O- --post-data="$Item" --header='Content-Type:application/json' http://127.0.0.1/api/dataset

done
printf '\nFinish\n\n'


