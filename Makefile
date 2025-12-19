BUNDLE_FLAGS = --build-arg BUNDLE_INSTALL_CMD='bundle install --jobs 20 --retry 5'

ifdef DEPLOYMENT
	BUNDLE_FLAGS = --build-arg BUNDLE_INSTALL_CMD='bundle install --without test'
endif

DOCKER_COMPOSE = docker compose -f docker-compose.yml

DOCKER_BUILD_CMD = $(DOCKER_COMPOSE) build $(BUNDLE_FLAGS)

build: stop
	$(DOCKER_BUILD_CMD)

prebuild:
	$(DOCKER_BUILD_CMD)
	$(DOCKER_COMPOSE) up --no-start

serve:
	$(MAKE) build
	$(DOCKER_COMPOSE) up -d

servelocal:
	$(MAKE) build
	docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

stoplocal:
	docker compose -f docker-compose.yml -f docker-compose.local.yml kill
	docker compose -f docker-compose.yml -f docker-compose.local.yml rm -f

lint:
	$(MAKE) build
	$(DOCKER_COMPOSE) run --no-deps --rm app bundle exec rubocop

test:
	$(MAKE) serve
	$(DOCKER_COMPOSE) run --rm app bundle exec rspec
	$(MAKE) stop

shell: serve
	$(DOCKER_COMPOSE) run --rm app ash

stop:
	$(DOCKER_COMPOSE) kill
	$(DOCKER_COMPOSE) rm -f

update: stop
	bundle lock --update
	$(MAKE) build
	$(MAKE) test

.PHONY: test serve stop lint servelocal stoplocal
