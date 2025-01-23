FROM rocker/geospatial:4.4.1

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y git wget curl

RUN mkdir -p /home/kapivara

COPY kapi-eia /home/kapivara/kapi

RUN git clone https://github.com/EiA2030/eia-carob /home/kapivara/kapi/eia-carob

WORKDIR /home/kapivara/kapi

COPY carob-eia /home/kapivara/carob-eia

COPY secrets app/secrets

RUN Rscript app/compile.R

WORKDIR /home/kapivara/kapi/app

EXPOSE 8567

ENTRYPOINT ["Rscript", "app.R"]

