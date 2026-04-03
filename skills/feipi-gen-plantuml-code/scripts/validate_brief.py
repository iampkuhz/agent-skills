#!/usr/bin/env python3
"""
PlantUML diagram-brief YAML 校验脚本（基于 YAML 规则配置）

用法:
  python scripts/validate_brief.py <brief.yaml>
  python scripts/validate_brief.py <brief.yaml> --rules <rules.yaml>

返回码:
  0 - 校验通过
  1 - 校验失败
"""

import sys
import re
import yaml
from pathlib import Path
from typing import Any


class BriefValidator:
    """基于 YAML 规则配置的 brief 校验器"""

    def __init__(self, rules: dict):
        self.rules = rules
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def validate(self, data: dict) -> bool:
        """校验整个 brief 文档"""
        if not isinstance(data, dict):
            self.errors.append("YAML 根元素必须是映射类型")
            return False

        # 校验顶层字段
        self._validate_fields(data, self.rules.get("fields", {}), "")

        # 校验数组字段
        self._validate_arrays(data, self.rules.get("arrays", {}))

        # 校验交叉引用
        self._validate_cross_references(data, self.rules.get("cross_references", []))

        return len(self.errors) == 0

    def _add_error(self, field: str, message: str) -> None:
        self.errors.append(f"[错误] {field}: {message}")

    def _add_warning(self, field: str, message: str) -> None:
        self.warnings.append(f"[警告] {field}: {message}")

    def _validate_fields(
        self,
        data: dict,
        field_rules: dict,
        prefix: str
    ) -> None:
        """校验顶层字段"""
        for field_name, rule in field_rules.items():
            full_name = f"{prefix}{field_name}" if prefix else field_name
            value = data.get(field_name)

            # 必填检查
            if rule.get("required", False) and field_name not in data:
                self._add_error(full_name, "必填字段缺失")
                continue

            if value is None:
                continue

            # 类型检查
            expected_type = rule.get("type")
            if expected_type == "string" and not isinstance(value, str):
                self._add_error(full_name, f"必须是字符串类型，当前为 {type(value).__name__}")
                continue

            if not isinstance(value, str):
                continue

            # 长度检查
            min_len = rule.get("min_length")
            max_len = rule.get("max_length")

            if min_len and len(value) < min_len:
                self._add_error(full_name, f"长度不能少于 {min_len} 字符 (当前 {len(value)})")

            if max_len and len(value) > max_len:
                self._add_error(full_name, f"长度不能超过 {max_len} 字符 (当前 {len(value)})")

            # 枚举检查
            enum_values = rule.get("enum")
            if enum_values and value not in enum_values:
                self._add_error(
                    full_name,
                    f"必须是 {enum_values} 之一，当前为 '{value}'"
                )

            # 正则匹配检查
            pattern = rule.get("pattern")
            if pattern and not re.match(pattern, value):
                self._add_error(full_name, f"格式不匹配：{pattern}")

    def _validate_arrays(
        self,
        data: dict,
        array_rules: dict
    ) -> None:
        """校验数组字段"""
        for array_name, rule in array_rules.items():
            if array_name not in data:
                if rule.get("required", False):
                    self._add_error(array_name, "必填字段缺失")
                continue

            array = data[array_name]
            if not isinstance(array, list):
                self._add_error(array_name, "必须是数组类型")
                continue

            # 数量检查
            min_items = rule.get("min_items")
            if min_items and len(array) < min_items:
                self._add_error(
                    array_name,
                    f"至少需要 {min_items} 项，当前 {len(array)} 项"
                )

            # 校验数组元素
            element_rules = rule.get("fields", {})
            for i, item in enumerate(array):
                if not isinstance(item, dict):
                    self._add_error(f"{array_name}[{i}]", "必须是映射类型")
                    continue

                self._validate_array_element(
                    item, element_rules, f"{array_name}[{i}]"
                )

    def _validate_array_element(
        self,
        item: dict,
        element_rules: dict,
        prefix: str
    ) -> None:
        """校验数组元素"""
        for field_name, rule in element_rules.items():
            full_name = f"{prefix}.{field_name}"
            value = item.get(field_name)

            # 必填检查
            if rule.get("required", False) and field_name not in item:
                self._add_error(full_name, "必填字段缺失")
                continue

            if value is None:
                continue

            # 类型检查
            expected_type = rule.get("type")
            if expected_type == "string" and not isinstance(value, str):
                self._add_error(full_name, f"必须是字符串类型")
                continue

            if not isinstance(value, str):
                continue

            # 长度检查
            min_len = rule.get("min_length")
            max_len = rule.get("max_length")

            if min_len and len(value) < min_len:
                self._add_error(
                    full_name, f"长度不能少于 {min_len} 字符"
                )

            if max_len and len(value) > max_len:
                self._add_error(
                    full_name, f"长度不能超过 {max_len} 字符"
                )

            # 枚举检查
            enum_values = rule.get("enum")
            if enum_values and value not in enum_values:
                self._add_error(
                    full_name,
                    f"必须是 {enum_values} 之一，当前为 '{value}'"
                )

            # 正则匹配检查
            pattern = rule.get("pattern")
            if pattern and not re.match(pattern, value):
                self._add_error(full_name, f"格式不匹配：{pattern}")

    def _validate_cross_references(
        self,
        data: dict,
        cross_refs: list
    ) -> None:
        """校验交叉引用"""
        # 收集所有有效的引用目标
        ref_targets: dict[str, set[str]] = {}

        # layers[].id
        valid_layer_ids = {
            layer.get("id")
            for layer in data.get("layers", [])
            if isinstance(layer, dict) and layer.get("id")
        }
        if valid_layer_ids:
            ref_targets["layers[].id"] = valid_layer_ids

        # components[].id
        valid_component_ids = {
            comp.get("id")
            for comp in data.get("components", [])
            if isinstance(comp, dict) and comp.get("id")
        }
        if valid_component_ids:
            ref_targets["components[].id"] = valid_component_ids

        # 校验每个交叉引用规则
        for ref_rule in cross_refs:
            field = ref_rule.get("field", "")
            references = ref_rule.get("references", "")

            valid_refs = ref_targets.get(references, set())

            if field.startswith("components[]."):
                target_field = field.split("[]", 1)[1].lstrip(".")
                for i, comp in enumerate(data.get("components", [])):
                    if not isinstance(comp, dict):
                        continue
                    ref_value = comp.get(target_field)
                    if ref_value and ref_value not in valid_refs:
                        self._add_error(
                            f"components[{i}].{target_field}",
                            f"引用了未定义的 {references}: '{ref_value}'，"
                            f"可用的 id: {sorted(valid_refs)}"
                        )

            elif field.startswith("flows[]."):
                target_field = field.split("[]", 1)[1].lstrip(".")
                for i, flow in enumerate(data.get("flows", [])):
                    if not isinstance(flow, dict):
                        continue
                    ref_value = flow.get(target_field)
                    if ref_value and ref_value not in valid_refs:
                        self._add_error(
                            f"flows[{i}].{target_field}",
                            f"引用了未定义的 {references}: '{ref_value}'，"
                            f"可用的 id: {sorted(valid_refs)}"
                        )


