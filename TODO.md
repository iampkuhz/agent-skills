## LLM 声称已完成

- [x] 001：统一 PlantUML skill 第一阶段审计与决策（基线、命名、迁移策略）
- [x] 002：创建 feipi-plantuml-generate-diagram 统一 skill 骨架（结构校验通过、test.sh 通过）
- [x] 003：architecture profile 迁移（schema/template/校验链）
- [x] 004：sequence profile 迁移（schema/template/校验链）
- [x] 005：profile_registry.py 共享注册表（路径已修正）
- [x] 006：文档兼容性报告（脚本路径对齐、brief_path 补全）
- [x] 007：扩展流程演练报告（expansion-playbook 修正）

## TODO

- [ ] 研究 open-code-review 架构，以及分析从 skill 作为入口的用法，重 skill 入口是否可行，对比单项目有什么劣势
- [ ] blockchain research 调研，分析现在 harness 问题
- [ ] 详细研究 open-code-review 怎么使用，围绕 skill 的一个入口是否有问题
- [ ] session browser
  - profile 里面每次 llm call 如果是 read，request context 看不出来 size
- [ ] ppt skill 优化，支持固定版式要求。目标能画出来 chatgpt 一样效果的 ppt
- [ ] ppt skill：
  - 如果有图标+文字，且文字是多行，考虑group
  - 文本框要设置默认的 margin 和行间距
  - 空白的单元格考虑merge
  - 单独的文本框不要自动调整大小，要固定大小

## OTEL 调试

等待 claude-code stable 仓库升级到 2.1.111 后，调试 otel 查看 claude 的 request/response 目录，并优化 tools/gateway/otel/README.md 里面的初始化环境变量配置方法，力求简单易用