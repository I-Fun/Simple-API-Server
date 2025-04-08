#!/bin/bash

# ==== Helper ====
generate_random() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# ==== Interactive Inputs ====
read -p "Postgres username [default: random]: " PGUSER
read -p "Postgres password [default: random]: " PGPASSWORD
read -p "Postgres database [default: random]: " PGDATABASE
read -p "API username [default: random]: " API_USER
read -p "API password [default: random]: " API_PASS
read -p "API exposed port [default: 3000]: " API_PORT

PGUSER=${PGUSER:-$(generate_random)}
PGPASSWORD=${PGPASSWORD:-$(generate_random)}
PGDATABASE=${PGDATABASE:-$(generate_random)}
API_USER=${API_USER:-$(generate_random)}
API_PASS=${API_PASS:-$(generate_random)}
API_PORT=${API_PORT:-3000}

# ==== Directory Setup ====
mkdir -p project/api

# ==== .env ====
cat <<EOF > api/.env
PGHOST=postgres
PGUSER=$PGUSER
PGPASSWORD=$PGPASSWORD
PGDATABASE=$PGDATABASE
PGPORT=5432
API_USER=$API_USER
API_PASS=$API_PASS
PORT=3000
EOF

# ==== Dockerfile ====
cat <<'EOF' > api/Dockerfile
FROM node:18

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
COPY .env .env

EXPOSE 3000
CMD ["node", "index.js"]
EOF

# ==== package.json ====
cat <<'EOF' > api/package.json
{
  "name": "api-server",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "basic-auth": "^2.0.1",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "pg": "^8.11.1"
  }
}
EOF

# ==== index.js ====
cat <<'EOF' > api/index.js
require('dotenv').config();
const express = require('express');
const basicAuth = require('basic-auth');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());

const pool = new Pool();

function auth(req, res, next) {
  const user = basicAuth(req);
  if (
    user &&
    user.name === process.env.API_USER &&
    user.pass === process.env.API_PASS
  ) {
    next();
  } else {
    res.set('WWW-Authenticate', 'Basic realm="Access API"');
    res.status(401).send('Authentication required.');
  }
}

app.get('/data', auth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM your_table');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
});
EOF

# ==== docker-compose.yml ====
cat <<EOF > project/docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16
    container_name: pg-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: $PGUSER
      POSTGRES_PASSWORD: $PGPASSWORD
      POSTGRES_DB: $PGDATABASE
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  pgadmin:
    image: dpage/pgadmin4
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin123
    ports:
      - "8080:80"
    depends_on:
      - postgres

  api:
    build: ./api
    container_name: api-server
    restart: unless-stopped
    ports:
      - "$API_PORT:3000"
    depends_on:
      - postgres

volumes:
  pgdata:
EOF

# ==== Final Output ====
echo
echo "✅ Project structure created in ./project/"
echo "🚀 Ready to run: cd project && docker-compose up -d"
echo
echo "🟢 Generated Credentials:"
echo "--------------------------------------"
echo "PostgreSQL Username: $PGUSER"
echo "PostgreSQL Password: $PGPASSWORD"
echo "PostgreSQL Database: $PGDATABASE"
echo "API Username:        $API_USER"
echo "API Password:        $API_PASS"
echo "API Exposed Port:    $API_PORT"
echo "--------------------------------------"
echo "⚠️  Please copy and store these credentials before continuing!"
echo
