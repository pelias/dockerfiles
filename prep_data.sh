#!/bin/bash

# deprecation notice
2>&1 echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
2>&1 echo 'This repository has been deprecated in favour of https://github.com/pelias/docker';
2>&1 echo;
2>&1 echo 'We strongly recommended you to migrate any code referencing this repository';
2>&1 echo 'to use https://github.com/pelias/docker as soon as possible.'
2>&1 echo;
2>&1 echo 'You can find more information about why we deprecated this code along with a migration guide in the wiki:';
2>&1 echo 'https://github.com/pelias/dockerfiles/wiki/Deprecation-Notice';
2>&1 echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

# load DATA_DIR and other vars from docker-compose .env file
export $(cat .env | xargs)

# start elasticsearch if it's not already running
if ! [ $(curl --output /dev/null --silent --head --fail http://localhost:9200) ]; then
    docker-compose up -d elasticsearch

    # wait for elasticsearch to start up
    echo 'waiting for elasticsearch service to come up'
    until $(curl --output /dev/null --silent --head --fail http://localhost:9200); do
      printf '.'
      sleep 2
    done
fi

# create the index in elasticsearch before importing data
docker-compose run --rm schema npm run create_index

# download all the data to be used by imports
docker-compose run --rm whosonfirst npm run download &
docker-compose run --rm openaddresses npm run download &
docker-compose run --rm openstreetmap npm run download &
docker-compose run --rm interpolation npm run download-tiger &

wait

# polylines data prep requires openstreetmap data, so wait until that's done to start this
# but then wait to run the polylines importer process until this is finished
#docker-compose run --rm valhalla bash ./docker_build.sh
docker-compose run --rm polylines bash ./docker_extract.sh

docker-compose run --rm placeholder npm run extract
docker-compose run --rm placeholder npm run build

docker-compose run --rm interpolation bash ./docker_build.sh &
docker-compose run --rm whosonfirst npm start
docker-compose run --rm openaddresses npm start
docker-compose run --rm openstreetmap npm start
docker-compose run --rm polylines npm start

wait
