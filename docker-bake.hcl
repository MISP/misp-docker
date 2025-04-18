variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
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

variable "PYPI_MISP_STIX" {
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

variable "PHP_VER" {
  default = null
}

group "default" {
  targets = [
    "modules",
    "modules-slim",
    "core",
    "core-slim",
  ]
}

target "modules" {
  context = "modules/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/modules:latest", "${NAMESPACE}/modules:${COMMIT_HASH}", MODULES_TAG != "" ? ["${NAMESPACE}/modules:${MODULES_TAG}"] : []])
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}",
    "MODULES_FLAVOR": "full",
  }
  platforms = "${PLATFORMS}"
}

target "modules-slim" {
  context = "modules/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/modules:latest-slim", "${NAMESPACE}/modules:${COMMIT_HASH}-slim", MODULES_TAG != "" ? ["${NAMESPACE}/modules:${MODULES_TAG}-slim"] : []])
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}",
    "MODULES_FLAVOR": "lite",
  }
  platforms = "${PLATFORMS}"
}

target "core" {
  context = "core/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/core:latest", "${NAMESPACE}/core:${COMMIT_HASH}", CORE_TAG != "" ? ["${NAMESPACE}/core:${CORE_TAG}"] : []])
  args = {
    "CORE_TAG": "${CORE_TAG}",
    "CORE_COMMIT": "${CORE_COMMIT}",
    "CORE_FLAVOR": "full",
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
  }
  platforms = "${PLATFORMS}"
}

target "core-slim" {
  context = "core/."
  dockerfile = "Dockerfile"
  tags = flatten(["${NAMESPACE}/core:latest-slim", "${NAMESPACE}/core:${COMMIT_HASH}-slim", CORE_TAG != "" ? ["${NAMESPACE}/core:${CORE_TAG}-slim"] : []])
  args = {
    "CORE_TAG": "${CORE_TAG}",
    "CORE_COMMIT": "${CORE_COMMIT}",
    "CORE_FLAVOR": "lite",
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
  }
  platforms = "${PLATFORMS}"
}
