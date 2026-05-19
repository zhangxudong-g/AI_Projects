import asyncio
import os
from typing import Optional
from .types import Hook, HookType

class HookManager:
    def __init__(self):
        self.hooks: list[Hook] = []

    def register(self, hook: Hook):
        self.hooks.append(hook)

    def unregister(self, hook: Hook):
        if hook in self.hooks:
            self.hooks.remove(hook)

    def get_hooks(self, hook_type: HookType) -> list[Hook]:
        return [h for h in self.hooks if h.type == hook_type]

    async def execute(self, hook_type: HookType, context: dict) -> bool:
        matching = self.get_hooks(hook_type)
        for hook in matching:
            result = await self._execute_hook(hook, context)
            if not result:
                return False
        return True

    async def _execute_hook(self, hook: Hook, context: dict) -> bool:
        proc = await asyncio.create_subprocess_shell(
            hook.script,
            env={**os.environ, **context.get("env", {})},
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            await asyncio.wait_for(proc.wait(), timeout=hook.timeout)
            return proc.returncode == 0
        except asyncio.TimeoutError:
            proc.kill()
            return False