variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
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
  tags = ["${DOCKER_USERNAME}/misp-docker:modules-latest", "${DOCKER_USERNAME}/misp-docker:modules-${DOCKER_IMG_TAG}", "${DOCKER_USERNAME}/misp-docker:modules-${MODULES_TAG}"]
  args = {
    "MODULES_TAG": "${MODULES_TAG}",
    "MODULES_COMMIT": "${MODULES_COMMIT}"
  }
  platforms = "${PLATFORMS}"
}

target "misp" {
  context = "server/."
  dockerfile = "Dockerfile"
  tags = ["${DOCKER_USERNAME}/misp-docker:core-latest", "${DOCKER_USERNAME}/misp-docker:core-${DOCKER_IMG_TAG}", "${DOCKER_USERNAME}/misp-docker:core-${MISP_TAG}"]
  args = {
    "MISP_TAG": "${MISP_TAG}",
    "MISP_COMMIT": "${MISP_COMMIT}",
    "PHP_VER": "${PHP_VER}",
  }
  platforms = "${PLATFORMS}"
}
