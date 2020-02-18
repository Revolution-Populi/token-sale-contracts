.SILENT:
.PHONY: tests build

.DEFAULT_GOAL := help

APP_ENV = dev
#-include .env
#ifneq ("$(wildcard .env.$(APP_ENV))", "")
#-include .env.$(APP_ENV)
#endif
#ifneq ("$(wildcard .env.local)", "")
#-include .env.local
#endif
export

ifeq ($(APP_ENV),prod)
CONFIG = docker-compose-prod.yml
else
CONFIG = docker-compose.yml
endif

COMPOSE_CMD = docker-compose -f$(CONFIG)

##Docker
build: ## Build images (and ensure they are up to date)
	@echo 'Pull & build required images for [$(APP_ENV)] mode'
	$(COMPOSE_CMD) build

start: ## Start containers
	@echo 'Starting containers in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) up -d

stop: ## Stop containers & remove docker networks
	@echo 'Stoping containers in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) down

restart: ## Restarts containers
	@echo 'Restarting containers in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) down
	$(COMPOSE_CMD) up -d

list: ## List current running containers services
	@echo 'List containers in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) ps

clean-container: ## Remove stopped containers
	@echo 'Remove stopped containers'
	$(COMPOSE_CMD) rm --force

cconsole: ## Start new bash terminal inside the arbitrary Container (arg CONTAINER)
	@echo 'Console to $(CONTAINER) container in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) exec $(CONTAINER) bash

rebuild: ## Rebuilds the arbitrary container (arg CONTAINER)
	@echo 'Rebuilding $(CONTAINER)...'
	$(COMPOSE_CMD) up -d --no-deps --build $(CONTAINER)

##
##Logs
logs: ## Display current running containers logs (Press "Ctrl + c" to exit)
	@echo 'Log containers in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) logs -f

##
##NPM
npm-init: ## Executes truffle command
	@echo 'Initializes NPM in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) exec truffle npm install

##
##Truffle
truffle: ## Executes truffle command
	@echo 'Execute truffle command "$(COMMAND)" in [$(APP_ENV)] mode'
	$(COMPOSE_CMD) exec truffle "./node_modules/truffle/build/cli.bundled.js" $(COMMAND)

flatten: ## Flattens smart contracts into single file
	@echo 'Flattening all contracts to a single file...'
	$(COMPOSE_CMD) exec truffle bash -c "cd /var/solidity-flattener && npm start /var/www/contracts/REVSale.sol "

##
##Help
help: ## Display available make tasks
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
