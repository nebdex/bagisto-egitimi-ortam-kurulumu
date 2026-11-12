# Bagisto eğitimi — imaj derleme tanımı (Docker Buildx Bake).
#
# Yerel derleme (kur.sh bunu çalıştırır):
#   docker buildx bake --load php
#
# Eğitmen için: imajı amd64 ve arm64 için bir kez derleyip bir kayıt deposuna gönderin;
# katılımcılar .env içinde PHP_IMAGE'ı bu adrese çevirir ve derlemeden çeker:
#   PHP_IMAGE=ghcr.io/<hesap>/bagisto-egitimi-php docker buildx bake php-paylasim --push

variable "PHP_VERSION" {
  default = "8.4"
}

variable "NODE_VERSION" {
  default = "22"
}

variable "PHP_IMAGE" {
  default = "bagisto-egitimi/php"
}

group "default" {
  targets = ["php"]
}

target "php" {
  context    = "docker/php"
  dockerfile = "Dockerfile"
  args = {
    PHP_VERSION  = PHP_VERSION
    NODE_VERSION = NODE_VERSION
  }
  tags = ["${PHP_IMAGE}:${PHP_VERSION}"]
}

target "php-paylasim" {
  inherits  = ["php"]
  platforms = ["linux/amd64", "linux/arm64"]
}
