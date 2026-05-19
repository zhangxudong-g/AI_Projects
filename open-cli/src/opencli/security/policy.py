from dataclasses import dataclass
from enum import Enum

class Effect(Enum):
    ALLOW = "allow"
    DENY = "deny"

@dataclass
class PolicyRule:
    resource: str
    action: str
    effect: Effect = Effect.ALLOW

class PolicyEngine:
    def __init__(self):
        self.rules: list[PolicyRule] = [
            PolicyRule(resource="file", action="delete", effect=Effect.DENY),
        ]

    def evaluate(self, resource: str, action: str) -> bool:
        for rule in self.rules:
            if rule.resource == resource and rule.action == action:
                return rule.effect == Effect.ALLOW
        return True  # Default allow