def load_rules(rules_path: Path) -> dict:
    """加载 YAML 规则配置"""
    with open(rules_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_yaml(yaml_path: Path) -> dict:
    """加载 YAML 文件"""
    with open(yaml_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate_brief(
    yaml_path: Path,
    rules: dict
) -> tuple[bool, list[str], list[str]]:
    """
    校验 brief 文件

    Returns:
        (is_valid, errors, warnings)
    """
    # 加载 YAML
    try:
        data = load_yaml(yaml_path)
    except yaml.YAMLError as e:
        return False, [f"YAML 解析错误：{e}"], []

    if data is None:
        return False, ["YAML 文件为空"], []

    # 执行校验
    validator = BriefValidator(rules)
    is_valid = validator.validate(data)

    return is_valid, validator.errors, validator.warnings


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "用法：python validate_brief.py <brief.yaml> [--rules <rules.yaml>]",
            file=sys.stderr
        )
        return 1

    brief_path = Path(sys.argv[1])
    rules_arg = None

    # 解析 --rules 参数
    for i, arg in enumerate(sys.argv):
        if arg == "--rules" and i + 1 < len(sys.argv):
            rules_arg = Path(sys.argv[i + 1])

    # 确定 rules 路径
    if rules_arg:
        rules_path = rules_arg
    else:
        # 默认使用 assets/validation/brief-rules.yaml
        rules_path = (
            Path(__file__).parent.parent
            / "assets" / "validation" / "brief-rules.yaml"
        )

    if not brief_path.exists():
        print(f"文件不存在：{brief_path}", file=sys.stderr)
        return 1

    if not rules_path.exists():
        print(f"规则文件不存在：{rules_path}", file=sys.stderr)
        return 1

    # 加载规则
    try:
        rules = load_rules(rules_path)
    except yaml.YAMLError as e:
        print(f"加载规则失败：{e}", file=sys.stderr)
        return 1
    except FileNotFoundError:
        print(f"规则文件不存在：{rules_path}", file=sys.stderr)
        return 1

    # 执行校验
    is_valid, errors, warnings = validate_brief(brief_path, rules)

    # 输出结果
    if is_valid:
        print(f"✓ 校验通过：{brief_path.name}")
        if warnings:
            print("\n警告:")
            for w in warnings:
                print(f"  {w}")
        return 0
    else:
        print(f"✗ 校验失败：{brief_path.name}", file=sys.stderr)
        print("\n错误详情:", file=sys.stderr)
        for i, error in enumerate(errors, 1):
            print(f"  {i}. {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
