# Inception

A containerized WordPress stack built from scratch with Docker (no pre-made images) showcasing multi-service orchestration, isolation, persistence, and bonus tooling.

## 1. Objectives

- Build and run an isolated WordPress platform over HTTPS backed by MariaDB
- Use only Dockerfiles (no docker hub pre-built full images for services beyond base OS)
- Manage data persistence via named volumes
- Orchestrate services with `docker compose`
- Extend with bonus services: Adminer, Redis, FTP, Portainer, Static Website

## 2. Stack Overview

Mandatory:

- Nginx (TLS termination, reverse proxy)
- WordPress (PHP-FPM) + wp-cli bootstrap script
- MariaDB (database)

Bonus:

- Adminer (DB management UI)
- Redis (object cache)
- FTP (file transfer to WordPress volume)
- Portainer (container management UI)
- Static Website (separate site served by Nginx minimal)

## 3. High-Level Architecture

```
                ┌──────────────┐        (admin UI)  ┌──────────────┐
Browser  https  │    Nginx     │  fastcgi_pass:9000 │  WordPress   │
──────────────▶ │ :443 / :80   │ ─────────────────▶ │  PHP-FPM     │
                │              │                    │  + wp-cli    │
                └─────┬────────┘                    └──────┬───────┘
                      │ SQL                                   │ Redis (cache API)
                      ▼                                       │
                 ┌───────────┐     volumes       ┌────────────┘
                 │  MariaDB  │ ◀────────────────▶│  Redis      │
                 └───────────┘                   └────────────┐
                      ▲    adminer over HTTP :8081            │
                      │  ┌──────────────────────────────┐     │
                      │  │          Adminer             │◀────┘
                      │  └──────────────────────────────┘
                      │
       FTP :21/:21100-21110 (uploads/themes/plugins)
                      ▲
                 ┌──────────┐
                 │   FTP    │
                 └──────────┘

Portainer :9999  (manages all containers)        Static Site :8080 (independent)
```

## 4. Data Flow (Typical Page Request)

1. User hits `https://DOMAIN_NAME/`
2. Nginx terminates TLS, routes PHP requests to WordPress (PHP-FPM socket/port)
3. WordPress loads PHP code, queries MariaDB (cached objects first via Redis)
4. Optional: Redis returns cached objects; else DB queried and result cached
5. Response sent back through Nginx

## 5. Volumes & Persistence

| Volume           | Path (Container)     | Purpose                         |
| ---------------- | -------------------- | ------------------------------- |
| `wp_data`        | `/var/www/wordpress` | WordPress code, uploads, themes |
| `db_data`        | `/var/lib/mysql`     | MariaDB data directory          |
| `portainer_data` | `/data`              | Portainer state                 |

All survive `docker compose down` (unless `-v` or `make fclean`).

## 6. Networking

- Single user-defined bridge network `inception_net` ensures predictable DNS: service names resolve to containers.
- Internal references: `mariadb:3306`, `redis:6379`, `wordpress` etc.
- External published ports map host → container (e.g. `443:443`, `8081:8080`).

### Docker Network Concepts

- Bridge network isolates containers from host except published ports.
- Embedded DNS lets containers use service names instead of IPs.
- Only exposed/published ports accessible externally.

## 7. Service Roles & Interactions

| Service             | Key Ports          | Depends          | Role                                  |
| ------------------- | ------------------ | ---------------- | ------------------------------------- |
| Nginx               | 443                | WordPress        | HTTPS reverse proxy & static delivery |
| WordPress (PHP-FPM) | 9000 (internal)    | MariaDB          | CMS processing                        |
| MariaDB             | 3306 (internal)    | none             | Persistent relational storage         |
| Adminer             | 8081               | MariaDB          | Web DB admin UI                       |
| Redis               | 6379               | WordPress        | In-memory cache (object/session)      |
| FTP                 | 21 + passive range | WordPress volume | File transfer for wp-content          |
| Portainer           | 9999               | Docker socket    | Container management UI               |
| Static Website      | 8080               | none             | Separate static content site          |

## 8. Build & Run

Make targets wrap compose:

```
make up        # build + start all
make down      # stop & remove containers
make fclean    # full cleanup (containers + images + volumes)
make rebuild   # fclean then up
```

Direct commands:

```
docker compose -f src/docker-compose.yml up -d --build
docker compose ps
docker compose logs -f wordpress
```

## 9. Environment Variables (`src/.env`)

```
MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD
DOMAIN_NAME, WP_TITLE
WP_ADMIN_NAME, WP_ADMIN_PASSWORD, WP_ADMIN_MAIL
WP_USER_NAME, WP_USER_PASSWORD, WP_USER_MAIL
FTP_USR, FTP_PWD
```

Used by init scripts (`wpconfig.sh`, DB init, FTP setup).

## 10. WordPress Bootstrap (`wpconfig.sh`)

Steps:

