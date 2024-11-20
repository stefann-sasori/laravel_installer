#!/bin/bash

# Utilisation du script
if [ $# -lt 2 ]; then
    echo "Usage: $0 <project_name> <destination_directory>"
    exit 1
fi

PROJECT_NAME=$1
DEST_DIR=$2

# Création du projet Laravel
echo "Création du projet Laravel $PROJECT_NAME dans $DEST_DIR..."
composer create-project --prefer-dist laravel/laravel "$DEST_DIR/$PROJECT_NAME"

# Navigation vers le répertoire du projet
cd "$DEST_DIR/$PROJECT_NAME"

# Initialisation de Git pour le projet
echo "Initialisation de Git pour le projet..."
git init
git add .
git commit -m "Initial commit"

# Installation de Laravel Sail
echo "Installation de Laravel Sail..."
composer require laravel/sail --dev

# Installation de Jetstream avec Inertia
echo "Installation de Jetstream avec Inertia..."
composer require laravel/jetstream
php artisan jetstream:install inertia

# Configuration de PostgreSQL dans le .env
echo "Configuration de PostgreSQL dans le .env..."
sed -i 's/DB_CONNECTION=mysql/DB_CONNECTION=pgsql/' .env
sed -i 's/DB_HOST=127.0.0.1/DB_HOST=pgsql/' .env
sed -i 's/DB_PORT=3306/DB_PORT=5432/' .env
sed -i 's/DB_DATABASE=laravel/DB_DATABASE='"$PROJECT_NAME"'/' .env
sed -i 's/DB_USERNAME=root/DB_USERNAME='"$PROJECT_NAME"'/' .env
sed -i 's/DB_PASSWORD=/DB_PASSWORD='"$PROJECT_NAME"'/' .env

# Ajout de PostgreSQL et Redis dans docker-compose.yml
echo "Ajout de PostgreSQL et Redis dans docker-compose.yml..."
cat << EOF > docker-compose.yml
services:
  laravel.test:
    build:
      context: ./vendor/laravel/sail/runtimes/8.2
      dockerfile: Dockerfile
      args:
        WWWGROUP: '${WWWGROUP:-1000}'
    image: sail-8.2/app
    ports:
      - '${APP_PORT:-8000}:80'
    environment:
      WWWUSER: '${WWWUSER:-1000}'
      LARAVEL_SAIL: 1
      XDEBUG_MODE: '${SAIL_XDEBUG_MODE:-off}'
      XDEBUG_CONFIG: '${SAIL_XDEBUG_CONFIG:-client_host=host.docker.internal}'
    volumes:
      - '.:/var/www/html'
    networks:
      - sail
    depends_on:
      - pgsql
      - redis

  pgsql:
    image: postgres:13
    ports:
      - '5432:5432'
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgsql_data:/var/lib/postgresql/data
    networks:
      - sail

  redis:
    image: redis:alpine
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    networks:
      - sail

volumes:
  pgsql_data:
  redis_data:

networks:
  sail:
    driver: bridge
EOF

# Installation des dépendances Node.js/NPM pour Inertia
echo "Installation des dépendances NPM..."
npm install

# Génération de la clé d'application
echo "Génération de la clé d'application..."
php artisan key:generate

# Exécution des migrations
echo "Exécution des migrations..."
php artisan migrate

# Construction des images Docker et lancement des conteneurs
echo "Construction des images Docker et démarrage des services..."
./vendor/bin/sail build --no-cache
./vendor/bin/sail up -d

echo "Le projet $PROJECT_NAME a été configuré et est accessible à http://localhost:8000"