# Agent Instructions for `dotfiles-init`

This file contains project-specific context information and guidelines for AI agents (like Gemini, Claude) operating in this repository. Adherence to these guidelines has the highest priority.

## 1. Project Context & Goals
This repository serves the automated initial setup of macOS systems (dotfiles initialization).
The core component is the `init.sh` script, which bootstraps package managers, tools, and security components before the actual dotfiles are loaded via Chezmoi.

## 2. Tech Stack
- **Operating System:** macOS (Darwin only)
- **Scripting Language:** Bash
- **Package Managers:** Homebrew, MacPorts
- **Configuration Management:** Chezmoi
- **Secret Management & SSH:** Proton Pass CLI (incl. Daemon/SSH Agent)

## 3. Architecture & Design Principles
When working on `init.sh` or other scripts in this project, strictly follow these principles:
- **Idempotency:** Scripts must be safe to run multiple times without leaving the system in an inconsistent state. Before any installation or configuration, check if it is already present or active.
- **Robustness & Fault Tolerance:**
  - Always use `set -euo pipefail` in Bash scripts.
  - Handle potential errors gracefully and provide meaningful error messages to the user.
- **Security:** Never hardcode passwords, tokens, or private keys in the code. Exclusively use the provided secret management (Proton Pass) for sensitive data.
- **Cleanliness:** Temporary directories and files created (e.g., via `mktemp -d`) must be reliably cleaned up at the end of execution (e.g., via `trap cleanup EXIT`).

## 4. Workflow & Superpowers Integration
- The project uses the `superpowers` framework for task planning and execution (see `docs/superpowers/` directory).
- Before making changes, always check if there is an existing plan in `docs/superpowers/plans/` or specifications in `docs/superpowers/specs/`.
- Follow the instructions in the plans precisely and check off checklists (`- [x]`) as you complete subtasks.
- **Commits:** Use the "Conventional Commits" format (e.g., `feat: ...`, `fix: ...`, `refactor: ...`) and keep commit messages concise (refer to the `caveman-commit` skill if applicable).
- **Dependencies:** Only modify global system states (like modifying `.zshrc` or global paths) if explicitly requested or documented.
