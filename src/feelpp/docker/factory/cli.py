#!/usr/bin/env python3
"""Command-line interface for Feel++ Docker factory."""

import os
import sys
import subprocess
import shlex
from pathlib import Path
from typing import Optional, Tuple

import click
from rich.console import Console
from rich.table import Table
from rich.syntax import Syntax
from rich.panel import Panel

from .config import Config
from .builder import ImageBuilder
from .validator import Validator

console = Console()


def _detect_factory_root() -> Path:
    """Locate the directory containing factory config/templates."""
    env_root = os.getenv("FEELPP_FACTORY_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()

    cwd = Path.cwd().resolve()
    search_roots = [cwd, *cwd.parents]

    for root in search_roots:
        # Case 1: commands executed from feelpp-env/
        if (root / "config").is_dir() and (root / "templates").is_dir():
            return root

        # Case 2: commands executed from repository root (contains feelpp-env/)
        candidate = root / "feelpp-env"
        if (candidate / "config").is_dir() and (candidate / "templates").is_dir():
            return candidate

    # Conservative fallback; explicit --config-dir/--template-dir can override.
    return cwd / "feelpp-env"


DEFAULT_FACTORY_ROOT = _detect_factory_root()
DEFAULT_CONFIG_DIR = DEFAULT_FACTORY_ROOT / "config"
DEFAULT_TEMPLATE_DIR = DEFAULT_FACTORY_ROOT / "templates"


def _detect_repo_root(factory_root: Path) -> Path:
    """Locate repository root (expects docker-bake.hcl)."""
    factory_root = factory_root.resolve()
    for root in [factory_root, *factory_root.parents]:
        if (root / "docker-bake.hcl").is_file():
            return root
    return factory_root.parent


DEFAULT_REPO_ROOT = _detect_repo_root(DEFAULT_FACTORY_ROOT)
DEFAULT_BAKE_FILE = DEFAULT_REPO_ROOT / "docker-bake.hcl"


def _parse_dist_spec(dist: str) -> Tuple[str, str]:
    """Parse distribution spec and return (name, version)."""
    if ":" not in dist:
        raise ValueError(f"DIST must be in format 'name:version' (got '{dist}')")

    dist_name, version_tag = dist.split(":", 1)
    dist_name = dist_name.strip()
    version_tag = version_tag.strip()

    if not dist_name or not version_tag:
        raise ValueError(f"DIST must be in format 'name:version' (got '{dist}')")

    return dist_name, version_tag


def _dist_tag(dist_name: str, version_tag: str) -> str:
    return f"{dist_name}-{version_tag}"


def _run_command(
    cmd: list[str],
    *,
    cwd: Optional[Path] = None,
    env: Optional[dict] = None,
) -> int:
    """Run shell command and stream output."""
    command_str = " ".join(shlex.quote(c) for c in cmd)
    console.print(f"[dim]$ {command_str}[/dim]")
    result = subprocess.run(cmd, check=False, cwd=cwd, env=env)
    return result.returncode


def _resolve_registry_credentials(
    token: Optional[str],
    user: Optional[str],
) -> Tuple[str, str]:
    """Resolve registry credentials from CLI args or environment."""
    resolved_token = token or os.getenv("CR_PAT") or os.getenv("GITHUB_TOKEN")
    if not resolved_token:
        raise ValueError(
            "GitHub token required. Set CR_PAT or GITHUB_TOKEN, or pass --token."
        )

    resolved_user = user or os.getenv("GITHUB_ACTOR") or os.getenv("USER")
    if not resolved_user:
        raise ValueError(
            "Username required. Set GITHUB_ACTOR/USER, or pass --user."
        )

    return resolved_user, resolved_token


def _docker_login(registry: str, user: str, token: str) -> None:
    """Authenticate Docker client against a registry."""
    try:
        result = subprocess.run(
            ["docker", "login", registry, "-u", user, "--password-stdin"],
            input=token.encode(),
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise FileNotFoundError("Docker command not found. Is Docker installed?") from exc

    if result.returncode != 0:
        stderr = result.stderr.decode(errors="replace").strip()
        raise RuntimeError(stderr or f"docker login failed with exit code {result.returncode}")


def _build_with_bake(
    *,
    config: Config,
    builder: ImageBuilder,
    repo_root: Path,
    bake_file: Path,
    dist: str,
    variant: str,
    tag: Optional[str],
    platform: Optional[str],
    no_cache: bool,
    output_dir: Path,
    load: bool,
    push: bool,
) -> str:
    """Generate Dockerfile and build feelpp-env image with docker buildx bake."""
    if variant not in config.variants:
        raise ValueError(
            f"Unknown variant '{variant}'. Available variants: {', '.join(config.variants.keys())}"
        )

    dist_name, version_tag = _parse_dist_spec(dist)
    config.get_distribution_version(dist_name, version_tag)  # validates dist/version
    dist_dash = _dist_tag(dist_name, version_tag)
    dist_spec = f"{dist_name}:{version_tag}"

    if dist_spec not in config.variants[variant].distributions:
        console.print(
            f"[yellow]Warning:[/yellow] {dist_spec} is not listed in variant '{variant}' distributions"
        )

    output_dir = output_dir.resolve()
    dockerfile_dir = output_dir / f"{dist_dash}-clang++"
    builder.generate_dockerfile(variant, dist_name, version_tag, dockerfile_dir)

    if tag is None:
        tag = f"{variant}:{dist_dash}"

    if push and load:
        raise ValueError("Cannot use --push and --load together")
    if load and platform and "," in platform:
        raise ValueError("--load supports a single platform; remove extra platforms or disable --load")

    if not bake_file.exists():
        raise FileNotFoundError(f"Bake file not found: {bake_file}")

    build_cmd = [
        "docker",
        "buildx",
        "bake",
        "--file",
        str(bake_file),
        "feelpp-env",
        "--set",
        f"feelpp-env.context={dockerfile_dir}",
        "--set",
        f"feelpp-env.tags={tag}",
    ]

    if platform:
        # Some buildx/bake versions accept `platform` but reject `platforms`.
        build_cmd.extend(["--set", f"feelpp-env.platform={platform}"])
    if no_cache:
        build_cmd.append("--no-cache")
    if load:
        build_cmd.extend(["--set", "feelpp-env.output=type=docker"])
    if push:
        build_cmd.append("--push")

    env = os.environ.copy()
    env["DIST"] = dist_dash

    console.print("\n[blue]Building Docker image with bake:[/blue]")
    console.print(f"  Distribution: {dist}")
    console.print(f"  Variant: {variant}")
    console.print(f"  Tag: {tag}")
    console.print(f"  Docker context: {dockerfile_dir}")
    console.print(f"  Bake file: {bake_file}")
    if platform:
        console.print(f"  Platform(s): {platform}")
    if push:
        console.print("  Push: enabled")
    elif load:
        console.print("  Load: enabled")
    console.print()

    code = _run_command(build_cmd, cwd=repo_root, env=env)
    if code != 0:
        raise RuntimeError(f"Build failed with exit code {code}")

    return tag


@click.group()
@click.option('--config-dir', type=click.Path(exists=True, path_type=Path), 
              default=DEFAULT_CONFIG_DIR,
              help='Configuration directory')
@click.option('--template-dir', type=click.Path(exists=True, path_type=Path),
              default=DEFAULT_TEMPLATE_DIR,
              help='Template directory')
@click.pass_context
def main(ctx, config_dir: Path, template_dir: Path):
    """Feel++ Docker Image Factory - Generate and manage development environment images."""
    ctx.ensure_object(dict)
    
    try:
        factory_root = config_dir.resolve().parent
        repo_root = _detect_repo_root(factory_root)
        bake_file = repo_root / "docker-bake.hcl"

        ctx.obj['factory_root'] = factory_root
        ctx.obj['repo_root'] = repo_root
        ctx.obj['bake_file'] = bake_file
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
            dist_name, version_tag = _parse_dist_spec(dist)
            config.get_distribution_version(dist_name, version_tag)
            
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
@click.argument('dist', required=True)
@click.option('--variant', default='feelpp-env', help='Variant to build')
@click.option('--tag', help='Docker tag (default: feelpp-env:DIST-VERSION)')
@click.option('--platform', help='Platform to build for (e.g., linux/amd64)')
@click.option('--no-cache', is_flag=True, help='Build without using cache')
@click.option('--load/--no-load', default=True,
              help='Load image into local Docker daemon (default: enabled)')
@click.option('--push', is_flag=True, help='Push image directly to registry')
@click.option('--output-dir', type=click.Path(path_type=Path), 
              default=DEFAULT_FACTORY_ROOT,
              help='Directory containing generated Dockerfiles')
@click.pass_context
def build(ctx, dist: str, variant: str, tag: Optional[str], 
         platform: Optional[str], no_cache: bool, load: bool, push: bool, output_dir: Path):
    """Generate and build image with docker buildx bake.

    DIST format: `name:version` (for example: `ubuntu:24.04`, `debian:13`).

    \b
    Examples:
      feelpp-factory build ubuntu:24.04
      feelpp-factory build debian:13 --tag test:debian-13
      feelpp-factory build ubuntu:24.04 --push --no-load
      feelpp-factory build fedora:42 --no-cache
    """
    config: Config = ctx.obj['config']
    builder: ImageBuilder = ctx.obj['builder']
    repo_root: Path = ctx.obj['repo_root']
    bake_file: Path = ctx.obj['bake_file']

    try:
        image_tag = _build_with_bake(
            config=config,
            builder=builder,
            repo_root=repo_root,
            bake_file=bake_file,
            dist=dist,
            variant=variant,
            tag=tag,
            platform=platform,
            no_cache=no_cache,
            output_dir=output_dir,
            load=load,
            push=push,
        )
        console.print(f"\n[green]✓ Successfully built {image_tag}[/green]")
        if load and not push:
            console.print("\nTo run the image:")
            console.print(f"  docker run -it --rm {image_tag}")
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except RuntimeError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        console.print("\n[yellow]Build interrupted by user[/yellow]")
        sys.exit(130)


@main.command()
@click.argument('dist', required=True)
@click.option('--variant', default='feelpp-env', help='Variant to test')
@click.option('--tag', help='Docker tag to test (default: feelpp-env:DIST-VERSION)')
@click.option('--platform', default='linux/amd64',
              help='Platform for build step (default: linux/amd64)')
@click.option('--no-cache', is_flag=True, help='Build without using cache')
@click.option('--skip-build', is_flag=True, help='Skip build and test existing local image')
@click.option('--output-dir', type=click.Path(path_type=Path),
              default=DEFAULT_FACTORY_ROOT,
              help='Directory containing generated Dockerfiles')
@click.pass_context
def test(ctx, dist: str, variant: str, tag: Optional[str], platform: str,
         no_cache: bool, skip_build: bool, output_dir: Path):
    """Build (optional) and run smoke tests inside the image.

    Current smoke tests:
    - `import petsc4py, slepc4py`
    - print module paths for quick diagnostics
    """
    config: Config = ctx.obj['config']
    builder: ImageBuilder = ctx.obj['builder']
    repo_root: Path = ctx.obj['repo_root']
    bake_file: Path = ctx.obj['bake_file']

    try:
        dist_name, version_tag = _parse_dist_spec(dist)
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    dist_dash = _dist_tag(dist_name, version_tag)
    image_tag = tag or f"{variant}:{dist_dash}"

    try:
        if skip_build:
            inspect_code = _run_command(
                ["docker", "image", "inspect", image_tag],
                cwd=repo_root,
            )
            if inspect_code != 0:
                console.print(
                    f"[red]Error:[/red] Image '{image_tag}' not found locally. "
                    f"Build it first or remove --skip-build."
                )
                sys.exit(1)
        else:
            image_tag = _build_with_bake(
                config=config,
                builder=builder,
                repo_root=repo_root,
                bake_file=bake_file,
                dist=dist,
                variant=variant,
                tag=tag,
                platform=platform,
                no_cache=no_cache,
                output_dir=output_dir,
                load=True,
                push=False,
            )
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except RuntimeError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        console.print("\n[yellow]Build interrupted by user[/yellow]")
        sys.exit(130)

    checks = [
        (
            "petsc4py/slepc4py import",
            [
                "docker",
                "run",
                "--rm",
                image_tag,
                "python3",
                "-c",
                (
                    "import petsc4py, slepc4py; "
                    "print('petsc4py:', petsc4py.__file__); "
                    "print('slepc4py:', slepc4py.__file__)"
                ),
            ],
        ),
    ]

    console.print("\n[blue]Running smoke tests:[/blue]")
    for name, cmd in checks:
        console.print(f"  - {name}")
        code = _run_command(cmd, cwd=repo_root)
        if code != 0:
            console.print(f"[red]✗ Smoke test failed:[/red] {name}")
            sys.exit(code)

    console.print(f"\n[green]✓ All smoke tests passed for {image_tag}[/green]")


@main.command()
@click.option('--registry', default='ghcr.io', help='Container registry')
@click.option('--token', help='GitHub token (default: $CR_PAT or $GITHUB_TOKEN)')
@click.option('--user', help='Registry username (default: $GITHUB_ACTOR or $USER)')
@click.option('--dry-run', is_flag=True, help='Show login command without executing')
def login(registry: str, token: Optional[str], user: Optional[str], dry_run: bool):
    """Login Docker client to container registry (default: ghcr.io)."""
    if dry_run:
        resolved_user = user or os.getenv("GITHUB_ACTOR") or os.getenv("USER") or "<user>"
        console.print("[yellow]DRY RUN - No login performed[/yellow]")
        console.print(f"Would execute: docker login {registry} -u {resolved_user} --password-stdin")
        return

    try:
        resolved_user, resolved_token = _resolve_registry_credentials(token, user)
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    console.print(f"[blue]Logging in to {registry} as {resolved_user}...[/blue]")
    try:
        _docker_login(registry, resolved_user, resolved_token)
    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except RuntimeError as e:
        console.print(f"[red]Login failed:[/red] {e}")
        sys.exit(1)

    console.print(f"[green]✓ Logged in to {registry}[/green]")


@main.command()
@click.argument('dist', required=True)
@click.option('--variant', default='feelpp-env', help='Variant to push')
@click.option('--registry', default='ghcr.io', help='Container registry')
@click.option('--repo', default='feelpp', help='Repository organization')
@click.option('--token', help='GitHub token (default: $CR_PAT or $GITHUB_TOKEN)')
@click.option('--user', help='Registry username (default: $GITHUB_ACTOR or $USER)')
@click.option('--dry-run', is_flag=True, help='Show what would be pushed without pushing')
@click.pass_context
def push(ctx, dist: str, variant: str, registry: str, repo: str, 
         token: Optional[str], user: Optional[str], dry_run: bool):
    """Push Docker image to container registry (ghcr.io).

    DIST format: `name:version` (for example: `ubuntu:24.04`, `debian:13`).

    Requires GitHub Personal Access Token with packages:write scope.
    Set via CR_PAT or GITHUB_TOKEN environment variable, or use --token option.

    \b
    Examples:
      export CR_PAT=ghp_xxxxxxxxxxxx
      feelpp-factory push ubuntu:24.04
      feelpp-factory push debian:13 --token ghp_xxxxx
      feelpp-factory push ubuntu:24.04 --dry-run
      feelpp-factory push debian:sid --registry docker.io --repo myuser
    """
    try:
        dist_name, version_tag = _parse_dist_spec(dist)
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    try:
        resolved_user, resolved_token = _resolve_registry_credentials(token, user)
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    
    # Construct tags
    local_tag = f"{variant}:{dist_name}-{version_tag}"
    remote_tag = f"{registry}/{repo}/{variant}:{dist_name}-{version_tag}"
    
    console.print("\n[green]═══ Pushing to Container Registry ═══[/green]")
    console.print(f"Distribution: {dist}")
    console.print(f"Local tag:    {local_tag}")
    console.print(f"Remote tag:   {remote_tag}")
    console.print(f"Registry:     {registry}")
    console.print(f"Repository:   {repo}/{variant}")
    console.print()
    
    if dry_run:
        console.print("[yellow]DRY RUN - No actual push will occur[/yellow]\n")
        console.print("Would execute:")
        console.print(f"  echo <token> | docker login {registry} -u {resolved_user} --password-stdin")
        console.print(f"  docker tag {local_tag} {remote_tag}")
        console.print(f"  docker push {remote_tag}")
        return
    
    # Check if local image exists
    try:
        result = subprocess.run(
            ['docker', 'image', 'inspect', local_tag],
            capture_output=True,
            check=False
        )
        if result.returncode != 0:
            console.print(f"[red]Error:[/red] Local image '{local_tag}' not found\n")
            console.print("Build it first with:")
            console.print(f"  feelpp-factory build {dist}")
            sys.exit(1)
    except FileNotFoundError:
        console.print("[red]Error:[/red] Docker command not found. Is Docker installed?")
        sys.exit(1)
    
    # Login to registry
    console.print(f"[blue]Logging in to {registry}...[/blue]")
    try:
        _docker_login(registry, resolved_user, resolved_token)
    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)
    except RuntimeError as e:
        console.print(f"[red]Login failed:[/red] {e}")
        sys.exit(1)
    
    # Tag image
    console.print("[blue]Tagging image...[/blue]")
    result = subprocess.run(
        ['docker', 'tag', local_tag, remote_tag],
        capture_output=True,
        check=False
    )
    if result.returncode != 0:
        console.print(f"[red]Tag failed:[/red] {result.stderr.decode()}")
        sys.exit(1)
    
    # Push image
    console.print("[blue]Pushing image...[/blue]")
    result = subprocess.run(
        ['docker', 'push', remote_tag],
        check=False
    )
    
    if result.returncode == 0:
        console.print(f"\n[green]✓ Successfully pushed {remote_tag}[/green]\n")
        console.print("Pull with:")
        console.print(f"  docker pull {remote_tag}")
    else:
        console.print(f"\n[red]✗ Push failed with exit code {result.returncode}[/red]")
        sys.exit(result.returncode)


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
