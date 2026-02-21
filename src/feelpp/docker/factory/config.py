#!/usr/bin/env python3
"""Configuration models for Docker image factory."""

from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional
from pydantic import BaseModel, Field
import yaml


class PackageManager(str, Enum):
    """Supported package managers."""
    APT = "apt"
    DNF = "dnf"
    YUM = "yum"


class DistributionVersion(BaseModel):
    """Single version of a distribution."""
    name: str = Field(..., description="Version codename (e.g., noble, bookworm)")
    tag: str = Field(..., description="Version tag (e.g., 24.04, 13)")
    base_image: str = Field(..., description="Base Docker image (e.g., ubuntu:24.04)")
    platforms: List[str] = Field(default=["linux/amd64"], description="Supported platforms")
    experimental: bool = Field(default=False, description="Whether this is experimental")
    cmake_version: Optional[str] = Field(default=None, description="Custom CMake version")
    requires_openmpi_layer: bool = Field(default=True, description="Whether OpenMPI layer is needed")


class Distribution(BaseModel):
    """Configuration for a distribution family."""
    versions: List[DistributionVersion]
    package_manager: PackageManager
    template: str = Field(..., description="Jinja2 template filename")
    mirror: Optional[str] = Field(default=None, description="Package mirror URL")


class PackageGroups(BaseModel):
    """Groups of packages across package managers."""
    groups: Dict[str, Dict[str, List[str]]] = Field(
        ..., 
        description="Package groups by name, then by package manager"
    )
    layers: Dict[str, List[str]] = Field(
        ...,
        description="Named layers composed of package groups"
    )


class Variant(BaseModel):
    """A variant to build (e.g., feelpp-env, feelpp-toolboxes)."""
    description: str
    layers: List[str]
    enable_openmpi: bool = True
    distributions: List[str] = Field(..., description="List of dist:version to build")
    extra_packages: Dict[str, List[str]] = Field(
        default_factory=dict,
        description="Extra packages per package manager"
    )


class Config:
    """Main configuration loader and accessor."""
    
    def __init__(self, config_dir: Path):
        """Initialize configuration from directory."""
        self.config_dir = Path(config_dir) if not isinstance(config_dir, Path) else config_dir
        self.distributions: Dict[str, Distribution] = {}
        self.packages: PackageGroups = None
        self.variants: Dict[str, Variant] = {}
        
        self._load_all()
    
    def _load_yaml(self, filename: str) -> dict:
        """Load a YAML configuration file."""
        path = self.config_dir / filename
        if not path.exists():
            raise FileNotFoundError(f"Configuration file not found: {path}")
        
        with open(path, 'r') as f:
            return yaml.safe_load(f)
    
    def _load_all(self):
        """Load all configuration files."""
        # Load distributions
        dist_config = self._load_yaml('distributions.yaml')
        for name, config in dist_config['distributions'].items():
            self.distributions[name] = Distribution(**config)
        
        # Load packages
        pkg_config = self._load_yaml('packages.yaml')
        self.packages = PackageGroups(**pkg_config)
        
        # Load variants
        variant_config = self._load_yaml('variants.yaml')
        for name, config in variant_config['variants'].items():
            self.variants[name] = Variant(**config)
    
    def get_distribution_version(self, dist_name: str, version_tag: str) -> DistributionVersion:
        """Get a specific distribution version configuration."""
        if dist_name not in self.distributions:
            raise ValueError(f"Unknown distribution: {dist_name}")
        
        dist = self.distributions[dist_name]
        for version in dist.versions:
            if version.tag == version_tag:
                return version
        
        raise ValueError(f"Unknown version {version_tag} for distribution {dist_name}")
    
    def get_packages_for_layers(
        self, 
        layers: List[str], 
        pkg_manager: PackageManager,
        extra_packages: Optional[List[str]] = None
    ) -> List[str]:
        """Get all packages needed for specified layers."""
        packages = []
        
        for layer_name in layers:
            if layer_name not in self.packages.layers:
                raise ValueError(f"Unknown layer: {layer_name}")
            
            for group_name in self.packages.layers[layer_name]:
                if group_name not in self.packages.groups:
                    raise ValueError(f"Unknown package group: {group_name}")
                
                group = self.packages.groups[group_name]
                if pkg_manager not in group:
                    raise ValueError(
                        f"Package group '{group_name}' does not support {pkg_manager}"
                    )
                
                packages.extend(group[pkg_manager])
        
        if extra_packages:
            packages.extend(extra_packages)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_packages = []
        for pkg in packages:
            if pkg not in seen:
                seen.add(pkg)
                unique_packages.append(pkg)
        
        return unique_packages
    
    def get_build_matrix(self, variant_name: str) -> List[Dict]:
        """Generate build matrix for a variant."""
        if variant_name not in self.variants:
            raise ValueError(f"Unknown variant: {variant_name}")
        
        variant = self.variants[variant_name]
        matrix = []
        
        for dist_spec in variant.distributions:
            dist_name, version_tag = dist_spec.split(':')
            dist = self.distributions[dist_name]
            version = self.get_distribution_version(dist_name, version_tag)
            
            matrix.append({
                'service': variant_name,
                'dist': version.name,
                'flavor': dist_name,
                'version': version.tag,
                'tag': f"{dist_name}-{version.tag}",
                'experimental': version.experimental,
                'platforms': ','.join(version.platforms),
                'dockerfile': 'Dockerfile',
            })
        
        return matrix
