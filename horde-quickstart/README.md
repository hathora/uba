# Horde Quickstart

You can find the official Horde installation tutorial [in the UE docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/horde-installation-tutorial-for-unreal-engine).

This folder is meant to be used as a reference/quickstart to use Horde just as a UBA coordinator. You will need It's assumed you're running on native Linux (not in WSL).

## SSL Certificate

The various configurations in the [config](./config/) folder expect you have SSL/TLS enabled on the Horde server. Note, it is possible to use Cloudflare's SSL proxy feature with an unencrypted local server.

To generate a self-signed certificate:

1. Open PowerShell as an administrator on a Windows machine
1. Run: `./gen-cert.ps1`

## Cloudflare

If you're using Cloudflare for DNS, you can use the proxy feature, but make sure you enable the below settings:

1. In Cloudflare, make sure SSL/TLS is Full
1. In Cloudflare, under Network make sure gRPC is enabled
1. In Cloudflare, under Rules add Http->Https redirect

## GitHub Packages

You will need to [authenticate Docker](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry) with GitHub Package Container Registry to pull the Epic-provided image for Horde.

## Starting Horde

1. Copy `.env.sample` to `.env` and edit the details accordingly
1. Run `./run.sh` to setup and run Horde for the first time. You should use `docker compose <down|up>` commands for subsequent stops/starts
