FROM rocker/geospatial:4.4.1

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y git wget curl

RUN mkdir -p /home/kapivara

RUN git clone --recurse-submodules https://github.com/egbendito/kapi-eia /home/kapivara/kapi

WORKDIR /home/kapivara/kapi

COPY carob-eia /home/kapivara/carob-eia

RUN Rscript app/compile.R

EXPOSE 8567

HEALTHCHECK CMD curl --fail http://localhost:8567/_stcore/health || exit 1

ENTRYPOINT ["Rscript", "app/app.R"]

