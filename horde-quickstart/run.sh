#!/bin/bash

if [ ! -f .env ]; then
  echo ".env file not found. Please create it with the necessary environment variables (copy .env.sample)."
  exit 1
fi

source .env

if [ ! -d data ]; then
  mkdir data
fi

if [ ! -f data/globals.json ]; then
  cp config/$HORDE_VERSION/globals.json data/globals.json
fi

if [ ! -f data/server.json ]; then
  cp config/$HORDE_VERSION/server.json data/server.json
fi

if [ ! -f data/cert.pfx ]; then
  if [ -f cert.pfx ]; then
    cp cert.pfx data/cert.pfx
  else
    echo "Could not find ./data/cert.pfx or ./cert.pfx. Please add your SSL certificate."
    exit 1
  fi
fi

# "Password": "your_password" in server.json should match CERT_PASSWORD in .env
sed -i "s/\"Password\": \".*\"/\"Password\": \"$CERT_PASSWORD\"/" data/server.json

docker pull ghcr.io/epicgames/horde-server:$HORDE_VERSION
docker compose pull
docker compose up -d