# 本仓库的常用命令入口：
# - `make new`：初始化 skill 骨架
# - `make validate`：校验单个 skill 目录
# - `make list`：列出已有 skills
# - `make install-links`：将本仓库 skills 软链接到用户目录
# - `make test`：按统一入口执行 skill 测试
SHELL := /bin/bash
SKILL ?=
RESOURCES ?=
DIR ?=
CONFIG ?=
OUTPUT ?=

.PHONY: new validate list install-links test

# 在 `skills/` 下创建新 skill。
# 示例：make new SKILL=gen-api-tests RESOURCES=scripts,references
new:
	@if [[ -z "$(SKILL)" ]]; then echo "用法: make new SKILL=<name> [RESOURCES=scripts,references,assets]"; exit 1; fi
	./scripts/init_skill.sh "$(SKILL)" $(if $(RESOURCES),--resources "$(RESOURCES)")

# 校验一个 skill 目录。
# 示例：make validate DIR=skills/feipi-gen-skills
validate:
	@if [[ -z "$(DIR)" ]]; then echo "用法: make validate DIR=skills/<name>"; exit 1; fi
	./scripts/quick_validate.sh "$(DIR)"

# 列出 `skills/` 下一层目录。
list:
	@find skills -maxdepth 1 -mindepth 1 -type d | sort

# 将仓库 `skills/` 下各 skill 软链接到 `$CODEX_HOME/skills`（默认 `~/.codex/skills`）。
# 示例：
# - make install-links
install-links:
	./scripts/install_skills_links.sh

# 统一执行 skill 测试入口。
# 示例：
# - make test SKILL=feipi-read-youtube-video
# - make test SKILL=read-youtube-video
# - make test SKILL=feipi-read-youtube-video CONFIG=skills/feipi-read-youtube-video/references/test_cases.txt OUTPUT=./tmp/runs
test:
	@if [[ -z "$(SKILL)" ]]; then echo "用法: make test SKILL=<name> [CONFIG=<path>] [OUTPUT=<path>]"; exit 1; fi
	./scripts/run_skill_test.sh "$(SKILL)" $(if $(CONFIG),--config "$(CONFIG)") $(if $(OUTPUT),--output "$(OUTPUT)")
