import asyncio
import json
import signal
import sys
import os
import typer
from typing import Optional

from .agent.engine import AgentEngine, AgentConfig
from .providers.litellm import LiteLLMProvider
from .providers.minimax import MiniMaxProvider
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


def create_provider(provider_name: str, api_key: str, model: str):
    if provider_name == "minimax":
        return MiniMaxProvider(api_key=api_key, default_model=model)
    elif provider_name == "litellm":
        return LiteLLMProvider(api_key=api_key, default_model=model)
    else:
        raise ValueError(f"Unknown provider: {provider_name}")


@cli.command()
def main(
    task: Optional[str] = typer.Argument(None, help="Task description to execute"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
    provider: str = typer.Option("minimax", "--provider", show_default=True, help="Provider: minimax or litellm"),
    model: Optional[str] = typer.Option(None, "--model", help="Model name"),
    api_key: Optional[str] = typer.Option(None, "--api-key", help="API key"),
):
    """Main entry point for open-cli."""
    if task is None:
        typer.echo("open-cli v2.0.0")
        typer.echo("Usage: opencli <task description>")
        typer.echo("       opencli --help")
        return

    signal.signal(signal.SIGINT, handle_interrupt)

    try:
        asyncio.run(run_task(task, verbose, provider, model, api_key))
    except KeyboardInterrupt:
        pass


async def run_task(task: str, verbose: bool, provider: str, model: Optional[str], api_key: Optional[str]):
    config = load_config(provider)

    effective_api_key = api_key or config.get("api_key", "")
    effective_model = model or config.get("model", "MiniMax-M2.6" if provider == "minimax" else "gpt-4")

    provider_obj = create_provider(provider, effective_api_key, effective_model)
    agent_config = AgentConfig(provider=provider_obj)
    engine = AgentEngine(agent_config)

    session = Session(id="cli-session", agent_type=AgentType.BUILD)

    async for msg in engine.run(task, session):
        output = json.dumps(msg.to_dict(), ensure_ascii=False)
        if verbose:
            typer.echo(f"[{msg.type.value}] {msg.content}")
        else:
            print(output, flush=True)


_DEFAULT_MINIMAX_API_KEY = "sk-cp-q6hyCftIk8An1s5VHPJZYFQOfypT4XVKnIuXoI0rtoqlh8I2h5CE3nbwxwkqErT3cm3CwjL-rGeVvfRiTDCLjHM0wLrTpvxZUPh6uCKWedeUnK0NulTpaPw"
_DEFAULT_MINIMAX_MODEL = "MiniMax-M2.6"


def load_config(provider: str) -> dict:
    if provider == "minimax":
        return {
            "api_key": os.getenv("MINIMAX_API_KEY", _DEFAULT_MINIMAX_API_KEY),
            "model": os.getenv("MINIMAX_MODEL", _DEFAULT_MINIMAX_MODEL)
        }
    else:
        return {
            "api_key": os.getenv("LITELLM_API_KEY", ""),
            "model": os.getenv("LITELLM_MODEL", "gpt-4")
        }


if __name__ == "__main__":
    cli()
