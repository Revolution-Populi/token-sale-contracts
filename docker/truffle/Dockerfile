FROM ubuntu:latest

WORKDIR /var/www

RUN apt-get update
RUN apt-get install --assume-yes curl software-properties-common apt-utils
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get install --assume-yes nodejs
RUN add-apt-repository -y ppa:ethereum/ethereum && apt-get update && apt-get install --assume-yes solc
RUN apt-get install --assume-yes git make build-essential

WORKDIR /var
RUN git clone https://github.com/poanetwork/solidity-flattener && cd solidity-flattener && npm install
COPY flattener.json /var/solidity-flattener/config.json

WORKDIR /var/www
ENTRYPOINT ["node", "./node_modules/remixd/bin/remixd", "-s", "/var/www/contracts", "--remix-ide" ,"https://remix.ethereum.org"]
