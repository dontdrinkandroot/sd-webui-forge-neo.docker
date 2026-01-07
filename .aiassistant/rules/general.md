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
It uses version (tag) 2.x of forge-neo (configurable via `FORGE_VERSION` ARG).
The resulting image should be called `dontdrinkandroot/sd-webui-forge-neo:${FORGE_VERSION}-cuda`.
The dockerfile is cleanly documented so decisions taken and the reasoning behind it can be clearly understood.
We want to keep the image size minimal by using a multi-stage build.
All files to copy are stored under `files/`.

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

## Self-Update Instruction

This guidelines file is a living document and MUST be actively maintained by the LLM Agent.

* **Trigger:** Whenever significant changes are made to the tech stack, project structure, coding guidelines, or key features, the LLM Agent MUST immediately update this file (`.aiassistant/rules/general.md`) to reflect the current state of the project.
* **Content:** 
    * Add any information that could have helped the agent to solve the task more efficiently or in fewer steps.
    * Remove outdated, obsolete, or incorrect information.
    * Ensure all tech stack versions and library names are accurate.
* **Proactivity:** Do not wait for explicit instructions to update these guidelines if you identify a discrepancy between the guidelines and the actual codebase.
