import json
import re
import os
from collections import defaultdict
from pathlib import Path
from typing import Dict, List

# 加载 .env 文件中的环境变量
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    # 如果没有安装 python-dotenv，则跳过加载
    pass


# ---------- optional deps ----------
try:
    import javalang
except ImportError:
    javalang = None

try:
    import sqlparse
    from sqlparse.sql import Identifier, IdentifierList, Where, Function
    from sqlparse.tokens import Keyword, DML
except ImportError:
    sqlparse = None


# ---------- shared ----------
def _uniq(seq: List[str]) -> List[str]:
    return sorted(set(seq))


def classify_java_artifact(anchors: dict) -> str:
    annotations = set(anchors.get("annotations", []))
    methods = anchors.get("methods", [])
    fields = anchors.get("fields", [])

    if annotations & {"Controller", "RestController"}:
        return "CONTROLLER"

    if annotations & {"Service"}:
        return "SERVICE"

    if annotations & {"Repository"}:
        return "REPOSITORY"

    if fields and not methods:
        return "DATA_STRUCTURE"

    return "UNKNOWN"


PROPERTY_GETTER_RE = re.compile(r"^(get|is)([A-Z]\w+)$")
PROPERTY_SETTER_RE = re.compile(r"^set([A-Z]\w+)$")

GETTER_SETTER_RE = re.compile(r"^(get|set|is)[A-Z_].*")

JAVA_IMPORTANT_ANNOTATIONS = {
    "Controller",
    "Service",
    "Component",
    "Repository",
    "RequestMapping",
    "GetMapping",
    "PostMapping",
    "PutMapping",
    "DeleteMapping",
    "ModelAttribute",
    "Inject",
    "Autowired",
}

SQL_IMPORTANT_FUNCTIONS = {
    "COUNT",
    "SUM",
    "AVG",
    "MIN",
    "MAX",
    "NVL",
    "COALESCE",
    "CAST",
    "TO_CHAR",
    "TO_DATE",
}


