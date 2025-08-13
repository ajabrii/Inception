NAME = inception
COMPOSE = docker compose
COMPOSE_FILE = src/docker-compose.yml

# 🟢 Run project (default)
all: up

up:
	@$(COMPOSE) -f $(COMPOSE_FILE) up --build -d
	@echo "\n🚀 Inception Project is running!"
	@echo "📋 Available Services:"
	@echo "┌─────────────────────────────────────────────────────────┐"
	@echo "│ 🌐 WordPress       │ https://localhost                 │"
	@echo "│ 🗄️  Adminer        │ http://localhost:8081             │"
	@echo "│ 🐳 Portainer       │ http://localhost:9999             │"
	@echo "│ 🌍 Static Website  │ http://localhost:8080             │"
	@echo "│ 📊 Redis           │ redis://localhost:6379            │"
	@echo "│ 📁 FTP Server      │ ftp://localhost:21                │"
	@echo "└─────────────────────────────────────────────────────────┘"
	@echo "✅ All services are ready to use!"


# 🔴 Stop and remove containers
down:
	@$(COMPOSE) -f $(COMPOSE_FILE) down

# 🧹 Clean everything: containers, volumes, images
fclean:
	@$(COMPOSE) -f $(COMPOSE_FILE) down -v --rmi all --remove-orphans

# 🔁 Full rebuild
re: fclean
	@$(MAKE) up
