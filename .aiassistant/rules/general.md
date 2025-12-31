---
apply: always
---

Project Rules
=============

About
-----

This project provides a Docker image definition and the CI process for Stable Difussion WebUI Forge Neo.

Source Project
------------

The base project is located at https://github.com/Haoming02/sd-webui-forge-classic/tree/neo.
A copy of the project is available under `./sourceproject`.
Only the `neo` branch is the head of the neo variant.
Neo versions are prefixed with 2.x.
For short reference we call it forge-neo.

Dockerfile
----------

It supports recent nvidia cards via cuda (12.8).
It uses uv as a package manager while building.
It uses version (tag) 2.7 of forge-neo.
The resulting image should be called `dontdrinkandroot/sd-webui-forge-neo:2.7-cuda`.
The dockerfile is cleanly documented so decisions taken and the reasoning behind it can be clearly understood.
We want to keep the image size minimal by using a multi-stage build.

### Caddy

We use caddy as a proxy and to provide authentication.
The user can specify a Bearer token to use via the `AUTH_TOKEN` docker `ENV` var.
By default caddy uses an internal ssl certificate but is also accessible via normal http.

### Forge-Neo

It runs on port 7860.
It exposes the api via the `--api` argument.
It does not download a model by default.
We support sageattention.

### Supervisord

Both Caddy and Forge-Neo run as services at the same time via supervisord.
