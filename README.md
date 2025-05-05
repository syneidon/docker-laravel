# Syneidon Laravel Docker Images

## Examples

### Simple container example

```bash
  # pull the image from docker hub for the desired Laravel version:
  docker pull syneidon/laravel:v10
  # or more specific PHP and NODE version:
  docker pull syneidon/laravel:v10-php8.2-node18
  # run the container:
  docker run -d --name laravel-10 syneidon/laravel:v10
  # install laravel 10 in the container:
  docker exec laravel-10 bash -c "composer create-project laravel/laravel:^10.0 . --quiet"
  docker exec laravel-10 cp .env.example .env
  docker exec laravel-10 php artisan key:generate
  # ... and it's done!
```

### Compose example with database and mount:

```yaml
services:
  laravel-app:
    image: syneidon/laravel:v10
    name: laravel-app
    volumes:
      - './src:/var/www/html'
    ports:
      - '80:80'
    depends_on:
      - laravel-db
    networks:
      - laravel-network
  laravel-db:
    image: mariadb:10.6
    container_name: laravel-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: laravel
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    volumes:
      - dbdata:/var/lib/mysql
    networks:
      - laravel-network
volumes:
  dbdata:
networks:
  laravel-network:
    driver: bridge
```

## Supported versions

| Laravel Version | PHP Versions           | Node Versions         |
|------------------|------------------------|------------------------|
| v6               | 7.3, 7.4, 8.0         | 14, 16, 18, 20         |
| v7               | 7.3, 7.4, 8.0         | 14, 16, 18, 20         |
| v8               | 7.3, 7.4, 8.0, 8.1    | 14, 16, 18, 20         |
| v9               | 8.0, 8.1, 8.2         | 14, 16, 18, 20         |
| v10              | 8.1, 8.2              | 14, 16, 18, 20         |
| v11              | 8.1, 8.2, 8.3         | 16, 18, 20             |
| v12              | 8.2, 8.3              | 18, 20                |
