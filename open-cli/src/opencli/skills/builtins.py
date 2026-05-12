from pathlib import Path
from ..extensions.skills import Skill

TDD_SKILL = Skill(
    name="tdd",
    description="Test Driven Development - write tests before implementation",
    version="1.0.0",
    path=Path("builtin://tdd"),
    prompt_template="",
    triggers=["tdd", "test driven", "write tests", "testing"],
    content="""# Test Driven Development Skill

When the user asks you to implement something using TDD:

## Workflow
1. **Write a failing test** - Start by writing a test that describes the expected behavior
2. **Run the test** - Verify it fails (red phase)
3. **Write minimal code** - Implement the simplest code that makes the test pass
4. **Run tests** - Verify it passes (green phase)
5. **Refactor** - Clean up code while keeping tests passing (refactor phase)

## Rules
- Never write implementation code before writing a failing test
- Write only enough code to pass the current test
- After passing, look for opportunities to refactor
- Keep tests focused on behavior, not implementation details

## Test Format
Use pytest-compatible tests:
```python
def test_feature_behavior():
    # Arrange - set up test data
    # Act - call the function
    # Assert - verify expected behavior
```
"""
)

DEBUG_SKILL = Skill(
    name="debug",
    description="Systematic debugging with hypothesis-driven approach",
    version="1.0.0",
    path=Path("builtin://debug"),
    prompt_template="",
    triggers=["debug", "fix", "error", "bug", "crash", "issue"],
    content="""# Debugging Skill

When the user asks you to debug or fix an issue:

## Systematic Debugging Workflow

### 1. Reproduce the Issue
- Get exact error messages or unexpected behavior
- Identify the conditions that trigger the problem
- Create a minimal reproduction case if possible

### 2. Form Hypothesis
- Based on error message and symptoms, hypothesize the root cause
- Consider: wrong input, state corruption, missing null check, race condition, etc.

### 3. Test Hypothesis
- Add diagnostic output (print statements, logging)
- Modify code to test the hypothesis
- Run and observe results

### 4. Implement Fix
- Fix the root cause, not just the symptoms
- Verify the fix doesn't break other functionality

### 5. Prevent Regression
- Add a test case that would have caught this bug
- Ensure CI/CD will catch similar issues in the future

## Rules
- Always get exact error messages before proposing fixes
- Reproduce the issue before claiming it's fixed
- Consider edge cases and boundary conditions
"""
)

REVIEW_SKILL = Skill(
    name="review",
    description="Code review following best practices",
    version="1.0.0",
    path=Path("builtin://review"),
    prompt_template="",
    triggers=["review", "code review", "look at", "check"],
    content="""# Code Review Skill

When the user asks you to review code:

## Review Focus Areas

### Correctness
- Does the code do what it's supposed to do?
- Are there off-by-one errors or boundary issues?
- Is error handling complete?

### Design
- Is the code in the right place?
- Are responsibilities properly separated?
- Is there appropriate abstraction?

### Readability
- Are variable/function names clear?
- Is complex logic documented?
- Is the code self-explanatory?

### Performance
- Are there obvious O(n²) or worse patterns?
- Are database queries optimized?
- Is caching used where appropriate?

### Security
- Is user input validated?
- Are there injection vulnerabilities?
- Are secrets properly handled?

## Output Format
For each issue found:
- **File:** path/to/file.py:line
- **Issue:** Description
- **Suggestion:** How to fix

## Rules
- Be constructive, not critical
- Focus on important issues, not style preferences
- Suggest improvements, don't just point out problems
"""
)

def get_builtin_skills() -> list[Skill]:
    """Return all built-in skills."""
    return [TDD_SKILL, DEBUG_SKILL, REVIEW_SKILL]
