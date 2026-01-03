# =============================================================================
# Feel++ Docker Bake Configuration
# =============================================================================
# Build all images:     docker buildx bake
# Build specific:       docker buildx bake feelpp
# Build with distro:    docker buildx bake --set "*.args.DIST=debian-13"
# Build and push:       docker buildx bake --push
#
# Image naming convention:
#   - Runtime (for users):  ghcr.io/feelpp/feelpp:ubuntu-24.04
#   - Dev (for CI chain):   ghcr.io/feelpp/feelpp:ubuntu-24.04-dev
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
  tags = [
    "${REGISTRY}/feelpp:${DIST}-dev",
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
  tags = [
    "${REGISTRY}/feelpp:${DIST}",
    "${REGISTRY}/feelpp:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Toolboxes
# =============================================================================

target "toolboxes" {
  context = "feelpp-toolboxes"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp:${DIST}-dev"
    DESCRIPTION = "Feel++ Toolboxes (dev)"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = [
    "${REGISTRY}/feelpp-toolboxes:${DIST}-dev",
    "${REGISTRY}/feelpp-toolboxes:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "toolboxes-runtime" {
  inherits = ["toolboxes"]
  target = "runtime"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp:${DIST}"
    DESCRIPTION = "Feel++ Toolboxes"
  }
  tags = [
    "${REGISTRY}/feelpp-toolboxes:${DIST}",
    "${REGISTRY}/feelpp-toolboxes:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Model Order Reduction (MOR)
# =============================================================================

target "mor" {
  context = "feelpp-mor"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-toolboxes:${DIST}-dev"
    DESCRIPTION = "Feel++ Model Order Reduction (dev)"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = [
    "${REGISTRY}/feelpp-mor:${DIST}-dev",
    "${REGISTRY}/feelpp-mor:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "mor-runtime" {
  inherits = ["mor"]
  target = "runtime"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-toolboxes:${DIST}"
    DESCRIPTION = "Feel++ Model Order Reduction"
  }
  tags = [
    "${REGISTRY}/feelpp-mor:${DIST}",
    "${REGISTRY}/feelpp-mor:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Python Bindings
# =============================================================================

target "python" {
  context = "feelpp-python"
  dockerfile = "Dockerfile.multistage"
  target = "builder"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-mor:${DIST}-dev"
    DESCRIPTION = "Feel++ Python Bindings (dev)"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
    FEELPP_GITHUB_TOKEN = "${FEELPP_GITHUB_TOKEN}"
    FEELPP_GIRDER_API_KEY = "${FEELPP_GIRDER_API_KEY}"
    FEELPP_CKAN_API_KEY = "${FEELPP_CKAN_API_KEY}"
    FEELPP_CKAN_URL = "${FEELPP_CKAN_URL}"
    FEELPP_CKAN_ORGANIZATION = "${FEELPP_CKAN_ORGANIZATION}"
  }
  tags = [
    "${REGISTRY}/feelpp-python:${DIST}-dev",
    "${REGISTRY}/feelpp-python:${DIST}-${BRANCH}-dev"
  ]
  platforms = ["linux/amd64"]
}

target "python-runtime" {
  inherits = ["python"]
  target = "runtime"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp-mor:${DIST}"
    DESCRIPTION = "Feel++ Python Bindings"
  }
  tags = [
    "${REGISTRY}/feelpp-python:${DIST}",
    "${REGISTRY}/feelpp-python:${DIST}-${BRANCH}"
  ]
}

# =============================================================================
# Test Suite (no runtime variant - tests only)
# =============================================================================

target "testsuite" {
  context = "feelpp-testsuite"
  dockerfile = "Dockerfile.template"
  args = {
    FROM_IMAGE = "${REGISTRY}/feelpp:${DIST}"
    DESCRIPTION = "Feel++ Test Suite"
    CXX = "${CXX}"
    CC = "${CC}"
    CMAKE_FLAGS = "${CMAKE_FLAGS}"
  }
  tags = [
    "${REGISTRY}/feelpp-testsuite:${DIST}",
    "${REGISTRY}/feelpp-testsuite:${DIST}-${BRANCH}"
  ]
  platforms = ["linux/amd64"]
}
