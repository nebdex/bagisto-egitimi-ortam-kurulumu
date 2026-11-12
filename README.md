# Bagisto eğitimi: yerel ortam

Bagisto'yu kendi bilgisayarınızda, örnek ürünlerle birlikte, Docker üzerinde tek komutla kurar. Bu ortam, hazır bir mağaza üzerinde çalışabilmeniz içindir.

## Gerekenler

- Docker: macOS'ta [Docker Desktop](https://www.docker.com/products/docker-desktop/) ya da
  [OrbStack](https://orbstack.dev), Windows'ta WSL2 ile Docker Desktop, Linux'ta Docker Engine. Compose v2 ve
  Buildx, Docker Desktop ve OrbStack ile birlikte gelir.
- En az 8 GB RAM (Docker'a en az 4 GB ayrılmış olmalı) ve yaklaşık 10 GB boş disk.
- İnternet bağlantısı (ilk kurulumda imajlar, Bagisto kodu ve Composer paketleri indirilir).
- Windows'ta bu klasörü WSL2'nin Linux dosya sistemine koyun (ör. ev klasörünüzün altına) ve komutları WSL2
  terminalinden çalıştırın. `/mnt/c/...` altında ortam çok yavaş çalışır.
- Linux'ta Elasticsearch için: `sudo sysctl -w vm.max_map_count=262144`.

Bilgisayarınızda PHP, Composer, MySQL ya da Node.js kurulu olması gerekmez; hepsi konteynerlerin içindedir.

## Kurulum

```bash
./kur.sh
```

Script şunları yapar:

1. PHP imajını derler (`docker buildx bake`).
2. MySQL, Redis, Elasticsearch ve Mailpit'i başlatır.
3. Bagisto'yu GitHub'dan `bagisto/` klasörüne indirir (`.env` içindeki `BAGISTO_VERSION`; varsayılan 2.5.1) ve
   `egitim` adlı bir git dalı açar.
4. Composer bağımlılıklarını kurar.
5. Bagisto'yu örnek ürünlerle kurar (`php artisan bagisto:install --no-interaction --demo-samples`).
6. Arama motorunu Elasticsearch yapar ve tam sayfa önbelleğini kapatır (aşağıya bakın).
7. Tüm servisleri başlatır ve adresleri yazar.

İlk kurulum internet hızına göre 10–20 dakika sürer. Script'i tekrar çalıştırmak güvenlidir; yapılmış adımları
atlar.

## Adresler

| Ne | Adres | Giriş |
|---|---|---|
| Mağaza | http://localhost:8000 | |
| Yönetim paneli | http://localhost:8000/admin | `admin@example.com` / `admin123` |
| Mailpit (giden e-postalar) | http://localhost:8025 | |
| phpMyAdmin | http://localhost:8081 | otomatik (root) |
| Elasticsearch | http://localhost:9200 | |
| MySQL | `localhost:3306` | `bagisto` / `bagisto`, `root` / `root` |

Portlar `.env` içinden değiştirilebilir. `APP_PORT` değişirse `bagisto/.env` içindeki `APP_URL`'yi de
aynı porta göre güncelleyin.

## Günlük kullanım

```bash
./kur.sh baslat     # servisleri başlatır
./kur.sh durdur     # servisleri durdurur; veriler korunur
./kur.sh durum      # servislerin durumunu gösterir
```

Bagisto komutları `app` konteynerinde çalışır:

```bash
docker compose exec app php artisan route:list
docker compose exec app php artisan optimize:clear
docker compose exec app composer require vendor/paket
docker compose exec app bash
```

Günlükler:

```bash
docker compose logs -f app queue
tail -f bagisto/storage/logs/laravel.log
```

Kod `bagisto/` klasöründedir ve konteynerlere bağlıdır: editörde yaptığınız değişiklik hemen etkili olur.
Değişikliklerinizi `git status` ve `git diff` ile izleyebilir, `git stash` ya da `git checkout -- .` ile geri
alabilirsiniz.

## Ortamdaki servisler

| Servis | Görevi |
|---|---|
| `app` | PHP 8.4-FPM; Bagisto uygulaması |
| `web` | Nginx; `bagisto/public` klasörünü sunar |
| `queue` | Kuyruk işçisi (`queue:listen`; kod değişikliklerini yeniden başlatmadan alır) |
| `scheduler` | Zamanlanmış görevler (`schedule:work`) |
| `mysql` | MySQL 8.4 |
| `redis` | Önbellek ve kuyruk |
| `elasticsearch` | Ürün arama (Elasticsearch 8) |
| `mailpit` | Gönderilen tüm e-postaları yakalar; hiçbir e-posta dışarı çıkmaz |
| `phpmyadmin` | Veritabanını tarayıcıdan incelemek için |
| `kibana` | İsteğe bağlı; Elasticsearch indekslerini incelemek için |
| `vite` | İsteğe bağlı; tema geliştirirken sıcak yenileme |

PHP imajında Bagisto'nun istediği ve kullanabildiği tüm eklentiler vardır: bcmath, calendar, ctype, curl, dom,
exif, fileinfo, filter, gd, gmp, hash, iconv, imagick, intl, json, mbstring, mysqli, opcache, openssl, pcntl,
pcre, pdo, pdo_mysql, pdo_pgsql, pgsql, redis, session, simplexml, soap, sockets, tokenizer, xdebug (kapalı),
xml, xmlreader, xmlwriter, zip, zlib. İmajda ayrıca Composer 2, Node.js 22 ve git vardır.

## Kurulumun eğitim için değiştirdiği ayarlar

Bagisto'nun varsayılanlarından farklı olan ayarlar şunlardır; hepsi yönetim panelinden ya da `bagisto/.env`'den
geri alınabilir.

- **Arama motoru Elasticsearch.** Bagisto'nun varsayılanı veritabanıdır. Ayar: Yapılandırma → Search Engines.
- **Tam sayfa önbelleği kapalı.** Açıkken misafir sayfaları bir hafta önbellekte kalır ve şablon değişiklikleri
  görünmez. Önbellekle ilgili bir konu çalışılırken Yapılandırma → Cache Management ekranından açılabilir.
- **Önbellek ve kuyruk Redis'te** (`CACHE_STORE=redis`, `QUEUE_CONNECTION=redis`), e-postalar Mailpit'e gider,
  saat dilimi `Europe/Istanbul`.

Mağaza dili ve para birimi varsayılan olarak İngilizce ve USD'dir. Türkçe ve TL ile kurmak için ilk kurulumdan
önce `.env` içinde `BAGISTO_LOCALE=tr` ve `BAGISTO_CURRENCY=TRY` yapın; örnek ürünlerin hepsinin
Türkçe çevirisi vardır.

## Tema geliştirme (Vite)

Bagisto'nun derlenmiş ön yüz dosyaları kodla birlikte gelir; yalnızca PHP ve Blade üzerinde çalışırken Vite
gerekmez. CSS veya JavaScript değiştirirken sıcak yenileme için:

```bash
docker compose --profile vite up vite                    # mağaza teması (Shop)
VITE_PAKET=Admin docker compose --profile vite up vite   # yönetim paneli (Admin)
```

İlk çalıştırmada paketin npm bağımlılıkları kurulur. Ctrl+C ile durdurduğunuzda sayfalar yeniden derlenmiş
dosyaları kullanır. Değişiklikleri kalıcı olarak derlemek için:

```bash
docker compose exec -w /var/www/html/packages/Webkul/Shop app npm run build
```

Aynı anda tek paket için Vite çalıştırılabilir.

## Xdebug

`.env` içinde `XDEBUG_MODE=debug` yapın ve `docker compose up -d` çalıştırın. Xdebug 9003 portundan
editörünüze bağlanır; istek başlatmak için tarayıcı eklentisi ya da `XDEBUG_TRIGGER` kullanın. Editörde yol
eşlemesi: `bagisto` → `/var/www/html`. Xdebug'ın editöre bağlanması henüz bir editörle denenmedi.

## Baştan kurmak

```bash
./kur.sh sifirla
```

Veritabanını, Redis ve Elasticsearch verilerini ve `bagisto/` klasörünü (yaptığınız tüm değişikliklerle) siler,
ardından baştan kurar. Onay için `evet` yazmanız istenir.

## Sorun giderme

- **Port kullanımda:** `.env` içinde ilgili portu değiştirip `./kur.sh baslat` çalıştırın.
- **Elasticsearch başlamıyor:** Docker'a ayrılan belleği artırın; düşük bellekli makinelerde `.env` içinde
  `ELASTICSEARCH_HEAP=256m` yapın.
- **Sayfalar stilsiz:** Çöken bir Vite sunucusundan `bagisto/public/*-vite.hot` dosyası kalmış olabilir;
  `./kur.sh baslat` bu dosyaları siler.
- **`.env` değişikliği etkili olmadı:** `docker compose exec app php artisan optimize:clear`.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `kur.sh` | Kurulum ve yönetim script'i |
| `compose.yaml` | Servis tanımları (Docker Compose) |
| `docker-bake.hcl` | PHP imajının derleme tanımı (Docker Buildx Bake) |
| `docker/php/` | PHP imajı: `Dockerfile`, `php.ini`, PHP-FPM ayarları, Vite yardımcıları |
| `docker/nginx/default.conf` | Nginx ayarları |
| `.env.example` | Ortam ayarları şablonu; `kur.sh` bunu `.env` olarak kopyalar |
| `bagisto/` | Bagisto kodu; `kur.sh` indirir, bu depoya girmez |