1. Wait for MariaDB readiness loop
2. Generate `wp-config.php`
3. Install core via wp-cli
4. Create secondary author user
5. Disable admin toolbar (global + user meta + mu-plugin)
6. Start PHP-FPM in foreground

## 11. Security / Hardening Highlights

- Separate service containers (least privilege)
- Non-root execution where applicable
- TLS termination at Nginx (self-signed in this setup)
- Restricted internal ports (DB/Redis not published)
- Explicit user meta tweaks (toolbar disable reduces accidental leak of admin state on frontend)

## 12. Redis Usage

WordPress (with object caching logic) can store transient/query results:

```
SET wp_post_42 "{...json...}" EX 3600
GET wp_post_42
```

Benefits: lower DB load, faster dynamic pages.

## 13. Adminer Usage

Access: `http://localhost:8081` (System: MySQL, Server: `mariadb`, user/pass from `.env`).
Typical queries:

```
SELECT post_title FROM wp_posts WHERE post_status='publish';
```

Export / import, inspect schema, reset passwords.

## 14. FTP Usage

Connect (passive mode):

```
Host: localhost
Port: 21
User: $FTP_USR
Pass: $FTP_PWD
Passive Ports: 21100-21110
```

Upload themes/plugins into `wp-content/` (same shared `wp_data` volume consumed by WordPress + FTP).

## 15. Portainer

Access: `http://localhost:9999`

- First-time: create admin account
- Manage containers, images, networks, volumes visually

## 16. Static Website

A lightweight Nginx container serving `/var/www/html` on `:8080`—useful for showcasing separation between dynamic (WordPress) and static site delivery.

## 17. Diagrams

### Container Topology

```
               +---------------------+
               |      Portainer      | (9999)
               +----------+----------+
                          | docker.sock
+---------+    +----------v----------+     +-----------+
| Browser |-->  |       Nginx        | --> | Static    |
| (TLS)   |     | 443       (fastcgi)|     | Website   |
+----+----+     +----+---------------+     +-----------+
     |               | PHP-FPM 9000
     |               v
     |         +-----------+      +-----------+
     |         | WordPress |<---->|   Redis   |
     |         +-----+-----+      +-----------+
     |               |
     |         SQL   v
     |         +-----------+
     |         |  MariaDB  |
     |         +-----------+
     |               ^
     |      Adminer (8081)
     |               |
     |             FTP (21 / passive range)
```

### Volume Mapping

```
wp_data:  WordPress <-> FTP <-> Nginx (read)   (themes/uploads)
db_data:  MariaDB data files
portainer_data: Portainer state
```

## 18. Common Docker / Compose Commands

| Task            | Command                               |
| --------------- | ------------------------------------- |
| List containers | `docker ps`                           |
| Stop one        | `docker stop <name>`                  |
| Remove one      | `docker rm <name>`                    |
| Show logs       | `docker logs -f wordpress`            |
| Exec shell      | `docker exec -it wordpress /bin/bash` |
| Prune unused    | `docker system prune -f`              |

Compose specifics:

```
docker compose up -d          # start
docker compose down           # stop
docker compose build <svc>    # rebuild one
docker compose logs -f nginx  # tail logs
```

### Docker Concepts Quick Reference

- Image: Immutable filesystem + metadata template
- Container: Runtime instance of an image
- Layer: Union FS piece (cached across builds)
- Volume: Persistent data mount managed by Docker
- Network (bridge): Virtual switch; service-name DNS
- Compose: Declarative multi-service orchestration (build, run, dependency graph)

## 19. Updating / Maintenance

- WordPress plugins: via admin UI (works: wp-content writable)
- Core updates: Permissions + `wp-content/upgrade` directory ensured; fallback is rebuild with updated tarball
- Redis purge: `docker exec -it redis redis-cli FLUSHALL`
- DB backup: `docker exec -it mariadb mariadb-dump -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > backup.sql`

## 20. Troubleshooting

| Symptom                     | Check                                                  |
| --------------------------- | ------------------------------------------------------ |
| 502 from Nginx              | Nginx error log; WordPress PHP-FPM running?            |
| WordPress cannot connect DB | MariaDB container up? creds in `.env`?                 |
| Adminer login fails         | Use `MYSQL_USER` / `MYSQL_PASSWORD` / host `mariadb`   |
| Redis unused                | Ensure object cache drop-in present / plugin installed |
| FTP list fails              | Passive port range open & mapped?                      |
| Portainer blank             | Browser cache / first-run init still pending           |

## 21. Cleanup Strategy

```
make down        # keep volumes
make fclean      # remove everything (images + volumes)
```

## 22. Extensibility Ideas

- Add Prometheus + Grafana for metrics
- Add Fail2Ban / ModSecurity in front of Nginx
- Implement automatic SSL via ACME (staging)
- Add mail service (Postfix + mailhog)

## 23. License & Attribution

Educational project (42 Inception). All trademarks belong to their respective owners.

---

Happy containerizing.
