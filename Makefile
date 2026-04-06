# 本仓库的常用命令入口：
# - `make install`：将本仓库 skills 安装到 agent 目录（软链接或拷贝到项目）
#
# 用法：
#   make install
#     安装到所有已存在的用户级 agent 目录（软链接）
#   make install AGENT=claudecode
#     仅安装到 ~/.claude/skills（软链接）
#   make install DIR=/path/to/project
#     安装到项目目录 /path/to/project/.agents/skills（拷贝）
#   make install AGENT=qwen DIR=/path/to/project
#     安装到项目目录 /path/to/project/.qwen/skills（拷贝）
#
# 参数说明：
#   AGENT: 指定 agent 类型（codex | qwen | qoder | claudecode | openclaw）
#          未指定时，软链接模式安装到所有已存在目录，拷贝模式使用默认 .agents/skills
#   DIR:   目标路径
#          未指定时，安装到用户级目录（软链接模式）
#          填写项目目录时，安装到该项目内（拷贝模式）

SHELL := /bin/bash
SKILL ?=
AGENT ?=
DIR ?=

.PHONY: install

install:
	./feipi-scripts/repo/install_skills.sh $(if $(AGENT),--agent "$(AGENT)") $(if $(DIR),--dir "$(DIR)")
