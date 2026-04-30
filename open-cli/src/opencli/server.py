from fastapi import FastAPI

app = FastAPI(title="open-cli Server")


@app.get("/health")
async def health():
    return {"status": "ok"}


def run_server():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
