# 仓库级包装命令：
# - `make install-links`：软链接安装到用户级 agent 目录
# - `make install-project PROJECT=/path/to/project`：拷贝安装到项目目录
# - `make install`：兼容旧入口；未传项目路径时等价于 `install-links`

SHELL := /bin/bash
AGENT ?=
PROJECT ?=
DIR ?=
INSTALL_SCRIPT := ./scripts/install_skills.sh
RESOLVED_PROJECT := $(or $(PROJECT),$(DIR))

.PHONY: help install install-links install-project

help:
	@echo "可用命令："
	@echo "  make install-links [AGENT=codex|qwen|qoder|claudecode|openclaw]"
	@echo "  make install-project PROJECT=/path/to/project [AGENT=...]"
	@echo "  make install [AGENT=...] [PROJECT=/path/to/project|DIR=/path/to/project]"

install:
ifeq ($(strip $(RESOLVED_PROJECT)),)
	@$(MAKE) install-links AGENT="$(AGENT)"
else
	@$(MAKE) install-project AGENT="$(AGENT)" PROJECT="$(RESOLVED_PROJECT)"
endif

install-links:
	@$(INSTALL_SCRIPT) $(if $(AGENT),--agent "$(AGENT)")

install-project:
	@if [[ -z "$(RESOLVED_PROJECT)" ]]; then \
		echo "缺少 PROJECT=/path/to/project（兼容旧参数：DIR=/path/to/project）" >&2; \
		exit 1; \
	fi
	@$(INSTALL_SCRIPT) $(if $(AGENT),--agent "$(AGENT)") --dir "$(RESOLVED_PROJECT)"
