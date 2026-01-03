#!/usr/bin/env python3
"""Command-line interface for Feel++ Docker factory."""

import sys
from pathlib import Path
from typing import Optional

import click
from rich.console import Console
from rich.table import Table
from rich.syntax import Syntax
from rich.panel import Panel

from .config import Config
from .builder import ImageBuilder
from .validator import Validator

console = Console()


@click.group()
@click.option('--config-dir', type=click.Path(exists=True, path_type=Path), 
              default=Path(__file__).parent.parent / 'config',
              help='Configuration directory')
@click.option('--template-dir', type=click.Path(exists=True, path_type=Path),
              default=Path(__file__).parent.parent / 'templates',
              help='Template directory')
@click.pass_context
def main(ctx, config_dir: Path, template_dir: Path):
    """Feel++ Docker Image Factory - Generate and manage development environment images."""
    ctx.ensure_object(dict)
    
    try:
        ctx.obj['config'] = Config(config_dir)
        ctx.obj['builder'] = ImageBuilder(ctx.obj['config'], template_dir)
        ctx.obj['validator'] = Validator(ctx.obj['config'])
    except Exception as e:
        console.print(f"[red]Error loading configuration:[/red] {e}")
        sys.exit(1)


@main.command()
@click.option('--variant', default='feelpp-env', help='Variant to generate')
@click.option('--dist', help='Specific distribution (e.g., ubuntu:24.04)')
@click.option('--output-dir', type=click.Path(path_type=Path), 
              default=Path.cwd(),
              help='Output directory for generated files')
@click.option('--dry-run', is_flag=True, help='Show what would be generated without writing files')
@click.pass_context
def generate(ctx, variant: str, dist: Optional[str], output_dir: Path, dry_run: bool):
    """Generate Dockerfiles from configuration."""
    config: Config = ctx.obj['config']
    builder: ImageBuilder = ctx.obj['builder']
    
    if variant not in config.variants:
        console.print(f"[red]Error:[/red] Unknown variant '{variant}'")
        console.print(f"Available variants: {', '.join(config.variants.keys())}")
        sys.exit(1)
    
    try:
        if dist:
            # Generate single distribution
            dist_name, version_tag = dist.split(':')
            
            if dry_run:
                content = builder.generate_dockerfile(variant, dist_name, version_tag)
                console.print(Panel(
                    Syntax(content, "dockerfile", theme="monokai"),
                    title=f"Dockerfile for {dist}",
                    border_style="green"
                ))
            else:
                output_subdir = output_dir / f"{dist_name}-{version_tag}-clang++"
                content = builder.generate_dockerfile(
                    variant, dist_name, version_tag, output_subdir
                )
                console.print(f"[green]✓[/green] Generated {output_subdir}/Dockerfile ({len(content)} bytes)")
        else:
            # Generate all distributions
            if dry_run:
                console.print("[yellow]Dry-run mode:[/yellow] Would generate:")
                for dist_spec in config.variants[variant].distributions:
                    console.print(f"  • {dist_spec}")
            else:
                results = builder.generate_all(variant, output_dir)
                
                table = Table(title=f"Generated Dockerfiles for {variant}")
                table.add_column("Distribution", style="cyan")
                table.add_column("Output Directory", style="blue")
                table.add_column("Size", justify="right", style="green")
                
                for result in results:
                    table.add_row(
                        result['dist'],
                        str(result['output_dir']),
                        f"{result['size']:,} bytes"
                    )
                
                console.print(table)
    
    except Exception as e:
        console.print(f"[red]Error generating Dockerfile:[/red] {e}")
        sys.exit(1)


