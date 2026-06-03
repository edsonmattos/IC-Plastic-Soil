"""CLI entry point — python -m pipeline <command>"""
import logging
import sys

import click

from .db.migrations import create_tables, drop_all_tables
from .pipeline import list_projects, load_project, run_all, sync_sheets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
    datefmt="%H:%M:%S",
)


@click.group()
def cli():
    """MPB Pipeline — loads QIIME2 results into PostgreSQL."""


@cli.command("init-db")
def cmd_init_db():
    """Create (or update) database schema."""
    create_tables()
    click.echo("Schema applied.")


@cli.command("drop-db")
@click.confirmation_option(prompt="This will DROP all tables. Continue?")
def cmd_drop_db():
    """Drop all pipeline tables (irreversible!)."""
    drop_all_tables(confirm=True)
    click.echo("All tables dropped.")


@cli.command("list")
def cmd_list():
    """List all available projects."""
    for name in list_projects():
        click.echo(name)


@cli.command("run")
@click.option(
    "--project", "-p",
    multiple=True,
    help="Project name(s) to load (e.g. projeto-01). Repeat for multiple.",
)
@click.option(
    "--all", "all_projects",
    is_flag=True,
    help="Load all projects and sync Sheets.",
)
@click.option(
    "--skip-sheets",
    is_flag=True,
    default=False,
    help="Skip Google Sheets sync step.",
)
def cmd_run(project, all_projects, skip_sheets):
    """Run the ETL pipeline for one or more projects."""
    if all_projects:
        run_all()
        return

    if not project:
        click.echo("Specify --project <name> or --all.", err=True)
        sys.exit(1)

    for name in project:
        load_project(name)

    if not skip_sheets:
        sync_sheets()


@cli.command("sync-sheets")
def cmd_sync_sheets():
    """Pull Google Sheets metadata and update dimensions/facts."""
    sync_sheets()
    click.echo("Sheets sync complete.")


if __name__ == "__main__":
    cli()
