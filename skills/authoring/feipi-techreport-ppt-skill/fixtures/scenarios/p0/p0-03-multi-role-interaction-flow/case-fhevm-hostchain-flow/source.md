# Source: Zama FHEVM 架构与交互流程

生成 1 页 16:9 技术汇报 PPT。

主题：Zama FHEVM 架构与交互流程（用户直接与 HostChain 合约交互）。

页面目标：用多角色交互流程图解释用户、DApp、HostChain、Coprocessor、Gateway、KMS、Oracle/Relayer 之间的核心交互。重点是说明链上合约、密文计算、解密请求、KMS签名、Oracle/Relayer回写之间的关系。

角色 / 组件：

- 用户 / DApp
- HostChain（以太坊 / L2）
- Coprocessor 网络
- Zama Gateway
- KMS 网络
- Oracle / Relayer

必须包含 10 个步骤：

1. 用户在本地选择明文业务数据并生成加密输入
2. SDK 输出 encrypted handles 与 inputProof
3. 用户钱包直接调用 HostChain 业务合约
4. 合约 / Executor 发出符号化 FHE 计算事件
5. Coprocessor 在密文上执行 FHE 计算
6. Coprocessor 将结果承诺与签名提交 Gateway 聚合
7. 用户发起解密请求
8. Gateway 检查 ACL 并调用 KMS
9. KMS 阈值解密并输出签名结果
10. Oracle / Relayer 回写链上或返回用户

注意：

- 步骤必须编号。
- 主交易线、密文计算线、解密返回线、内部/状态同步线要区分。
- 右侧需要有步骤说明和关键解释。
