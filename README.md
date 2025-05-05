# docker-laravel

example:

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

docker-compose example with database and project mount:

```yaml
services:
  laravel-app:
    image: syneidon/laravel:v10
    name: laravel-app
    volumes:
      - ./src:/var/www/html
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
```yaml
