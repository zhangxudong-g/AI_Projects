import pytest
import tempfile
import shutil
from pathlib import Path
from opencli.security import TrustedFolderManager, TrustedFolder, Permission, PolicyEngine, PolicyRule, Effect

@pytest.fixture
def temp_folder():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

class TestTrustedFolderManager:
    def test_init_empty(self):
        manager = TrustedFolderManager()
        assert manager.folders == []

    def test_check_access_read_permission(self, temp_folder):
        trusted = TrustedFolder(path=temp_folder, permissions={Permission.READ})
        manager = TrustedFolderManager(folders=[trusted])
        assert manager.check_access(temp_folder / "file.txt", Permission.READ) is True

    def test_check_access_missing_permission(self, temp_folder):
        trusted = TrustedFolder(path=temp_folder, permissions={Permission.READ})
        manager = TrustedFolderManager(folders=[trusted])
        assert manager.check_access(temp_folder / "file.txt", Permission.WRITE) is False

    def test_check_access_nested_path(self, temp_folder):
        nested = temp_folder / "sub" / "nested"
        nested.mkdir(parents=True)
        trusted = TrustedFolder(path=temp_folder, permissions={Permission.READ}, recursive=True)
        manager = TrustedFolderManager(folders=[trusted])
        assert manager.check_access(nested / "deep.txt", Permission.READ) is True

    def test_check_access_unrelated_path(self, temp_folder):
        trusted = TrustedFolder(path=temp_folder, permissions={Permission.READ})
        manager = TrustedFolderManager(folders=[trusted])
        other = Path(tempfile.mkdtemp())
        try:
            assert manager.check_access(other / "file.txt", Permission.READ) is False
        finally:
            shutil.rmtree(other)

class TestPolicyEngine:
    def test_default_deny_delete_file(self):
        engine = PolicyEngine()
        assert engine.evaluate("file", "delete") is False

    def test_default_allow_other_actions(self):
        engine = PolicyEngine()
        assert engine.evaluate("file", "read") is True
        assert engine.evaluate("file", "write") is True

    def test_evaluate_unknown_resource(self):
        engine = PolicyEngine()
        assert engine.evaluate("unknown", "delete") is True

    def test_add_rule(self, temp_folder):
        engine = PolicyEngine()
        rule = PolicyRule(resource="network", action="connect", effect=Effect.DENY)
        engine.rules.append(rule)
        assert engine.evaluate("network", "connect") is False