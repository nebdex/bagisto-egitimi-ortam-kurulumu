#!/usr/bin/env bash
# Bagisto eğitimi — yerel Docker ortamını kurar ve yönetir.
#
# Kullanım: ./kur.sh [komut]
#   kur       (varsayılan) İmajı derler, Bagisto'yu indirir, örnek verilerle kurar ve başlatır.
#             Tekrar çalıştırmak güvenlidir: yapılmış adımları atlar.
#   baslat    Servisleri başlatır.
#   durdur    Servisleri durdurur (veriler korunur).
#   durum     Servislerin durumunu gösterir.
#   sifirla   Veritabanını, arama indeksini ve bagisto/ klasörünü silip baştan kurar.
#   yardim    Bu metni gösterir.
#
# Ana makinede yalnızca Docker gerekir (Docker Desktop, OrbStack ya da Linux'ta Docker Engine;
# Compose v2 ve Buildx ile). Windows'ta WSL2 içinden çalıştırın.

set -euo pipefail

cd "$(dirname "$0")"
ORTAM_DIR="$(pwd)"
KOD_DIR="$ORTAM_DIR/bagisto"

bilgi() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
uyari() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
hata() {
    printf '\033[1;31mHATA:\033[0m %s\n' "$*" >&2
    exit 1
}

dc() { docker compose "$@"; }

# Kurulum sırasında komutları uygulama imajında, servisleri yeniden başlatmadan çalıştırır.
php_calistir() { dc run --rm --no-deps app "$@"; }

# Bir KEY=değer satırını dosyada günceller; yoksa sona ekler (macOS ve Linux'ta aynı çalışır).
env_yaz() {
    local anahtar=$1 deger=$2 dosya=$3
    awk -v k="$anahtar" -v v="$deger" '
        BEGIN { bulundu = 0 }
        $0 ~ "^" k "=" { print k "=" v; bulundu = 1; next }
        { print }
        END { if (!bulundu) print k "=" v }
    ' "$dosya" >"$dosya.tmp"
    mv "$dosya.tmp" "$dosya"
}

