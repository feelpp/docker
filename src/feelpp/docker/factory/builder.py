#!/usr/bin/env python3
"""Docker image builder using templates."""

from pathlib import Path
from typing import Dict, Optional
from jinja2 import Environment, FileSystemLoader, StrictUndefined

from .config import Config, PackageManager


class ImageBuilder:
    """Build Docker images from templates and configuration."""
    
    def __init__(self, config: Config, template_dir: Path):
        """Initialize builder with configuration and templates."""
        self.config = config
        self.template_dir = template_dir
        
        # Setup Jinja2 environment with strict undefined checking
        self.env = Environment(
            loader=FileSystemLoader(template_dir),
            undefined=StrictUndefined,
            trim_blocks=True,
            lstrip_blocks=True,
        )
        
        # Add custom filters
        self.env.filters['join_packages'] = self._join_packages
    
    def generate_dockerfile(
        self, 
        variant_name: str,
        dist_name: str, 
        version_tag: str,
        output_dir: Optional[Path] = None
    ) -> str:
        """Generate Dockerfile for a specific variant and distribution."""
        # Get variant configuration
        variant = self.config.variants[variant_name]
        
        # Get distribution configuration
        dist = self.config.distributions[dist_name]
        version = self.config.get_distribution_version(dist_name, version_tag)
        
        # Get template
        template = self.env.get_template(dist.template)
        
        # Build context
        context = self._build_context(variant, dist_name, dist, version)
        
        # Render template
        dockerfile_content = template.render(**context)
        
        # Optionally write to file
        if output_dir:
            output_dir = Path(output_dir)
            output_dir.mkdir(parents=True, exist_ok=True)
            
            output_file = output_dir / "Dockerfile"
            output_file.write_text(dockerfile_content)
            
            # Copy auxiliary files if they exist
            self._copy_auxiliary_files(output_dir)
        
        return dockerfile_content
    
    def _copy_auxiliary_files(self, output_dir: Path):
        """Copy auxiliary files (WELCOME, start.sh, etc.) to output directory."""
        import shutil
        
        # Files to copy from parent directory
        aux_files = [
            'WELCOME',
            'start.sh',
            'start-user.sh',
            'bashrc.feelpp',
            'ctest-to-junit.xsl',
        ]
        
        # Files with feelpp prefix
        feelpp_files = [
            'feelpp.conf.sh',
            'feelpp.env.sh',
        ]
        
        parent_dir = self.template_dir.parent
        
        for filename in aux_files + feelpp_files:
            src = parent_dir / filename
            if src.exists():
                dst = output_dir / filename
                shutil.copy2(src, dst)
    
    def _build_context(self, variant, dist_name, dist, version) -> Dict:
        """Build template rendering context."""
        # Get packages
        extra_pkgs = variant.extra_packages.get(dist.package_manager, [])
        packages = self.config.get_packages_for_layers(
            variant.layers,
            dist.package_manager,
            extra_pkgs
        )
        
        context = {
            # Distribution info
            'base_image': version.base_image,
            'dist_name': dist_name,
            'dist_version': version.tag,
            'dist_codename': version.name,
            
            # Package management
            'pkg_manager': dist.package_manager,
            'packages': packages,
            'mirror': dist.mirror,
            
            # Build configuration
            'platforms': version.platforms,
            'experimental': version.experimental,
            'cmake_version': version.cmake_version,
            
            # Feature flags
            'enable_openmpi': variant.enable_openmpi,
            'requires_openmpi_layer': version.requires_openmpi_layer,
            
            # Variant info
            'variant_name': variant.description,
        }
        
        return context
    
    @staticmethod
    def _join_packages(packages: list, indent: int = 8) -> str:
        """Join packages with proper formatting for Dockerfile RUN statements."""
        if not packages:
            return ""
        
        # Create indentation
        spaces = ' ' * indent
        
        # Join packages with continuation (including last package)
        lines = [f"{spaces}{pkg} \\" for pkg in packages]
        
        return '\n'.join(lines)
    
    def generate_all(self, variant_name: str, base_output_dir: Path):
        """Generate Dockerfiles for all distributions in a variant."""
        variant = self.config.variants[variant_name]
        results = []
        
        for dist_spec in variant.distributions:
            dist_name, version_tag = dist_spec.split(':')
            dist = self.config.distributions[dist_name]
            version = self.config.get_distribution_version(dist_name, version_tag)
            
            # Create output directory for this variant
            output_dir = base_output_dir / f"{dist_name}-{version.tag}-clang++"
            
            # Generate Dockerfile
            content = self.generate_dockerfile(
                variant_name,
                dist_name,
                version_tag,
                output_dir
            )
            
            results.append({
                'dist': f"{dist_name}:{version_tag}",
                'output_dir': output_dir,
                'success': True,
                'size': len(content)
            })
        
        return results
