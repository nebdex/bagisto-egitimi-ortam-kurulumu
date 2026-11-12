// Vite geliştirme sunucusu için küçük bir TCP aktarıcı.
//
// Bagisto'nun paket vite.config.js dosyaları server.host değerini VITE_HOST'tan alır ve
// laravel-vite-plugin bu değeri public/*-vite.hot dosyasına yazar. Tarayıcının bu adrese
// ulaşabilmesi için VITE_HOST=localhost kalmalı; ama localhost'ta dinleyen bir sunucuya
// konteyner dışından erişilemez. Bu betik 0.0.0.0:VITE_PROXY_PORT adresinde dinler ve
// gelen bağlantıları konteyner içindeki localhost:VITE_PORT'a aktarır. Böylece Bagisto'nun
// kaynak koduna dokunmadan ana makinedeki tarayıcı http://localhost:VITE_PORT adresine ulaşır.
//
// Vite "localhost"u konteynerde ::1 ya da 127.0.0.1 olarak açabilir; aktarıcı ikisini de dener
// ve çalışanı hatırlar.

import net from "node:net";

const listenPort = Number(process.env.VITE_PROXY_PORT || 5174);
const targetPort = Number(process.env.VITE_PORT || 5173);
const hosts = ["::1", "127.0.0.1"];
let preferred = 0;

function connectUpstream(client, attempt = 0) {
    const index = (preferred + attempt) % hosts.length;
    const upstream = net.connect({ host: hosts[index], port: targetPort });

    upstream.once("connect", () => {
        preferred = index;
        upstream.on("error", () => client.destroy());
        client.on("error", () => upstream.destroy());
        client.pipe(upstream).pipe(client);
    });

    upstream.once("error", () => {
        upstream.destroy();

        if (attempt + 1 < hosts.length) {
            connectUpstream(client, attempt + 1);
        } else {
            client.destroy();
        }
    });
}

net.createServer((client) => {
    client.on("error", () => client.destroy());
    connectUpstream(client);
}).listen(listenPort, "0.0.0.0");