on_kosullar() {
    command -v docker >/dev/null 2>&1 || hata "Docker bulunamadı. Docker Desktop (ya da OrbStack) kurun."
    docker info >/dev/null 2>&1 || hata "Docker çalışmıyor. Docker Desktop'ı (ya da OrbStack'i) başlatıp tekrar deneyin."
    docker compose version >/dev/null 2>&1 || hata "Docker Compose v2 bulunamadı."
    docker buildx bake --help >/dev/null 2>&1 || hata "Docker Buildx (bake) bulunamadı."

    case "$ORTAM_DIR" in
        /mnt/[a-z]/*)
            uyari "Klasör Windows diskinde ($ORTAM_DIR). WSL2'nin Linux dosya sistemine (ör. ev klasörünüzün altına) taşıyın; aksi hâlde ortam çok yavaş çalışır."
            ;;
    esac

    if [ "$(uname -s)" = "Linux" ]; then
        local mmc
        mmc=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
        if [ "$mmc" -lt 262144 ]; then
            uyari "vm.max_map_count=$mmc. Elasticsearch için en az 262144 gerekir: sudo sysctl -w vm.max_map_count=262144"
        fi
    fi
}

ortam_ayarlari() {
    if [ ! -f .env ]; then
        cp .env.example .env
        bilgi ".env oluşturuldu (şablon: .env.example)."
    fi

    env_yaz HOST_UID "$(id -u)" .env
    env_yaz HOST_GID "$(id -g)" .env

    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
}

imaj_derle() {
    bilgi "PHP imajı derleniyor: $PHP_IMAGE:$PHP_VERSION (docker buildx bake)..."
    docker buildx bake --load php
}

# PHP_IMAGE varsayılan yerel addan farklıysa (eğitmenin paylaştığı imaj) önce onu indirir.
imaj_hazirla() {
    if [ "$PHP_IMAGE" != "bagisto-egitimi/php" ]; then
        bilgi "Hazır PHP imajı indiriliyor: $PHP_IMAGE:$PHP_VERSION..."
        if docker pull "$PHP_IMAGE:$PHP_VERSION"; then
            return
        fi
        uyari "İmaj indirilemedi; yerelde derleniyor."
    fi
    imaj_derle
}

imaj_hazir() {
    docker image inspect "$PHP_IMAGE:$PHP_VERSION" >/dev/null 2>&1 || imaj_hazirla
}

altyapi_baslat() {
    bilgi "MySQL, Redis, Elasticsearch ve Mailpit başlatılıyor..."
    dc up -d --wait --wait-timeout 300 mysql redis elasticsearch mailpit
}

kod_indir() {
    if [ -f "$KOD_DIR/artisan" ]; then
        bilgi "Bagisto kodu zaten var (bagisto/); indirme atlandı."
        return
    fi

    mkdir -p "$KOD_DIR"
    if [ -n "$(ls -A "$KOD_DIR")" ]; then
        hata "bagisto/ klasörü boş değil ama içinde Bagisto da yok. Klasörü kontrol edin ya da ./kur.sh sifirla çalıştırın."
    fi

    bilgi "Bagisto v$BAGISTO_VERSION indiriliyor (git clone)..."
    php_calistir git -c advice.detachedHead=false clone --quiet --depth 1 \
        --branch "v$BAGISTO_VERSION" https://github.com/bagisto/bagisto.git .

    # Katılımcıların değişiklikleri "egitim" dalında birikir; git diff/git stash ile izlenebilir.
    php_calistir git switch --quiet -c egitim
}

bagimliliklar() {
    if [ -f "$KOD_DIR/vendor/autoload.php" ]; then
        bilgi "Composer bağımlılıkları zaten kurulu; atlandı."
        return
    fi

    bilgi "Composer bağımlılıkları kuruluyor..."
    php_calistir composer install --no-interaction --prefer-dist --no-progress
}

uygulama_env() {
    local f="$KOD_DIR/.env"

    if [ -f "$f" ]; then
        bilgi "bagisto/.env zaten var; değiştirilmedi."
        return
    fi

    bilgi "bagisto/.env oluşturuluyor..."
    cp "$KOD_DIR/.env.example" "$f"

    env_yaz APP_URL "http://localhost:$APP_PORT" "$f"
    env_yaz APP_TIMEZONE "$BAGISTO_TIMEZONE" "$f"
    env_yaz APP_LOCALE "$BAGISTO_LOCALE" "$f"
    env_yaz APP_CURRENCY "$BAGISTO_CURRENCY" "$f"

    env_yaz DB_CONNECTION mysql "$f"
    env_yaz DB_HOST mysql "$f"
    env_yaz DB_PORT 3306 "$f"
    env_yaz DB_DATABASE bagisto "$f"
    env_yaz DB_USERNAME bagisto "$f"
    env_yaz DB_PASSWORD bagisto "$f"

    env_yaz REDIS_HOST redis "$f"
    env_yaz CACHE_STORE redis "$f"
    env_yaz QUEUE_CONNECTION redis "$f"

    env_yaz MAIL_HOST mailpit "$f"
    env_yaz MAIL_PORT 1025 "$f"

    env_yaz ELASTICSEARCH_HOST http://elasticsearch:9200 "$f"
}

mysql_sorgu() {
    dc exec -T -e MYSQL_PWD=bagisto mysql mysql --user=bagisto --database=bagisto "$@"
}

kurulu_mu() {
    local sayi
    sayi=$(mysql_sorgu --skip-column-names --execute="SELECT COUNT(*) FROM admins" 2>/dev/null || echo 0)
    [ "${sayi:-0}" -gt 0 ] 2>/dev/null
}

kurulum() {
    bilgi "Bagisto örnek verilerle kuruluyor (birkaç dakika sürebilir)..."
    php_calistir php artisan bagisto:install --no-interaction --demo-samples
}

# Eğitim ortamı için yönetim paneli ayarları (Yapılandırma ekranında da değiştirilebilir):
# - Arama motoru: Elasticsearch (Bagisto'nun varsayılanı veritabanıdır).
# - Tam sayfa önbelleği (FPC) kapalı: açıkken misafir sayfaları bir hafta önbellekte kalır ve
#   şablon değişiklikleri görünmez.
egitim_ayarlari() {
    bilgi "Arama motoru Elasticsearch yapılıyor, tam sayfa önbelleği kapatılıyor..."
    mysql_sorgu <<'SQL'
DELETE FROM core_config
 WHERE code IN ('search_engines.general.settings.enabled',
                'search_engines.general.settings.engine',
                'cache_management.full_page_cache.settings.enabled')
   AND channel_code IS NULL AND locale_code IS NULL;
INSERT INTO core_config (code, value, channel_code, locale_code, created_at, updated_at) VALUES
  ('search_engines.general.settings.enabled', '1', NULL, NULL, NOW(), NOW()),
  ('search_engines.general.settings.engine', 'elastic', NULL, NULL, NOW(), NOW()),
  ('cache_management.full_page_cache.settings.enabled', '0', NULL, NULL, NOW(), NOW());
SQL

    php_calistir php artisan optimize:clear
    php_calistir php artisan indexer:index --type=search --mode=full
}

servisleri_baslat() {
    # Çöken bir Vite sunucusundan kalan hot dosyası stilsiz sayfalara yol açar.
    rm -f "$KOD_DIR"/public/*-vite.hot

    bilgi "Servisler başlatılıyor..."
    dc up -d --wait --wait-timeout 300
}

saglik_kontrolu() {
    command -v curl >/dev/null 2>&1 || return 0

    local kod
    kod=$(curl -s -o /dev/null -w '%{http_code}' --max-time 60 "http://localhost:$APP_PORT/" || true)
    if [ "$kod" = "200" ]; then
        bilgi "Mağaza yanıt veriyor (HTTP 200)."
    else
        uyari "Mağaza beklenen yanıtı vermedi (HTTP $kod). Günlükler: docker compose logs app web"
    fi
}

ozet() {
    cat <<EOF

Bagisto hazır.

  Mağaza          http://localhost:$APP_PORT
  Yönetim paneli  http://localhost:$APP_PORT/admin
                  admin@example.com / admin123
  Mailpit         http://localhost:$MAILPIT_PORT
  phpMyAdmin      http://localhost:$PHPMYADMIN_PORT
  Elasticsearch   http://localhost:$FORWARD_ES_PORT
  MySQL           localhost:$FORWARD_DB_PORT  (bagisto / bagisto, root / root)

  Kod             bagisto/  (git dalı: egitim)
  Komutlar        docker compose exec app php artisan ...
                  docker compose exec app composer ...

EOF
}

kur() {
    on_kosullar
    ortam_ayarlari
    imaj_hazirla
    altyapi_baslat
    kod_indir
    bagimliliklar
    uygulama_env

    if kurulu_mu; then
        bilgi "Bagisto zaten kurulu; kurulum adımı atlandı."
    else
        kurulum
        egitim_ayarlari
    fi

    servisleri_baslat
    saglik_kontrolu
    ozet
}

baslat() {
    on_kosullar
    ortam_ayarlari
    [ -f "$KOD_DIR/artisan" ] || hata "Bagisto henüz kurulmamış. Önce ./kur.sh çalıştırın."
    imaj_hazir
    servisleri_baslat
    saglik_kontrolu
    ozet
}

durdur() {
    ortam_ayarlari
    bilgi "Servisler durduruluyor (veriler korunur)..."
    dc --profile vite --profile kibana down
}

durum() {
    ortam_ayarlari
    dc --profile vite --profile kibana ps
}

sifirla() {
    on_kosullar
    ortam_ayarlari

    cat <<EOF
Bu işlem şunları SİLER:
  - MySQL veritabanı, Redis ve Elasticsearch verileri
  - bagisto/ klasörü: Bagisto kodu ve üzerinde yaptığınız TÜM değişiklikler
Ardından Bagisto baştan kurulur.
EOF
    printf "Devam etmek için 'evet' yazın: "
    local cevap
    read -r cevap
    [ "$cevap" = "evet" ] || {
        bilgi "İptal edildi."
        exit 0
    }

    dc --profile vite --profile kibana down --volumes --remove-orphans
    rm -rf "$KOD_DIR"
    kur
}

yardim() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-kur}" in
    kur) kur ;;
    baslat) baslat ;;
    durdur) durdur ;;
    durum) durum ;;
    sifirla) sifirla ;;
    yardim | -h | --help) yardim ;;
    *)
        yardim
        exit 1
        ;;
esac
