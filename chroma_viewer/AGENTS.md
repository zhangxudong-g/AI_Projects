# Agent Guidelines

This document provides guidelines for coding agents working in this repository.

## Project Overview

ChromaDB Viewer - A bilingual (Chinese/English) toolset for inspecting and searching ChromaDB vector databases. Includes both CLI and Web interfaces.

## Build/Lint/Test Commands

### Running the Project

```bash
# CLI Tool - View ChromaDB contents
python view_chroma_db.py --project <project_name>
python view_chroma_db.py --project agent3 --search "function"
python view_chroma_db.py --list-projects

# Web Interface
cd chroma_web_viewer
python app.py
# Then open http://localhost:5000

# Test ChromaDB connection
python test_connection.py

# Create test database
python create_test_db.py
```

### Testing

**No formal test framework configured.** When adding tests, use standard Python conventions:
- Place test files alongside code files (e.g., `test_*.py` in project root)
- Use `unittest` or `pytest` (add to requirements.txt if needed)
- Run single test: `python -m pytest tests/test_module.py::test_function`

### Installation

```bash
# For CLI tool
pip install chromadb

# For web viewer
cd chroma_web_viewer
pip install -r requirements.txt  # Flask==2.3.3, chromadb==0.4.14
```

### Linting

**No linting configured.** Recommended tools to add:
- `black` for formatting
- `flake8` for linting
- `mypy` for type checking

## Code Style Guidelines

### Python

#### File Structure
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module docstring (Google-style or reST)
Brief description.
"""

# Standard library imports first
import argparse
import json
import os
from pathlib import Path

# Third-party imports second
import chromadb
from chromadb.config import Settings
from flask import Flask, render_template, request, jsonify
```

#### Naming Conventions
- **Functions/Methods**: `snake_case` - e.g., `view_chroma_contents()`, `search_chroma_contents()`
- **Classes**: `PascalCase` - e.g., `DataProcessor`, `QueryEngine`
- **Variables**: `snake_case` - e.g., `db_path`, `collection_name`, `query_text`
- **Constants**: `UPPER_SNAKE_CASE` - e.g., `MAX_CONNECTIONS`, `DEFAULT_LIMIT`
- **Private members**: Leading underscore - e.g., `_internal_method`

#### Docstrings
Use descriptive docstrings for all public functions/classes:
```python
def view_chroma_contents(db_path, collection_name="code_symbols", limit=10):
    """
    View ChromaDB contents.

    Args:
        db_path: Path to ChromaDB database
        collection_name: Name of collection to view (default: "code_symbols")
        limit: Maximum number of documents to display

    Returns:
        bool: True if successful, False otherwise
    """
```

#### Error Handling
- Use try-except blocks for all I/O and external API calls
- Return boolean success indicators for CLI tools
- Return error dictionaries with "error" key for APIs: `{"error": "error message"}`
- Include context in error messages

```python
try:
    client = chromadb.PersistentClient(path=db_path)
except Exception as e:
    print(f"[ERROR] 错误: {str(e)}")
    return False
```

#### CLI Output Format
Use labeled prefixes for console output:
```python
print("[COLLECTION] 可用集合:")
print("[STATS] 集合包含 X 个文档")
print("[PREVIEW] 前 X 个样本:")
print("[DOC] 文档内容:")
print("[META] 元数据:")
print("[ERROR] 错误:")
print("[DONE] 操作完成")
```

#### Type Hints (Optional but Recommended)
```python
from typing import Optional, List, Dict, Any

def search_chroma_contents(
    db_path: str,
    query_text: str,
    collection_name: str = "code_symbols",
    n_results: int = 5
) -> bool:
    """Search ChromaDB contents."""
```

### JavaScript (Web Interface)

#### Naming Conventions
- **Functions/Methods**: `camelCase` - e.g., `viewData()`, `handleSearch()`
- **Variables**: `camelCase` - e.g., `dbPath`, `collectionName`, `searchQuery`
- **Constants**: `UPPER_SNAKE_CASE` - e.g., `MAX_RESULTS`, `API_ENDPOINT`
- **DOM Elements**: camelCase with ID reference - e.g., `document.getElementById('dbPath')`

#### Async/Await Pattern
```javascript
async function viewData() {
    try {
        const response = await fetch('/api/view', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                db_path: dbPath,
                collection_name: collectionName,
                limit: parseInt(limit)
            })
        });
        const data = await response.json();
        if (data.error) {
            showError(data.error);
            return;
        }
        displayResults(data);
    } catch (error) {
        showError(`错误: ${error.message}`);
    }
}
```

#### Event Listeners
```javascript
document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('viewBtn').addEventListener('click', viewData);
    document.getElementById('searchBtn').addEventListener('click', searchData);
});
```

### HTML/CSS

#### Naming (kebab-case)
```html
<!-- IDs and classes use kebab-case -->
<div id="db-path-select" class="input-group">
<button id="view-btn" class="btn-primary">
<div class="card metadata-section">
```

#### CSS Organization
- Use CSS custom properties (variables) for theming
- Organize by component/section
- Support multiple themes (light, dark, blue, green)

```css
:root {
    --bg-color: #f5f5f5;
    --button-bg: #3498db;
    --button-hover: #2980b9;
}
```

## Project Structure

```
chroma_viewer/
├── view_chroma_db.py          # Main CLI tool
├── test_connection.py          # Connection test script
├── create_test_db.py           # Test database creator
├── chroma_web_viewer/          # Web interface
│   ├── app.py                  # Flask application
│   ├── requirements.txt        # Web dependencies
│   ├── static/
│   │   ├── script.js          # Frontend logic
│   │   └── styles.css         # Styling with themes
│   └── templates/
│       └── index.html         # Main page
└── chroma_env/                 # Virtual environment (do not edit)
```

## Important Notes

- **Bilingual Project**: Messages and documentation are in Chinese and English. When adding user-facing strings, provide both languages when appropriate
- **ChromaDB Version**: Currently using ChromaDB 0.4.14. Be aware of API differences between 0.3.x and 0.4.x
- **Persistence**: ChromaDB uses `PersistentClient` with `duckdb+parquet` backend
- **Path Handling**: Handle both absolute and relative paths. Use `os.path.isabs()`, `os.path.abspath()`, and `Path.expanduser()`
- **No Package Manager**: Project does not use npm, yarn, poetry, or similar. Dependencies installed via pip
- **Test Databases**: `test_chroma_db/`, `test_new_db/` directories contain test data

## Adding New Features

1. CLI tools: Follow `view_chroma_db.py` patterns with argparse and labeled output
2. Web routes: Add to `app.py` following existing route pattern: `@app.route('/api/endpoint', methods=['POST'])`
3. Frontend: Add functions to `script.js`, styles to `styles.css`
4. Update this file if new build/lint/test commands are added
