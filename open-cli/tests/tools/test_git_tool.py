import pytest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

# Skip these tests - they test the old API structure
pytest.skip("Old API structure tests - see test_registry.py for new tests", allow_module_level=True)
