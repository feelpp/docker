#!/usr/bin/env python3
"""Validation for configuration and generated Dockerfiles."""

from typing import List
from .config import Config


class Validator:
    """Validate configuration consistency and correctness."""
    
    def __init__(self, config: Config):
        """Initialize validator with configuration."""
        self.config = config
    
    def validate_all(self) -> List[str]:
        """Run all validation checks and return list of errors."""
        errors = []
        
        errors.extend(self._validate_distributions())
        errors.extend(self._validate_packages())
        errors.extend(self._validate_variants())
        errors.extend(self._validate_cross_references())
        
        return errors
    
    def _validate_distributions(self) -> List[str]:
        """Validate distribution configurations."""
        errors = []
        
        for dist_name, dist in self.config.distributions.items():
            # Check for duplicate version tags
            tags = [v.tag for v in dist.versions]
            if len(tags) != len(set(tags)):
                errors.append(f"Distribution '{dist_name}' has duplicate version tags")
            
            # Check base images are properly formatted
            for version in dist.versions:
                if ':' not in version.base_image:
                    errors.append(
                        f"Distribution '{dist_name}' version '{version.tag}' "
                        f"has invalid base_image: {version.base_image}"
                    )
                
                # Check platforms are valid
                valid_platforms = {'linux/amd64', 'linux/arm64', 'linux/arm/v7'}
                for platform in version.platforms:
                    if platform not in valid_platforms:
                        errors.append(
                            f"Distribution '{dist_name}' version '{version.tag}' "
                            f"has invalid platform: {platform}"
                        )
        
        return errors
    
    def _validate_packages(self) -> List[str]:
        """Validate package configurations."""
        errors = []
        
        # Check package groups reference valid package managers
        for group_name, group in self.config.packages.groups.items():
            for pkg_mgr in group.keys():
                if pkg_mgr not in ['apt', 'dnf', 'yum']:
                    errors.append(
                        f"Package group '{group_name}' uses unknown "
                        f"package manager: {pkg_mgr}"
                    )
        
        # Check layers reference valid package groups
        for layer_name, groups in self.config.packages.layers.items():
            for group_name in groups:
                if group_name not in self.config.packages.groups:
                    errors.append(
                        f"Layer '{layer_name}' references unknown "
                        f"package group: {group_name}"
                    )
        
        return errors
    
    def _validate_variants(self) -> List[str]:
        """Validate variant configurations."""
        errors = []
        
        for variant_name, variant in self.config.variants.items():
            # Check layers exist
            for layer in variant.layers:
                if layer not in self.config.packages.layers:
                    errors.append(
                        f"Variant '{variant_name}' references unknown layer: {layer}"
                    )
            
            # Check distribution specifications are valid
            for dist_spec in variant.distributions:
                if ':' not in dist_spec:
                    errors.append(
                        f"Variant '{variant_name}' has invalid distribution "
                        f"specification: {dist_spec} (should be 'name:version')"
                    )
                    continue
                
                dist_name, version_tag = dist_spec.split(':', 1)
                
                if dist_name not in self.config.distributions:
                    errors.append(
                        f"Variant '{variant_name}' references unknown "
                        f"distribution: {dist_name}"
                    )
                    continue
                
                # Check version exists
                try:
                    self.config.get_distribution_version(dist_name, version_tag)
                except ValueError as e:
                    errors.append(
                        f"Variant '{variant_name}': {str(e)}"
                    )
        
        return errors
    
    def _validate_cross_references(self) -> List[str]:
        """Validate cross-references between configurations."""
        errors = []
        
        # Check that all distributions in variants support required package managers
        for variant_name, variant in self.config.variants.items():
            for dist_spec in variant.distributions:
                try:
                    dist_name, version_tag = dist_spec.split(':', 1)
                    dist = self.config.distributions[dist_name]
                    
                    # Get packages for this variant
                    try:
                        self.config.get_packages_for_layers(
                            variant.layers,
                            dist.package_manager
                        )
                    except ValueError as e:
                        errors.append(
                            f"Variant '{variant_name}' with distribution "
                            f"'{dist_spec}': {str(e)}"
                        )
                except (ValueError, KeyError):
                    # Already caught in other validations
                    pass
        
        return errors
