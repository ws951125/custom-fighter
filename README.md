# Custom Fighter

A cross-platform 2D action-fighting game and creator platform inspired by the feel of classic side-scrolling arena fighters, with original systems for player-created characters, data-driven skills, custom VFX, and future AI-assisted skill animation generation.

## Project direction

- **Engine:** Godot 4.7.2 stable
- **Language:** GDScript
- **Primary MVP targets:** Web + Windows
- **Future targets:** Android + iOS
- **Development model:** public, CI-first, cloud-tested
- **Creator direction:** PC/Web-first creator tools; runtime designed for cross-platform play

## Core differentiator

Players will eventually be able to create a character, configure skills without writing code, provide reference images for effects such as fireballs or sword formations, generate/import VFX, preview them, and use the resulting character package in the game.

## Current milestone

**Milestone 0 — Foundation**

The repository is being bootstrapped with a minimal Godot Web prototype, automated headless tests, Web export, browser smoke testing, and GitHub Pages deployment.

## Online-first validation policy

This project is designed so routine validation happens online. GitHub Actions must run automated project checks, headless tests, Web export, and browser smoke tests. Human testing should normally use the deployed Web build instead of requiring a local Godot installation.

See `AGENTS.md` and `docs/MVP.md` for the working rules and roadmap.
