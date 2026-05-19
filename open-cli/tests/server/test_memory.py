import pytest
from opencli.server.memory import AutoMemory, Learning, MemoryCategory


@pytest.fixture
def auto_memory():
    return AutoMemory(project_root="/tmp/test")


@pytest.mark.asyncio
async def test_learn(auto_memory):
    await auto_memory.learn(
        observation="How to build a Python package",
        source="user:123",
        category=MemoryCategory.BUILD_COMMAND
    )

    assert len(auto_memory.learnings) == 1
    learning = auto_memory.learnings[0]
    assert learning.content == "How to build a Python package"
    assert learning.category == MemoryCategory.BUILD_COMMAND


@pytest.mark.asyncio
async def test_recall(auto_memory):
    await auto_memory.learn(
        observation="pytest is a testing framework",
        source="user:123",
        category=MemoryCategory.TEST_COMMAND
    )
    await auto_memory.learn(
        observation="How to build a Python package",
        source="user:456",
        category=MemoryCategory.BUILD_COMMAND
    )

    results = await auto_memory.recall("pytest")
    assert len(results) == 1
    assert "pytest" in results[0].content


@pytest.mark.asyncio
async def test_recall_by_category(auto_memory):
    await auto_memory.learn(
        observation="pytest is a testing framework",
        source="user:123",
        category=MemoryCategory.TEST_COMMAND
    )
    await auto_memory.learn(
        observation="python -m pip install .",
        source="user:456",
        category=MemoryCategory.BUILD_COMMAND
    )

    results = await auto_memory.recall_by_category(MemoryCategory.TEST_COMMAND)
    assert len(results) == 1
    assert results[0].category == MemoryCategory.TEST_COMMAND


def test_get_stats(auto_memory):
    import asyncio
    asyncio.run(auto_memory.learn(
        observation="pytest is a testing framework",
        source="user:123",
        category=MemoryCategory.TEST_COMMAND
    ))
    asyncio.run(auto_memory.learn(
        observation="python -m pip install .",
        source="user:456",
        category=MemoryCategory.BUILD_COMMAND
    ))

    stats = auto_memory.get_stats()
    assert stats[MemoryCategory.TEST_COMMAND.value] == 1
    assert stats[MemoryCategory.BUILD_COMMAND.value] == 1
    assert stats[MemoryCategory.CODE_PATTERN.value] == 0