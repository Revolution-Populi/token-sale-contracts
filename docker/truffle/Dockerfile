FROM ubuntu:latest

WORKDIR /var/www

RUN apt-get update
RUN apt-get install --assume-yes curl software-properties-common apt-utils
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get install --assume-yes nodejs
RUN add-apt-repository -y ppa:ethereum/ethereum && apt-get update && apt-get install --assume-yes solc
RUN apt-get install --assume-yes git make build-essential