# =========================================================
# MAIN
# =========================================================
def extract_anchors(*, source_code: str, language: str) -> Dict[str, List[str]]:
    """
    Extract engineering-level anchors from source code.
    Anchors are NOT coverage items.
    They are semantic hints for later fact aggregation.

    Supports:
      - Python
      - Java
      - SQL / PL/SQL
    """
    lang = language.lower()
    anchors = defaultdict(list)

    # =====================================================
    # Python
    # =====================================================
    if lang == "python":
        anchors["classes"] += re.findall(r"\bclass\s+([A-Z_a-z][\w]*)\b", source_code)

        anchors["functions"] += re.findall(r"\bdef\s+([a-zA-Z_]\w*)\s*\(", source_code)

        anchors["async_functions"] += re.findall(
            r"\basync\s+def\s+([a-zA-Z_]\w*)\s*\(", source_code
        )

        anchors["decorators"] += re.findall(r"@([a-zA-Z_][\w\.]*)", source_code)

        anchors["imports"] += re.findall(
            r"^\s*(?:from|import)\s+([a-zA-Z_][\w\.]*)",
            source_code,
            re.MULTILINE,
        )

    # =====================================================
    # Java (AST first, regex fallback)
    # =====================================================
    elif lang == "java":
        parsed = False

        if javalang is not None:
            try:
                tree = javalang.parse.parse(source_code)
                parsed = True

                for imp in tree.imports:
                    anchors["imports"].append(imp.path)

                for _, node in tree:
                    # classes / interfaces / enums
                    if isinstance(
                        node,
                        (
                            javalang.tree.ClassDeclaration,
                            javalang.tree.InterfaceDeclaration,
                            javalang.tree.EnumDeclaration,
                        ),
                    ):
                        anchors["classes"].append(node.name)

                        for ann in node.annotations or []:
                            if ann.name in JAVA_IMPORTANT_ANNOTATIONS:
                                anchors["annotations"].append(ann.name)

                    # fields
                    if isinstance(node, javalang.tree.FieldDeclaration):
                        for d in node.declarators:
                            anchors["fields"].append(d.name)

                    # methods
                    if isinstance(node, javalang.tree.MethodDeclaration):
                        if not ({"public", "protected"} & set(node.modifiers)):
                            continue

                        name = node.name
                        if GETTER_SETTER_RE.match(name):
                            continue

                        anchors["methods"].append(name)

                        for ann in node.annotations or []:
                            if ann.name in JAVA_IMPORTANT_ANNOTATIONS:
                                anchors["annotations"].append(ann.name)

            except Exception:
                parsed = False

        # -------- regex fallback --------
        if not parsed:
            anchors["classes"] += [
                c[1]
                for c in re.findall(
                    r"\b(class|interface|enum)\s+([A-Z][\w]*)",
                    source_code,
                )
            ]

            for m in re.findall(
                r"""
                \b(public|protected)\s+
                (?:static\s+|final\s+|synchronized\s+|abstract\s+)*
                [\w\<\>\[\]]+\s+
                ([a-zA-Z_]\w*)\s*\(
                """,
                source_code,
                re.VERBOSE,
            ):
                name = m[1]
                if not GETTER_SETTER_RE.match(name):
                    anchors["methods"].append(name)

            for ann in re.findall(r"@([A-Z][A-Za-z0-9_]*)", source_code):
                if ann in JAVA_IMPORTANT_ANNOTATIONS:
                    anchors["annotations"].append(ann)

            anchors["imports"] += re.findall(
                r"\bimport\s+(?:static\s+)?([\w\.]+);",
                source_code,
            )

    # =====================================================
    # SQL / PL/SQL
    # =====================================================
    elif lang in {"sql", "plsql", "oracle"}:
        # strip comments
        code = re.sub(r"--.*?$", "", source_code, flags=re.MULTILINE)
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)

        parsed = False

        # ---------- sqlparse path ----------
        if sqlparse is not None:
            try:
                statements = sqlparse.parse(code)
                parsed = True

                for stmt in statements:
                    for token in stmt.tokens:
                        if token.ttype is DML:
                            anchors["statements"].append(token.value.upper())

                        if isinstance(token, Where):
                            anchors["conditions"].append(
                                re.sub(r"\s+", " ", token.value.strip())
                            )

                        if isinstance(token, Function):
                            fname = token.get_name()
                            if fname and fname.upper() in SQL_IMPORTANT_FUNCTIONS:
                                anchors["functions"].append(fname.upper())

                        if token.ttype is Keyword and "JOIN" in token.value.upper():
                            anchors["joins"].append(token.value.upper())

                        if isinstance(token, IdentifierList):
                            for ident in token.get_identifiers():
                                _sql_ident(ident, anchors)

                        elif isinstance(token, Identifier):
                            _sql_ident(token, anchors)

            except Exception:
                parsed = False

        # ---------- regex fallback ----------
        if not parsed:
            anchors["statements"] += re.findall(
                r"\b(SELECT|INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP)\b",
                code,
                re.I,
            )

            anchors["tables"] += re.findall(
                r"\bFROM\s+([A-Z0-9_\.]+)|\bJOIN\s+([A-Z0-9_\.]+)|\bUPDATE\s+([A-Z0-9_\.]+)|\bINTO\s+([A-Z0-9_\.]+)",
                code,
                re.I,
            )

            anchors["conditions"] += [
                re.sub(r"\s+", " ", c[0])
                for c in re.findall(
                    r"\bWHERE\s+(.*?)(GROUP BY|ORDER BY|HAVING|$)",
                    code,
                    re.I | re.DOTALL,
                )
            ]

            anchors["joins"] += re.findall(
                r"\b(INNER JOIN|LEFT JOIN|RIGHT JOIN|FULL JOIN|JOIN)\b",
                code,
                re.I,
            )

            anchors["functions"] += re.findall(
                r"\b(COUNT|SUM|AVG|MIN|MAX|NVL|COALESCE|CAST|TO_CHAR|TO_DATE)\b",
                code,
                re.I,
            )

        # ---------- PL/SQL structures ----------
        anchors["procedures"] += re.findall(
            r"\bcreate\s+(?:or\s+replace\s+)?procedure\s+([A-Z0-9_]+)",
            code,
            re.I,
        )

        anchors["functions"] += re.findall(
            r"\bcreate\s+(?:or\s+replace\s+)?function\s+([A-Z0-9_]+)",
            code,
            re.I,
        )

        anchors["packages"] += re.findall(
            r"\bcreate\s+(?:or\s+replace\s+)?package\s+([A-Z0-9_]+)",
            code,
            re.I,
        )

        anchors["package_bodies"] += re.findall(
            r"\bcreate\s+(?:or\s+replace\s+)?package\s+body\s+([A-Z0-9_]+)",
            code,
            re.I,
        )

        anchors["triggers"] += re.findall(
            r"\bcreate\s+(?:or\s+replace\s+)?trigger\s+([A-Z0-9_]+)",
            code,
            re.I,
        )

        anchors["with_queries"] += re.findall(
            r"\bwith\s+([A-Z0-9_]+)\s+as\s*\(",
            code,
            re.I,
        )

    else:
        raise ValueError(f"Unsupported language: {language}")

    # 针对 Java 代码，进行 artifact 类型分类
    if language.lower() == "java":
        artifact_type = classify_java_artifact(anchors)
        anchors["artifact_type"] = [artifact_type]

    # 针对 SQL 代码，设置 artifact 类型为 SQL_SCRIPT
    if language.lower() == "sql":
        # normalize table names
        anchors["artifact_type"] = "SQL_SCRIPT"

    # =====================================================
    # normalize / dedupe
    # =====================================================
    return {k: _uniq(v) for k, v in anchors.items()}


# =========================================================
# SQL helpers
# =========================================================
def _sql_ident(ident, anchors):
    real = ident.get_real_name()
    if not real or real == "*":
        return

    # table.column or alias.column
    if "." in real:
        anchors["columns"].append(real.split(".")[-1])
    else:
        anchors["columns"].append(real)

    parent = ident.get_parent_name()
    if parent:
        anchors["tables"].append(parent)


def prepare_engineering_facts(
    *,
    source_code: str,
    language: str,
    output_dir: Path,
) -> Path:
    anchors = extract_anchors(
        source_code=source_code,
        language=language,
    )
    anchors_path = output_dir / "anchors.json"
    anchors_path.write_text(
        json.dumps(anchors, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    return {
        "anchors_path": anchors_path,
        "artifact_type": anchors.get("artifact_type", ["UNKNOWN"])[0],
    }
