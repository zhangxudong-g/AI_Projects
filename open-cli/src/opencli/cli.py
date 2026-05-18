import asyncio
import json
import signal
import sys
import os
import typer
from pathlib import Path
from typing import Optional
from rich.console import Console
from rich.markdown import Markdown

from .agent.engine import AgentEngine, AgentConfig
from .providers.litellm import LiteLLMProvider
from .providers.minimax import MiniMaxProvider
from .messages.messages import Session, AgentType
from .memory.loader import MemoryLoader
from .memory.auto_memory import AutoMemory

cli = typer.Typer(help="open-cli - AI Coding Agent", no_args_is_help=True)
console = Console()


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
    interactive: bool = typer.Option(False, "--interactive", "-i", help="Force interactive mode"),
):
    """Main entry point for open-cli."""
    signal.signal(signal.SIGINT, handle_interrupt)

    if task is None or interactive:
        # Interactive REPL mode
        asyncio.run(run_repl(verbose, provider, model, api_key))
    else:
        # Single task mode
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


async def run_repl(verbose: bool, provider: str, model: Optional[str], api_key: Optional[str]):
    """Interactive REPL mode - loops until user quits."""
    config = load_config(provider)

    effective_api_key = api_key or config.get("api_key", "")
    effective_model = model or config.get("model", "MiniMax-M2.6" if provider == "minimax" else "gpt-4")

    provider_obj = create_provider(provider, effective_api_key, effective_model)
    agent_config = AgentConfig(provider=provider_obj)
    engine = AgentEngine(agent_config)

    session = Session(id="repl-session", agent_type=AgentType.BUILD)

    console.print("[bold blue]open-cli v2.0.0[/bold blue] - Interactive Mode")
    console.print("[dim]Type 'help' for commands, 'exit' or 'quit' to end session[/dim]\n")

    while not shutdown.shutdown_requested:
        try:
            # Get user input using standard input
            user_input = input("\n> ").strip()
        except EOFError:
            console.print("\n[yellow]Goodbye![/yellow]")
            break
        except KeyboardInterrupt:
            console.print("\n[yellow]Goodbye![/yellow]")
            break

        if not user_input:
            continue

        # Handle built-in commands
        if user_input.lower() in ("exit", "quit", "q"):
            console.print("[yellow]Goodbye![/yellow]")
            break
        elif user_input.lower() == "help":
            console.print("""
[bold]Available Commands:[/bold]
  help     - Show this help message
  exit/quit - Exit the REPL
  clear    - Clear the screen
  session  - Show current session ID

[bold]Otherwise:[/bold] Type your message or task naturally.
""")
            continue
        elif user_input.lower() == "clear":
            console.clear()
            continue
        elif user_input.lower() == "session":
            console.print(f"[dim]Session ID: {session.id}[/dim]")
            continue

        # Process user input through agent
        console.print("[dim]Thinking...[/dim]")

        try:
            async for msg in engine.run(user_input, session):
                if msg.type.value == "thinking":
                    if verbose:
                        console.print(f"[dim]Thinking: {msg.content}[/dim]")
                elif msg.type.value == "plan":
                    if msg.content:
                        console.print(f"[cyan]Plan: {msg.content}[/cyan]")
                elif msg.type.value == "tool_call":
                    console.print(f"[yellow]Tool: {msg.tool_name}[/yellow]")
                elif msg.type.value == "tool_result":
                    if msg.success:
                        content = msg.content or ""
                        if len(content) > 200:
                            console.print(f"[green]Result: {content[:200]}...[/green]")
                        else:
                            console.print(f"[green]Result: {content}[/green]")
                    else:
                        console.print(f"[red]Error: {msg.content}[/red]")
                elif msg.type.value == "done":
                    if msg.content:
                        md = Markdown(msg.content)
                        console.print(md)

        except KeyboardInterrupt:
            console.print("\n[yellow]Interrupted.[/yellow]")
            continue
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            if verbose:
                import traceback
                console.print(f"[dim]{traceback.format_exc()}[/dim]")


_DEFAULT_MINIMAX_API_KEY = "sk-cp-q6hyCftIk8An1s5VHPJZYFQOfypT4XVKnIuXoI0rtoqlh8I2h5CE3nbwxwkqErT3cm3CwjL-rGeVvfRiTDCLjHM0wLrTpvxZUPh6uCKWedeUnK0NulTpaPw"
_DEFAULT_MINIMAX_MODEL = "MiniMax-M2.7"


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


# Memory commands sub-app
memory_app = typer.Typer(help="Memory management commands")


@memory_app.command("view")
def memory_view():
    """View current memory contents."""
    loader = MemoryLoader()
    context = loader.build_context()
    if context:
        console.print(context)
    else:
        console.print("[dim]No memory loaded.[/dim]")


@memory_app.command("edit")
def memory_edit():
    """Edit AGENTS.md file."""
    loader = MemoryLoader()
    agents_path = loader.get_user_agents_path()
    if not agents_path.exists():
        agents_path.parent.mkdir(parents=True, exist_ok=True)
        agents_path.write_text("# Project Context\n\n", encoding="utf-8")
    editor = os.environ.get("EDITOR", "notepad")
    os.system(f'"{editor}" "{agents_path}"')


@memory_app.command("clear")
def memory_clear():
    """Clear auto-memory."""
    loader = MemoryLoader()
    auto_memory = AutoMemory.from_loader(loader)
    memory_path = auto_memory.get_memory_path()
    if memory_path.exists():
        memory_path.unlink()
    console.print("[green]Auto-memory cleared.[/green]")


# Init commands sub-app
init_app = typer.Typer(help="Initialize project for open-cli")


@init_app.command("default")
def init_project():
    """Analyze project and create AGENTS.md."""
    project_path = Path.cwd()

    # Detect basic tech stack
    tech_stack = []
    if (project_path / "package.json").exists():
        tech_stack.append("Node.js")
    if (project_path / "requirements.txt").exists():
        tech_stack.append("Python")
    if (project_path / "Cargo.toml").exists():
        tech_stack.append("Rust")
    if not tech_stack:
        tech_stack.append("Unknown")

    content = f"""# Project Context

## Tech Stack
- {", ".join(tech_stack)}

## Project Structure
- (Describe your project structure here)

## Build Commands
- (Add build commands here)

## Coding Standards
- (Add coding standards here)
"""

    agents_path = project_path / "AGENTS.md"
    if agents_path.exists():
        console.print("[yellow]AGENTS.md already exists. Not overwriting.[/yellow]")
    else:
        agents_path.write_text(content, encoding="utf-8")
        console.print(f"[green]Created {agents_path}[/green]")
        console.print("Please edit it with your project details.")


# Register sub-apps
cli.add_typer(memory_app, name="memory")
cli.add_typer(init_app, name="init")


if __name__ == "__main__":
    cli()
