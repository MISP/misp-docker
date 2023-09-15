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

variable "DOCKER_USERNAME" {
  default = null
}

variable "DOCKER_IMG_TAG" {
  default = null
}

variable "MODULES_TAG" {
  default = ""
}

variable "MODULES_COMMIT" {
  default = ""
}

variable "LIBFAUP_COMMIT" {
  default = null
}

variable "MISP_TAG" {
  default = ""
}

variable "MISP_COMMIT" {
  default = ""
}

variable "PHP_VER" {
  default = null
}

group "default" {
  targets = [
    "misp-modules",
    "misp",
  ]
}

target "misp-modules" {
  context = "modules/."
  dockerfile = "Dockerfile"
  tags = flatten(["${DOCKER_USERNAME}/misp-docker:modules-latest", "${DOCKER_USERNAME}/misp-docker:modules-${DOCKER_IMG_TAG}", MODULES_TAG != "" ? ["${DOCKER_USERNAME}/misp-docker:modules-${MODULES_TAG}"] : []])
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}",
  }
  platforms = "${PLATFORMS}"
}

target "misp" {
  context = "server/."
  dockerfile = "Dockerfile"
  tags = flatten(["${DOCKER_USERNAME}/misp-docker:core-latest", "${DOCKER_USERNAME}/misp-docker:core-${DOCKER_IMG_TAG}", MISP_TAG != "" ? ["${DOCKER_USERNAME}/misp-docker:core-${MISP_TAG}"] : []])
  args = {
    "MISP_TAG": "${MISP_TAG}",
    "MISP_COMMIT": "${MISP_COMMIT}",
    "PHP_VER": "${PHP_VER}",
    "PYPI_REDIS_VERSION": "${PYPI_REDIS_VERSION}",
    "PYPI_LIEF_VERSION": "${PYPI_LIEF_VERSION}",
    "PYPI_PYDEEP2_VERSION": "${PYPI_PYDEEP2_VERSION}",
    "PYPI_PYTHON_MAGIC_VERSION": "${PYPI_PYTHON_MAGIC_VERSION}",
    "PYPI_MISP_LIB_STIX2_VERSION": "${PYPI_MISP_LIB_STIX2_VERSION}",
    "PYPI_MAEC_VERSION": "${PYPI_MAEC_VERSION}",
    "PYPI_MIXBOX_VERSION": "${PYPI_MIXBOX_VERSION}",
    "PYPI_CYBOX_VERSION": "${PYPI_CYBOX_VERSION}",
  }
  platforms = "${PLATFORMS}"
}
