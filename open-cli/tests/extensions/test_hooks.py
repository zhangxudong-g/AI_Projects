import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.hooks import Hook, HookType, HookManager

class TestHookType:
    def test_hook_types(self):
        assert HookType.BEFORE_TOOL_CALL.value == "before_tool_call"
        assert HookType.AFTER_TOOL_CALL.value == "after_tool_call"
        assert HookType.BEFORE_AGENT_RUN.value == "before_agent_run"
        assert HookType.AFTER_AGENT_RUN.value == "after_agent_run"
        assert HookType.ON_ERROR.value == "on_error"
        assert HookType.ON_CHECKPOINT.value == "on_checkpoint"

class TestHook:
    def test_hook_creation(self):
        hook = Hook(
            type=HookType.BEFORE_TOOL_CALL,
            script="echo test",
            condition={"tool": "read_file"},
            timeout=60
        )
        assert hook.type == HookType.BEFORE_TOOL_CALL
        assert hook.script == "echo test"
        assert hook.condition == {"tool": "read_file"}
        assert hook.timeout == 60

    def test_hook_defaults(self):
        hook = Hook(type=HookType.ON_ERROR, script="echo error")
        assert hook.condition is None
        assert hook.timeout == 30

class TestHookManager:
    def test_manager_init(self):
        manager = HookManager()
        assert manager.hooks == []

    def test_register(self):
        manager = HookManager()
        hook = Hook(type=HookType.BEFORE_TOOL_CALL, script="echo test")
        manager.register(hook)
        assert hook in manager.hooks

    def test_unregister(self):
        manager = HookManager()
        hook = Hook(type=HookType.BEFORE_TOOL_CALL, script="echo test")
        manager.register(hook)
        manager.unregister(hook)
        assert hook not in manager.hooks

    def test_get_hooks(self):
        manager = HookManager()
        h1 = Hook(type=HookType.BEFORE_TOOL_CALL, script="echo 1")
        h2 = Hook(type=HookType.AFTER_TOOL_CALL, script="echo 2")
        h3 = Hook(type=HookType.BEFORE_TOOL_CALL, script="echo 3")
        manager.register(h1)
        manager.register(h2)
        manager.register(h3)
        before_hooks = manager.get_hooks(HookType.BEFORE_TOOL_CALL)
        assert len(before_hooks) == 2
        assert h1 in before_hooks
        assert h3 in before_hooks

    @pytest.mark.asyncio
    async def test_execute_no_matching_hooks(self):
        manager = HookManager()
        result = await manager.execute(HookType.BEFORE_TOOL_CALL, {})
        assert result is True

    @pytest.mark.asyncio
    async def test_execute_hook_script_not_found(self):
        manager = HookManager()
        hook = Hook(type=HookType.BEFORE_TOOL_CALL, script="nonexistent_script_xyz")
        manager.register(hook)
        result = await manager.execute(HookType.BEFORE_TOOL_CALL, {})
        assert result is False