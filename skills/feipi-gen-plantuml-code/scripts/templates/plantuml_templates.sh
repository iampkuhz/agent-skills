#!/usr/bin/env bash
set -euo pipefail

# 根据需求文本生成 PlantUML 代码。
# 支持 component / sequence / class 三类图。

usage() {
  cat <<'USAGE'
用法:
  scripts/generate_plantuml.sh --type <component|sequence|class|auto> --requirement <text> [--title <title>] [--output <path>]

示例:
  bash scripts/generate_plantuml.sh --type component --requirement "画钱包插件与 RPC 的分层组件图" --output ./tmp/diagram.puml
USAGE
}

TYPE=""
REQUIREMENT=""
TITLE=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TYPE="$2"
      shift 2
      ;;
    --requirement)
      REQUIREMENT="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 1
      ;;
  esac
done

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

TYPE="$(trim "$TYPE")"
REQUIREMENT="$(trim "$REQUIREMENT")"
TITLE="$(trim "$TITLE")"
OUTPUT="$(trim "$OUTPUT")"

if [[ -z "$TYPE" || -z "$REQUIREMENT" ]]; then
  echo "必须提供 --type 与 --requirement" >&2
  usage
  exit 1
fi

if [[ "$TYPE" == "auto" ]]; then
  if printf '%s' "$REQUIREMENT" | rg -qi '(组件|module|模块|rpc|钱包|dapp)'; then
    TYPE="component"
  elif printf '%s' "$REQUIREMENT" | rg -qi '(时序|sequence|交互|请求|响应)'; then
    TYPE="sequence"
  elif printf '%s' "$REQUIREMENT" | rg -qi '(类图|class|对象|实体|模型)'; then
    TYPE="class"
  else
    echo "auto 无法识别图类型，请显式指定 --type" >&2
    exit 2
  fi
fi

if [[ -z "$TITLE" ]]; then
  case "$TYPE" in
    component)
      TITLE="分层组件流程图"
      ;;
    sequence)
      TITLE="业务交互时序图"
      ;;
    class)
      TITLE="领域类图"
      ;;
    *)
      ;;
  esac
fi

# 简单关键字提取：优先贴合钱包/RPC/DApp 语义。
COMP_APP_NAME="业务应用"
COMP_WALLET_NAME="钱包插件"
COMP_INFRA_NAME="基础设施"

if printf '%s' "$REQUIREMENT" | rg -qi '(dapp|前端|页面|应用)'; then
  COMP_APP_NAME="DApp 页面"
fi
if printf '%s' "$REQUIREMENT" | rg -qi '(钱包|wallet)'; then
  COMP_WALLET_NAME="钱包插件"
fi
if printf '%s' "$REQUIREMENT" | rg -qi '(rpc|链|网络|节点)'; then
  COMP_INFRA_NAME="RPC / 链网络"
fi

build_component() {
  cat <<PUML
@startuml
title ${TITLE}

skinparam componentStyle uml2
skinparam shadowing false
top to bottom direction
skinparam nodesep 6
skinparam ranksep 78
skinparam linetype ortho

' L1 应用层（浅蓝）
rectangle "L1 应用层（${COMP_APP_NAME}）" as L_APP #F4F7FF {
  component "DApp UI\n(页面逻辑)" as DAppUI
  component "Provider API\n(request/events)" as ProviderAPI #FFF2CC
  DAppUI -[hidden]down-> ProviderAPI
}

' L2 钱包层（浅绿）
rectangle "L2 钱包层（${COMP_WALLET_NAME}）" as L_WALLET #F7FFF4 {
  component "Provider Impl\n(钱包实现)" as ProviderImpl #FFF2CC
  component "Wallet UI\n(授权确认)" as WalletUI
  component "Key Manager\n(签名账户)" as KeyManager
  ProviderImpl -[hidden]down-> WalletUI
  WalletUI -[hidden]down-> KeyManager
}

' L3 基础设施层（浅橙）
rectangle "L3 基础设施层（${COMP_INFRA_NAME}）" as L_INFRA #FFF8F0 {
  component "RPC Endpoint\n(HTTP/WS)" as RPC
  cloud "Chain Network" as Chain
  RPC -[hidden]down-> Chain
}

' 强制层级上下排列，减少并排拥挤
L_APP -[hidden]down-> L_WALLET
L_WALLET -[hidden]down-> L_INFRA

' 模块间流程 edge：统一用 S 序号
DAppUI -down-> ProviderAPI : S1 发起请求\nmethod+params
ProviderAPI -down-> ProviderImpl : S2 路由到钱包
ProviderImpl -down-> WalletUI : S3 触发授权确认
WalletUI -down-> KeyManager : S4 签名/授权
ProviderImpl -down-> RPC : S5 转发到 RPC
RPC -down-> Chain : S6 链上执行/广播
Chain -up-> RPC : S7 回执结果
RPC -up-> ProviderImpl : S8 回传\n结果/错误
ProviderImpl -up-> ProviderAPI : S9 resolve/\nreject
ProviderAPI -up-> DAppUI : S10 更新 UI

' 事件同步流程
ProviderImpl -up-> ProviderAPI : S11 emit\naccounts\n/chain\n/connect
ProviderAPI -up-> DAppUI : S12 订阅处理\n并重渲染
@enduml
PUML
}

build_sequence() {
  cat <<PUML
@startuml
title ${TITLE}

skinparam shadowing false
skinparam nodesep 8
skinparam ranksep 70

actor User as U
participant "DApp" as D
participant "Provider" as P
participant "Wallet UI" as W
participant "RPC" as R

autonumber
U -> D : 点击 Connect
D -> P : request(eth_requestAccounts)
P -> W : 请求授权
W -> U : 展示账户权限
U -> W : 同意授权
W --> P : 返回账户
P --> D : resolve(accounts)
D -> P : request(personal_sign)
P -> W : 请求签名
U -> W : 确认签名
W -> R : 广播签名请求
R --> P : 返回结果
P --> D : resolve(signature)
@enduml
PUML
}

build_class() {
  cat <<PUML
@startuml
title ${TITLE}

skinparam shadowing false
top to bottom direction
skinparam nodesep 8
skinparam ranksep 72

class Wallet {
  +id: string
  +name: string
  +activeNetworkId: string
  +switchNetwork(networkId)
}

class Account {
  +address: string
  +label: string
  +sign(message)
}

class Network {
  +chainId: int
  +rpcUrl: string
}

class Transaction {
  +hash: string
  +from: string
  +to: string
  +broadcast()
}

class SignatureRequest {
  +message: string
  +approve()
  +reject()
}

Wallet "1" o-- "1..*" Account : 管理
Wallet "1" --> "1" Network : 当前连接
Account "1" --> "0..*" Transaction : 发起
Account "1" --> "0..*" SignatureRequest : 处理
Transaction "*" --> "1" Network : 广播
@enduml
PUML
}

content=""
case "$TYPE" in
  component)
    content="$(build_component)"
    ;;
  sequence)
    content="$(build_sequence)"
    ;;
  class)
    content="$(build_class)"
    ;;
  *)
    echo "不支持的图类型: ${TYPE}（仅支持 component|sequence|class|auto）" >&2
    exit 2
    ;;
esac

if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")"
  printf '%s\n' "$content" > "$OUTPUT"
  echo "output_path=$OUTPUT"
else
  printf '%s\n' "$content"
fi

echo "diagram_type=$TYPE"
echo "requirement_length=${#REQUIREMENT}"
