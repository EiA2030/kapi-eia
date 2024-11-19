FROM rocker/geospatial:4.4.1

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y git wget curl

RUN mkdir -p /home/kapivara/ && git clone 

WORKDIR /home/kapivara/kapi

COPY testing/other/api/ ./app

COPY carob-eia /home/kapivara/carob-eia

RUN git clone https://github.com/EiA2030/eia-carob && \
    Rscript compile.R

EXPOSE 8567

HEALTHCHECK CMD curl --fail http://localhost:8567/_stcore/health || exit 1

ENTRYPOINT ["Rscript", "app/app.R"]

# sudo docker run -i --rm --name st -t egbendito:kapi /bin/bash
