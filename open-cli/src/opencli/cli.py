import typer

cli = typer.Typer(help="open-cli - AI Coding Agent")


@cli.command()
def main():
    """Main entry point for open-cli."""
    typer.echo("open-cli v2.0.0")


if __name__ == "__main__":
    cli()
