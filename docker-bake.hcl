variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
}

variable "DOCKER_HUB_PROXY" {
  default = ""
}

variable "PYPI_REDIS_VERSION" {
  default = ""
}

variable "PYPI_LIEF_VERSION" {
  default = ""
}

variable "PYPI_PYDEEP2_VERSION" {
  default = ""
}

variable "PYPI_PYTHON_MAGIC_VERSION" {
  default = ""
}

variable "PYPI_MISP_LIB_STIX2_VERSION" {
  default = ""
}

variable "PYPI_MAEC_VERSION" {
  default = ""
}

variable "PYPI_MIXBOX_VERSION" {
  default = ""
}

variable "PYPI_CYBOX_VERSION" {
  default = ""
}

variable "PYPI_PYMISP_VERSION" {
  default = ""
}

variable "PYPI_MISP_STIX_VERSION" {
  default = ""
}

variable "PYPI_TAXII2_CLIENT" {
  default = ""
}

variable "PYPI_SETUPTOOLS_VERSION" {
  default = ""
}

variable "PYPI_SUPERVISOR_VERSION" {
  default = ""
}

variable "NAMESPACE" {
  default = null
}

variable "COMMIT_HASH" {
  default = null
}

variable "MODULES_TAG" {
  default = ""
}

variable "MODULES_COMMIT" {
  default = ""
}

variable "CORE_TAG" {
  default = ""
}

variable "CORE_COMMIT" {
  default = ""
}

variable "GUARD_TAG" {
  default = ""
}

variable "GUARD_COMMIT" {
  default = ""
}

variable "PHP_VER" {
  default = null
}

group "default" {
  targets = [
    "misp-modules",
    "misp-modules-slim",
    "misp-core",
    "misp-core-slim",
    "misp-guard",
  ]
}

group "slim" {
  targets = [
    "misp-modules-slim",
    "misp-core-slim",
    "misp-guard",
  ]
}
group "standard" {
  targets = [
    "misp-modules",
    "misp-core",
    "misp-guard",
  ]
}

target "misp-modules" {
  context = "modules/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/misp-modules:latest", "${NAMESPACE}/misp-modules:${COMMIT_HASH}", MODULES_TAG != "" ? ["${NAMESPACE}/misp-modules:${MODULES_TAG}"] : []])
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}",
    "MODULES_FLAVOR": "standard",
    "DOCKER_HUB_PROXY" : "${DOCKER_HUB_PROXY}",
  }
  platforms = "${PLATFORMS}"
}

target "misp-modules-slim" {
  inherits = [ "misp-modules" ]
  tags = flatten(["${NAMESPACE}/misp-modules:latest-slim", "${NAMESPACE}/misp-modules:${COMMIT_HASH}-slim", MODULES_TAG != "" ? ["${NAMESPACE}/misp-modules:${MODULES_TAG}-slim"] : []])
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}",
    "MODULES_FLAVOR": "slim",
    "DOCKER_HUB_PROXY" : "${DOCKER_HUB_PROXY}",
  }
  platforms = "${PLATFORMS}"
}

target "misp-core" {
  context = "core/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/misp-core:latest", "${NAMESPACE}/misp-core:${COMMIT_HASH}", CORE_TAG != "" ? ["${NAMESPACE}/misp-core:${CORE_TAG}"] : []])
  args = {
    "CORE_TAG": "${CORE_TAG}",
    "CORE_COMMIT": "${CORE_COMMIT}",
    "CORE_FLAVOR": "standard",
    "PHP_VER": "${PHP_VER}",
    "PYPI_REDIS_VERSION": "${PYPI_REDIS_VERSION}",
    "PYPI_LIEF_VERSION": "${PYPI_LIEF_VERSION}",
    "PYPI_PYDEEP2_VERSION": "${PYPI_PYDEEP2_VERSION}",
    "PYPI_PYTHON_MAGIC_VERSION": "${PYPI_PYTHON_MAGIC_VERSION}",
    "PYPI_MISP_LIB_STIX2_VERSION": "${PYPI_MISP_LIB_STIX2_VERSION}",
    "PYPI_MAEC_VERSION": "${PYPI_MAEC_VERSION}",
    "PYPI_MIXBOX_VERSION": "${PYPI_MIXBOX_VERSION}",
    "PYPI_CYBOX_VERSION": "${PYPI_CYBOX_VERSION}",
    "PYPI_PYMISP_VERSION": "${PYPI_PYMISP_VERSION}",
    "PYPI_MISP_STIX_VERSION": "${PYPI_MISP_STIX_VERSION}",
    "PYPI_TAXII2_CLIENT": "${PYPI_TAXII2_CLIENT}",
    "PYPI_SETUPTOOLS_VERSION": "${PYPI_SETUPTOOLS_VERSION}",
    "PYPI_SUPERVISOR_VERSION": "${PYPI_SUPERVISOR_VERSION}",
    "DOCKER_HUB_PROXY" : "${DOCKER_HUB_PROXY}",
  }
  platforms = "${PLATFORMS}"
}

target "misp-core-slim" {
  inherits = [ "misp-core" ]
  tags = flatten(["${NAMESPACE}/misp-core:latest-slim", "${NAMESPACE}/misp-core:${COMMIT_HASH}-slim", CORE_TAG != "" ? ["${NAMESPACE}/misp-core:${CORE_TAG}-slim"] : []])
  args = {
    "CORE_TAG": "${CORE_TAG}",
    "CORE_COMMIT": "${CORE_COMMIT}",
    "CORE_FLAVOR": "slim",
    "PHP_VER": "${PHP_VER}",
    "PYPI_REDIS_VERSION": "${PYPI_REDIS_VERSION}",
    "PYPI_LIEF_VERSION": "${PYPI_LIEF_VERSION}",
    "PYPI_PYDEEP2_VERSION": "${PYPI_PYDEEP2_VERSION}",
    "PYPI_PYTHON_MAGIC_VERSION": "${PYPI_PYTHON_MAGIC_VERSION}",
    "PYPI_MISP_LIB_STIX2_VERSION": "${PYPI_MISP_LIB_STIX2_VERSION}",
    "PYPI_MAEC_VERSION": "${PYPI_MAEC_VERSION}",
    "PYPI_MIXBOX_VERSION": "${PYPI_MIXBOX_VERSION}",
    "PYPI_CYBOX_VERSION": "${PYPI_CYBOX_VERSION}",
    "PYPI_PYMISP_VERSION": "${PYPI_PYMISP_VERSION}",
    "PYPI_MISP_STIX_VERSION": "${PYPI_MISP_STIX_VERSION}",
    "PYPI_TAXII2_CLIENT": "${PYPI_TAXII2_CLIENT}",
    "PYPI_SETUPTOOLS_VERSION": "${PYPI_SETUPTOOLS_VERSION}",
    "PYPI_SUPERVISOR_VERSION": "${PYPI_SUPERVISOR_VERSION}",
    "DOCKER_HUB_PROXY" : "${DOCKER_HUB_PROXY}",
  }
  platforms = "${PLATFORMS}"
}

target "misp-guard" {
  context = "guard/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/misp-guard:latest", "${NAMESPACE}/misp-guard:${COMMIT_HASH}", GUARD_TAG != "" ? ["${NAMESPACE}/misp-guard:${GUARD_TAG}"] : []])
  args = {
    "GUARD_TAG": "${GUARD_TAG}",
    "GUARD_COMMIT": "${GUARD_COMMIT}"
    "DOCKER_HUB_PROXY" : "${DOCKER_HUB_PROXY}",
  }
  platforms = "${PLATFORMS}"
}
