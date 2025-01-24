FROM rocker/geospatial:4.4.1

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y git wget curl

RUN mkdir -p /home/kapivara

RUN git clone --single-branch --branch dev https://github.com/EiA2030/kapi-eia /home/kapivara/kapi && \
    git clone https://github.com/EiA2030/eia-carob /home/kapivara/kapi/eia-carob

WORKDIR /home/kapivara/kapi

COPY carob-eia /home/kapivara/carob-eia

RUN Rscript app/compile.R

WORKDIR /home/kapivara/kapi/app

EXPOSE 8567

ENTRYPOINT ["Rscript", "app.R"]
