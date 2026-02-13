import asyncio
import websockets
import json

async def test_single_server_websocket():
    """Test WebSocket connection for a single server"""
    uri = "ws://localhost:9000/ws/Server%20-%20ps"  # URL encoded server name
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to single server WebSocket")
            
            # Receive a few messages
            for i in range(3):
                data = await websocket.recv()
                
                # Check if data is binary (compressed) or text (JSON)
                if isinstance(data, bytes):
                    print(f"Received binary data (likely compressed): {len(data)} bytes")
                else:
                    parsed_data = json.loads(data)
                    print(f"Received JSON data keys: {list(parsed_data.keys()) if isinstance(parsed_data, dict) else 'Not a dict'}")
                    if isinstance(parsed_data, dict) and 'error' in parsed_data:
                        print(f"  Error: {parsed_data['error']}")
                    elif isinstance(parsed_data, dict):
                        print(f"  Server: {parsed_data.get('server_name', 'Unknown')}, Timestamp: {parsed_data.get('timestamp', 'N/A')}")
                    
    except Exception as e:
        print(f"Error connecting to single server WebSocket: {e}")

async def test_all_servers_websocket():
    """Test WebSocket connection for all servers"""
    uri = "ws://localhost:9000/ws-all"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to all servers WebSocket")
            
            # Receive a few messages
            for i in range(3):
                data = await websocket.recv()
                
                # Check if data is binary (compressed) or text (JSON)
                if isinstance(data, bytes):
                    print(f"Received binary data (likely compressed): {len(data)} bytes")
                else:
                    parsed_data = json.loads(data)
                    print(f"Received JSON data for {len(parsed_data)} servers")
                    for server_name, server_data in parsed_data.items():
                        if isinstance(server_data, dict) and 'error' in server_data:
                            print(f"  {server_name}: Error - {server_data['error']}")
                        else:
                            print(f"  {server_name}: OK, Timestamp: {server_data.get('timestamp', 'N/A')}")
                    
    except Exception as e:
        print(f"Error connecting to all servers WebSocket: {e}")

async def test_cli_websocket():
    """Test WebSocket connection for CLI functionality"""
    uri = "ws://localhost:9000/ws/cli/Server%20-%20ps"  # URL encoded server name
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to CLI WebSocket")
            
            # Send a simple command
            command = {
                "command": "echo 'Hello from WebSocket CLI'",
                "use_sudo": False
            }
            await websocket.send(json.dumps(command))
            
            # Receive response
            response = await websocket.recv()
            print(f"CLI response: {response}")
                    
    except Exception as e:
        print(f"Error connecting to CLI WebSocket: {e}")

async def main():
    print("Testing WebSocket connections...")
    print("\n1. Testing single server WebSocket:")
    await test_single_server_websocket()
    
    print("\n2. Testing all servers WebSocket:")
    await test_all_servers_websocket()
    
    print("\n3. Testing CLI WebSocket:")
    await test_cli_websocket()

if __name__ == "__main__":
    asyncio.run(main())