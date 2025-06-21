NAME = inception
COMPOSE = docker compose
COMPOSE_FILE = src/docker-compose.yml

# 🟢 Run project (default)
all: up

up:
	@$(COMPOSE) -f $(COMPOSE_FILE) up --build -d

# 🔴 Stop and remove containers
down:
	@$(COMPOSE) -f $(COMPOSE_FILE) down

# 🧹 Clean everything: containers, volumes, images
fclean:
	@$(COMPOSE) -f $(COMPOSE_FILE) down -v --rmi all --remove-orphans

# 🔁 Full rebuild
rebuild: fclean
	@$(MAKE) up
