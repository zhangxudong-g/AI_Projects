import asyncio
import json
import signal
import sys
import typer
from typing import Optional

from .agent.engine import AgentEngine, AgentConfig
from .providers.litellm import LiteLLMProvider
from .types.messages import Session, AgentType

cli = typer.Typer(help="open-cli - AI Coding Agent")

class GracefulShutdown:
    def __init__(self):
        self.shutdown_requested = False

shutdown = GracefulShutdown()

def handle_interrupt(signum, frame):
    shutdown.shutdown_requested = True
    typer.echo("\nInterrupted by user. Shutting down...", err=True)
    raise KeyboardInterrupt

@cli.command()
def main(
    task: Optional[str] = typer.Argument(None, help="Task description to execute"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Main entry point for open-cli."""
    if task is None:
        typer.echo("open-cli v2.0.0")
        typer.echo("Usage: opencli <task description>")
        typer.echo("       opencli --help")
        return

    signal.signal(signal.SIGINT, handle_interrupt)

    try:
        asyncio.run(run_task(task, verbose))
    except KeyboardInterrupt:
        pass

async def run_task(task: str, verbose: bool):
    config = load_config()
    provider = LiteLLMProvider(
        api_key=config.get("LITELLM_API_KEY", ""),
        default_model=config.get("LITELLM_MODEL", "gpt-4")
    )
    agent_config = AgentConfig(provider=provider)
    engine = AgentEngine(agent_config)

    session = Session(id="cli-session", agent_type=AgentType.BUILD)

    async for msg in engine.run(task, session):
        output = json.dumps(msg.to_dict(), ensure_ascii=False)
        if verbose:
            typer.echo(f"[{msg.type.value}] {msg.content}")
        else:
            print(output, flush=True)

def load_config() -> dict:
    import os
    return {
        "LITELLM_API_KEY": os.getenv("LITELLM_API_KEY", ""),
        "LITELLM_MODEL": os.getenv("LITELLM_MODEL", "gpt-4")
    }

if __name__ == "__main__":
    cli()
