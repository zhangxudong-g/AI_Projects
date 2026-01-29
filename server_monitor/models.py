from pydantic import BaseModel
from datetime import datetime
from typing import Dict, List, Optional

class ApiStats(BaseModel):
    total_requests: int
    active_connections: int
    response_times: Dict[str, float]
    error_rates: Dict[str, float]