@main.command()
@click.option('--variant', help='Specific variant to show')
@click.pass_context
def show(ctx, variant: Optional[str]):
    """Show configuration details."""
    config: Config = ctx.obj['config']
    
    if variant:
        if variant not in config.variants:
            console.print(f"[red]Error:[/red] Unknown variant '{variant}'")
            sys.exit(1)
        
        var_config = config.variants[variant]
        
        console.print(Panel(
            f"[bold]{var_config.description}[/bold]\n\n"
            f"Layers: {', '.join(var_config.layers)}\n"
            f"OpenMPI: {'enabled' if var_config.enable_openmpi else 'disabled'}\n"
            f"Distributions: {len(var_config.distributions)}",
            title=f"Variant: {variant}",
            border_style="blue"
        ))
        
        # Show distributions
        table = Table(title="Distributions")
        table.add_column("Name", style="cyan")
        table.add_column("Base Image", style="blue")
        table.add_column("Platforms", style="green")
        table.add_column("Experimental", style="yellow")
        
        for dist_spec in var_config.distributions:
            dist_name, version_tag = dist_spec.split(':')
            version = config.get_distribution_version(dist_name, version_tag)
            
            table.add_row(
                dist_spec,
                version.base_image,
                ', '.join(version.platforms),
                "Yes" if version.experimental else "No"
            )
        
        console.print(table)
    else:
        # Show all variants
        table = Table(title="Available Variants")
        table.add_column("Name", style="cyan")
        table.add_column("Description", style="blue")
        table.add_column("Distributions", justify="right", style="green")
        
        for name, var_config in config.variants.items():
            table.add_row(
                name,
                var_config.description,
                str(len(var_config.distributions))
            )
        
        console.print(table)


@main.command()
@click.pass_context
def validate(ctx):
    """Validate configuration files."""
    validator: Validator = ctx.obj['validator']
    
    console.print("[blue]Validating configuration...[/blue]")
    
    errors = validator.validate_all()
    
    if errors:
        console.print(f"\n[red]Found {len(errors)} error(s):[/red]")
        for error in errors:
            console.print(f"  • {error}")
        sys.exit(1)
    else:
        console.print("[green]✓ Configuration is valid[/green]")


@main.command()
@click.option('--variant', default='feelpp-env', help='Variant to generate matrix for')
@click.option('--format', type=click.Choice(['table', 'json', 'yaml']), 
              default='table', help='Output format')
@click.pass_context
def matrix(ctx, variant: str, format: str):
    """Generate build matrix for CI."""
    config: Config = ctx.obj['config']
    
    try:
        build_matrix = config.get_build_matrix(variant)
        
        if format == 'table':
            table = Table(title=f"Build Matrix for {variant}")
            if build_matrix:
                # Add columns dynamically from first item
                for key in build_matrix[0].keys():
                    table.add_column(key.replace('_', ' ').title())
                
                for item in build_matrix:
                    table.add_row(*[str(v) for v in item.values()])
            
            console.print(table)
        
        elif format == 'json':
            import json
            console.print(json.dumps(build_matrix, indent=2))
        
        elif format == 'yaml':
            import yaml
            console.print(yaml.dump({'matrix': {'include': build_matrix}}, 
                                   default_flow_style=False))
    
    except Exception as e:
        console.print(f"[red]Error generating matrix:[/red] {e}")
        sys.exit(1)


@main.command()
@click.option('--variant', default='feelpp-env', help='Variant to update CI for')
@click.option('--workflow-file', type=click.Path(path_type=Path),
              default=Path.cwd() / '.github' / 'workflows' / 'feelpp-env.yml',
              help='Workflow file to update')
@click.pass_context
def update_ci(ctx, variant: str, workflow_file: Path):
    """Update GitHub Actions workflow with current build matrix."""
    config: Config = ctx.obj['config']
    
    console.print(f"[yellow]Not implemented yet[/yellow]")
    console.print(f"Would update {workflow_file} with matrix for {variant}")
    
    # TODO: Implement workflow file update
    # - Read existing workflow
    # - Replace matrix section
    # - Write back with preserved formatting


if __name__ == '__main__':
    main(obj={})
