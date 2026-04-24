# AI Sync Manager Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Windows PowerShell sync manager with Chinese double-click launchers for Codex and Claude Code Git-based state sync.

**Architecture:** The root project contains user-facing `.cmd` launchers and a menu script. Reusable PowerShell logic lives in `scripts/lib/`, and all direct action scripts call the shared operations layer so setup, pull, push, status, and rebind behave consistently.

**Tech Stack:** Windows PowerShell, Git CLI, JSON config files, CMD launchers.

---

## Chunk 1: Project Scaffolding And Configuration

### Task 1: Add Local Config Template And Ignore Local Config

**Files:**
- Create: `config.example.json`
- Modify: `.gitignore`

- [ ] **Step 1: Add `config.example.json`**

Create a config template with `backupRoot`, `backupRetention`, `codex`, and `claude` sections.

- [ ] **Step 2: Ignore local config**

Add `config.json` to `.gitignore` so private local paths and repository URLs are not committed.

## Chunk 2: Shared PowerShell Library

### Task 2: Implement Shared Helpers

**Files:**
- Create: `scripts/lib/config.ps1`
- Create: `scripts/lib/git-utils.ps1`
- Create: `scripts/lib/backup.ps1`
- Create: `scripts/lib/operations.ps1`
- Create: `scripts/lib/menu.ps1`

- [ ] **Step 1: Implement config loading**

Load `config.json`, expand `%USERPROFILE%` paths, validate required tool sections, and provide default `backupRetention = 3`.

- [ ] **Step 2: Implement Git utilities**

Wrap common Git commands: repo detection, origin lookup, branch lookup, fetch, status, ahead/behind, and remote verification.

- [ ] **Step 3: Implement backup helpers**

Back up only approved sync scope and prune old backups beyond retention.

- [ ] **Step 4: Implement tool operations**

Implement setup, pull, push, status, and rebind operations using the shared helpers.

- [ ] **Step 5: Implement menu helpers**

Render main and tool-specific menus and call the same operations used by direct scripts.

## Chunk 3: Direct Scripts And Double-Click Launchers

### Task 3: Add User Entry Points

**Files:**
- Create: `sync.ps1`
- Create: `scripts/setup-all.ps1`
- Create: `scripts/setup-codex.ps1`
- Create: `scripts/setup-claude.ps1`
- Create: `scripts/pull-all.ps1`
- Create: `scripts/pull-codex.ps1`
- Create: `scripts/pull-claude.ps1`
- Create: `scripts/push-all.ps1`
- Create: `scripts/push-codex.ps1`
- Create: `scripts/push-claude.ps1`
- Create: `scripts/status.ps1`
- Create: `scripts/rebind-codex.ps1`
- Create: `scripts/rebind-claude.ps1`
- Create: `01-初始化.cmd`
- Create: `02-拉取全部.cmd`
- Create: `03-拉取Codex.cmd`
- Create: `04-拉取Claude.cmd`
- Create: `05-推送全部.cmd`
- Create: `06-推送Codex.cmd`
- Create: `07-推送Claude.cmd`

- [ ] **Step 1: Add direct PowerShell scripts**

Each direct script imports `scripts/lib/operations.ps1` and calls exactly one shared operation.

- [ ] **Step 2: Add Chinese `.cmd` launchers**

Each launcher calls PowerShell with `-ExecutionPolicy Bypass`, runs the corresponding direct script, and pauses at the end.

- [ ] **Step 3: Add interactive menu**

`sync.ps1` imports menu helpers and starts the interactive manager.

## Chunk 4: Documentation And Verification

### Task 4: Update README And Verify Syntax

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document setup workflow**

Explain copying `config.example.json` to `config.json`, filling repository URLs, running initialization, pull, and push.

- [ ] **Step 2: Verify PowerShell syntax**

Run PowerShell parser checks over all `.ps1` files.

- [ ] **Step 3: Verify launcher presence**

List the root `.cmd` launchers and direct scripts.
