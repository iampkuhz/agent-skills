# Helpers

本目录存放 Presentation Compiler 的辅助脚本和工具函数。

## 目录结构

```text
helpers/
├── geometry.js            # 几何运算函数（矩形重叠、包含、间距等）
├── semantic-rules.js      # 语义碰撞规则（连接器端点感知、小重叠容忍等）
├── static-qa.js           # 静态 QA 引擎
├── render/
│   └── manifest.js        # PNG header 解析 + render manifest 构建
├── repair/
│   ├── classify-issues.js # Issue 分类器（Static QA + Render QA → 可修复类型）
│   └── repair-plan.js     # Repair Plan 生成器
├── pipeline/
│   └── run-pipeline.js    # Pipeline 编排器（Validate → Static QA → Build → Render QA → Report）
└── pptx/
    ├── theme.js           # 主题定义（颜色、字号、字体、画布）
    ├── primitives.js      # PptxGenJS 原子操作封装
    ├── compiler.js        # 编译器（builder 注册 + 编译入口）
    └── builders/
        ├── architecture-map.js   # 架构图 builder
        ├── flow-diagram.js       # 流程图 builder
        └── comparison-matrix.js  # 对比矩阵 builder
```

## 约束

- Helper 脚本不应包含完整业务逻辑，只做可复用的原子操作。
- 不引入 npm/pip 依赖（`pptxgenjs` 是可选依赖，通过 graceful skip 处理）。
- 每个 helper 必须有明确的输入输出契约。
