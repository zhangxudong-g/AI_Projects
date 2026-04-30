import os
from pathlib import Path
from typing import List, Dict, Any
from core.security import SecurityBoundary, SecurityError

class FileTool:
    def __init__(self, security: SecurityBoundary):
        self.security = security

    def read_file(self, file_path: str) -> str:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if not path.is_file():
            raise ValueError(f"Not a file: {file_path}")
        return path.read_text(encoding="utf-8")

    def write_file(self, file_path: str, content: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return {"success": True, "path": str(path), "bytes": len(content)}

    def list_directory(self, dir_path: str) -> List[str]:
        path = self.security.validate_path(Path(dir_path))
        if not path.exists():
            raise FileNotFoundError(f"Directory not found: {dir_path}")
        if not path.is_dir():
            raise ValueError(f"Not a directory: {dir_path}")

        entries = []
        for item in sorted(path.iterdir()):
            name = item.name
            if item.is_dir():
                name += "/"
            entries.append(name)
        return entries

    def list_directory_formatted(self, dir_path: str = ".") -> str:
        """List directory in a formatted way, avoiding Windows encoding issues."""
        try:
            path = Path(dir_path) if dir_path else Path.cwd()
            path = self.security.validate_path(path)
        except SecurityError:
            return f"Error: Access denied to {dir_path}"

        if not path.exists():
            return f"Directory not found: {dir_path}"
        if not path.is_dir():
            return f"Not a directory: {dir_path}"

        lines = [f"Directory: {path.absolute()}", ""]
        items = []
        total_files = 0
        total_dirs = 0

        for item in sorted(path.iterdir()):
            try:
                stat = item.stat()
                size = stat.st_size if item.is_file() else 0
                item_type = "<DIR>" if item.is_dir() else str(size)
                items.append((item.name, item_type))
                if item.is_dir():
                    total_dirs += 1
                else:
                    total_files += 1
            except PermissionError:
                items.append((item.name + " [PERMISSION DENIED]", ""))
            except Exception as e:
                items.append((item.name + f" [ERROR: {e}]", ""))

        max_name_len = max(len(name) for name, _ in items) if items else 20
        for name, item_type in items:
            lines.append(f"  {name:<{max_name_len}} {item_type}")

        lines.append("")
        lines.append(f"{total_dirs} directories, {total_files} files")

        return "\n".join(lines)

    def create_directory(self, dir_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(dir_path))
        path.mkdir(parents=True, exist_ok=True)
        return {"success": True, "path": str(path)}

    def delete_file(self, file_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        path.unlink()
        return {"success": True, "path": str(path)}

    def read_pdf(self, file_path: str) -> str:
        """Read PDF file and return text content."""
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if path.suffix.lower() != ".pdf":
            raise ValueError(f"Not a PDF file: {file_path}")

        try:
            import fitz  # PyMuPDF
        except ImportError:
            return "Error: PyMuPDF not installed. Run: pip install pymupdf"

        try:
            doc = fitz.open(str(path))
            text_parts = []
            for page_num in range(len(doc)):
                page = doc[page_num]
                text = page.get_text()
                if text.strip():
                    text_parts.append(f"=== Page {page_num + 1} ===\n{text}")
            doc.close()
            if not text_parts:
                return "PDF is empty or contains no extractable text."
            return "\n\n".join(text_parts)
        except Exception as e:
            return f"Error reading PDF: {str(e)}"

    def fetch_url(self, url: str) -> str:
        """Fetch content from a URL."""
        try:
            import requests
        except ImportError:
            return "Error: requests not installed. Run: pip install requests"

        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            content_type = response.headers.get('content-type', '')

            if 'text/html' in content_type:
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(response.text, 'html.parser')
                for script in soup(['script', 'style']):
                    script.decompose()
                text = soup.get_text(separator='\n', strip=True)
                lines = [line for line in text.split('\n') if line.strip()]
                return '\n'.join(lines[:200])
            elif 'application/json' in content_type:
                import json
                return json.dumps(response.json(), indent=2, ensure_ascii=False)[:2000]
            else:
                return response.text[:2000]
        except Exception as e:
            return f"Error fetching URL: {str(e)}"

    def read_image(self, file_path: str) -> str:
        """Read image file and describe it using OCR."""
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if not path.suffix.lower() in ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']:
            raise ValueError(f"Not an image file: {file_path}")

        try:
            from PIL import Image
            import pytesseract
        except ImportError:
            return "Error: PIL or pytesseract not installed. Run: pip install pillow pytesseract"

        try:
            image = Image.open(str(path))
            text = pytesseract.image_to_string(image, lang='eng+chi')
            if not text.strip():
                return "No text found in image."
            return f"Image size: {image.size}\nOCR Result:\n{text}"
        except Exception as e:
            return f"Error reading image: {str(e)}"

    def grep_search(self, pattern: str, dir_path: str = ".") -> str:
        """Search for pattern in files."""
        import re
        path = self.security.validate_path(Path(dir_path))
        if not path.exists():
            return f"Directory not found: {dir_path}"

        matches = []
        try:
            regex = re.compile(pattern, re.IGNORECASE)
        except re.error:
            regex = re.compile(re.escape(pattern), re.IGNORECASE)

        for file_path in path.rglob('*'):
            if file_path.is_file() and file_path.suffix in ['.py', '.js', '.ts', '.txt', '.md', '.json', '.yaml', '.yml', '.toml', '.cfg', '.ini', '.html', '.css']:
                try:
                    content = file_path.read_text(encoding='utf-8', errors='ignore')
                    for line_num, line in enumerate(content.split('\n'), 1):
                        if regex.search(line):
                            matches.append(f"{file_path}:{line_num}: {line.strip()[:100]}")
                except Exception:
                    pass

        if not matches:
            return f"No matches found for '{pattern}' in {dir_path}"
        return f"Found {len(matches)} matches:\n\n" + '\n'.join(matches[:50])

    def format_json(self, content: str) -> str:
        """Format JSON string."""
        import json
        try:
            parsed = json.loads(content)
            return json.dumps(parsed, indent=2, ensure_ascii=False)
        except json.JSONDecodeError as e:
            return f"Invalid JSON: {str(e)}"