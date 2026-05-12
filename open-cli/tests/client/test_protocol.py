import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.client.protocol import ClientProtocol


class TestClientProtocol:
    def test_init_default_url(self):
        protocol = ClientProtocol()
        assert protocol.server_url == "http://localhost:8000"

    def test_init_custom_url(self):
        protocol = ClientProtocol(server_url="http://custom:9000")
        assert protocol.server_url == "http://custom:9000"

    @pytest.mark.asyncio
    async def test_connect_failure(self):
        """Test connect returns False when server is unavailable"""
        protocol = ClientProtocol(server_url="http://localhost:9999")
        result = await protocol.connect()
        assert result is False

    @pytest.mark.asyncio
    async def test_create_session_returns_none_when_unavailable(self):
        """Test create_session returns None when server is unavailable"""
        protocol = ClientProtocol(server_url="http://localhost:9999")
        result = await protocol.create_session()
        assert result is None
