# =============================================================================
# Feel++ Docker Bake Configuration
# =============================================================================
# Build all images:     docker buildx bake
# Build specific:       docker buildx bake feelpp
# Build with distro:    docker buildx bake --set "*.args.DIST=debian-13"
# Build and push:       docker buildx bake --push
#
# Image naming convention:
#   - develop branch:       ghcr.io/feelpp/feelpp:ubuntu-24.04 (runtime)
#                           ghcr.io/feelpp/feelpp:ubuntu-24.04-dev (dev)
#   - feature branches:     ghcr.io/feelpp/feelpp:ubuntu-24.04-{branch} (runtime)
#                           ghcr.io/feelpp/feelpp:ubuntu-24.04-{branch}-dev (dev)
# =============================================================================

variable "REGISTRY" {
  default = "ghcr.io/feelpp"
}

variable "DIST" {
  default = "ubuntu-24.04"
}

variable "BRANCH" {
  default = "develop"
}

variable "CXX" {
  default = "clang++"
}

variable "CC" {
  default = "clang"
}

variable "CMAKE_FLAGS" {
  default = ""
}

# Secrets for tests (passed via environment variables)
variable "FEELPP_GITHUB_TOKEN" {
  default = ""
}

variable "FEELPP_GIRDER_API_KEY" {
  default = ""
}

variable "FEELPP_CKAN_API_KEY" {
  default = ""
}

variable "FEELPP_CKAN_URL" {
  default = ""
}

variable "FEELPP_CKAN_ORGANIZATION" {
  default = ""
}

# =============================================================================
# Groups - Build multiple targets together
# =============================================================================

group "default" {
  targets = ["feelpp"]
}

group "all-dev" {
  targets = ["feelpp", "toolboxes", "mor", "python"]
}

group "all" {
  targets = ["feelpp-runtime", "toolboxes-runtime", "mor-runtime", "python-runtime"]
}

group "full" {
  targets = ["feelpp-full"]
}

group "full-all" {
  targets = ["feelpp-full", "feelpp-full-runtime"]
}

# =============================================================================
# Base Environment (built separately via factory.sh)
# =============================================================================

target "feelpp-env" {
  context = "feelpp-env/${DIST}-clang++"
  dockerfile = "Dockerfile"
  tags = ["${REGISTRY}/feelpp-env:${DIST}"]
  platforms = ["linux/amd64"]
}

# =============================================================================
# Feel++ Core Library
# =============================================================================

target "feelpp" {
  context = "feelpp"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-env:${DIST}"
    DESCRIPTION = "Feel++ core library (dev)"
    BRANCH = "${BRANCH}"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp:${DIST}-dev"
  ] : [
    "${REGISTRY}/feelpp:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "feelpp-runtime" {
  inherits = ["feelpp"]
  target = "runtime"
  args = {
    DESCRIPTION = "Feel++ core library"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp:${DIST}"
  ] : [
    "${REGISTRY}/feelpp:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Toolboxes
# =============================================================================
# Builder uses RUNTIME base image (not -dev) - smaller, just needs installed libs.
# Source is cloned in the Dockerfile.

target "toolboxes" {
  context = "feelpp-toolboxes"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = BRANCH == "develop" ? "${REGISTRY}/feelpp:${DIST}" : "${REGISTRY}/feelpp:${DIST}-${BRANCH}"
    DESCRIPTION = "Feel++ Toolboxes (dev)"
    BRANCH = "${BRANCH}"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-toolboxes:${DIST}-dev"
  ] : [
    "${REGISTRY}/feelpp-toolboxes:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "toolboxes-runtime" {
  inherits = ["toolboxes"]
  target = "runtime"
  args = {
    DESCRIPTION = "Feel++ Toolboxes"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-toolboxes:${DIST}"
  ] : [
    "${REGISTRY}/feelpp-toolboxes:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Model Order Reduction (MOR)
# =============================================================================
# Builder uses RUNTIME base image (not -dev) - smaller, just needs installed libs.
# Source is cloned in the Dockerfile.

target "mor" {
  context = "feelpp-mor"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = BRANCH == "develop" ? "${REGISTRY}/feelpp-toolboxes:${DIST}" : "${REGISTRY}/feelpp-toolboxes:${DIST}-${BRANCH}"
    DESCRIPTION = "Feel++ Model Order Reduction (dev)"
    BRANCH = "${BRANCH}"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-mor:${DIST}-dev"
  ] : [
    "${REGISTRY}/feelpp-mor:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "mor-runtime" {
  inherits = ["mor"]
  target = "runtime"
  args = {
    DESCRIPTION = "Feel++ Model Order Reduction"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-mor:${DIST}"
  ] : [
    "${REGISTRY}/feelpp-mor:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Python Bindings
# =============================================================================
# Builder uses RUNTIME base image (not -dev) - smaller, just needs installed libs.
# Source is cloned in the Dockerfile.

target "python" {
  context = "feelpp-python"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = BRANCH == "develop" ? "${REGISTRY}/feelpp-mor:${DIST}" : "${REGISTRY}/feelpp-mor:${DIST}-${BRANCH}"
    DESCRIPTION = "Feel++ Python Bindings (dev)"
    BRANCH = "${BRANCH}"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-python:${DIST}-dev"
  ] : [
    "${REGISTRY}/feelpp-python:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "python-runtime" {
  inherits = ["python"]
  target = "runtime"
  args = {
    DESCRIPTION = "Feel++ Python Bindings"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-python:${DIST}"
  ] : [
    "${REGISTRY}/feelpp-python:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Full Build (all components in one image)
# =============================================================================
# Use this for a complete Feel++ installation in a single build.
# Image names use "-full" suffix to avoid collision with component builds.
# =============================================================================

target "feelpp-full" {
  context = "feelpp"
  dockerfile = "Dockerfile.full"
  target = "builder"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-env:${DIST}"
    DESCRIPTION = "Feel++ Full Stack (dev)"
    BRANCH = "${BRANCH}"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp:${DIST}-full-dev"
  ] : [
    "${REGISTRY}/feelpp:${DIST}-${BRANCH}-full-dev"
  ]
  platforms = ["linux/amd64"]
}

target "feelpp-full-runtime" {
  inherits = ["feelpp-full"]
  target = "runtime"
  args = {
    DESCRIPTION = "Feel++ Full Stack"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp:${DIST}-full"
  ] : [
    "${REGISTRY}/feelpp:${DIST}-${BRANCH}-full"
  ]
}

# =============================================================================
# Test Suite (no runtime variant - tests only)
# =============================================================================

target "testsuite" {
  context = "feelpp-testsuite"
  dockerfile = "Dockerfile.template"
  args = {
    FROM_IMAGE = BRANCH == "develop" ? "${REGISTRY}/feelpp:${DIST}" : "${REGISTRY}/feelpp:${DIST}-${BRANCH}"
    DESCRIPTION = "Feel++ Test Suite"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
  }
  tags = BRANCH == "develop" ? [
    "${REGISTRY}/feelpp-testsuite:${DIST}"
  ] : [
    "${REGISTRY}/feelpp-testsuite:${DIST}-${BRANCH}"
  ]
  platforms = ["linux/amd64"]
}
