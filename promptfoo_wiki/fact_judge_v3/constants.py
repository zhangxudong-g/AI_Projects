ENGINEERING_ACTION_MAP = [
    {
        "min": 90,
        "max": 100,
        "label": "PRIMARY_REFERENCE",
        "description": "可作为主要参考文档",
        "action": "可直接用于理解、调试和修改代码",
    },
    {
        "min": 70,
        "max": 89,
        "label": "SAFE_WITH_CAUTION",
        "description": "可用于理解与修改，需关注风险点",
        "action": "修改前需重点核对标注的风险或 TODO",
    },
    {
        "min": 50,
        "max": 69,
        "label": "STRUCTURE_ONLY",
        "description": "仅供理解结构，修改需对照源码",
        "action": "不可仅依赖文档进行修改",
    },
    {
        "min": 40,
        "max": 49,
        "label": "READ_ONLY_WARNING",
        "description": "不建议用于修改",
        "action": "仅用于初步了解，不可指导工程决策",
    },
    {
        "min": 0,
        "max": 39,
        "label": "UNTRUSTWORTHY",
        "description": "不可信",
        "action": "不应作为任何工程依据",
    },
]
