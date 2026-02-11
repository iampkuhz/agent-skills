# 本仓库的常用命令入口：
# - `make new`：初始化 skill 骨架
# - `make validate`：校验单个 skill 目录
# - `make list`：列出已有 skills
SHELL := /bin/bash
SKILL ?=
RESOURCES ?=
DIR ?=

.PHONY: new validate list

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
