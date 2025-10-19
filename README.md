# 🧭 TraefikSwarmMonitor

## 📖 О проекте

Этот проект — практическое руководство по построению **кластерной инфраструктуры Docker Swarm**
с балансировкой через **Traefik**, развёртыванием собственного контейнера **Nginx + PHP-FPM**,
и настройкой **системы мониторинга Prometheus + Grafana + Node Exporter**.

Главная цель — **понять, как масштабировать веб-сервисы, обеспечивать отказоустойчивость и наблюдаемость**,
используя реальные DevOps-инструменты.

---

## 🧩 Используемые технологии

* **Vagrant** — автоматизация запуска виртуальных машин (Ubuntu Server).
* **VirtualBox** — гипервизор для тестовой инфраструктуры.
* **Docker + Swarm** — контейнеризация и оркестрация.
* **Traefik v2.10** — обратный прокси и балансировщик нагрузки.
* **Nginx + PHP-FPM + Supervisor** — стек веб-приложения.
* **Prometheus + Grafana + Node Exporter** — система мониторинга кластера.

---

## 🗂️ Структура проекта

```
devops-swarm-project/
├── Vagrantfile
├── stack/
│   └── docker-stack.yml
├── scripts/
│   ├── install_docker.sh
│   ├── join_worker.sh
│   └── swarm_init.sh
├── app/
│   ├── web/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── supervisord.conf
│   │   └── src/
│   │       ├── index.html
│   │       └── index.php
│   └── monitor/
│       ├── prometheus/
│       │   └── prometheus.yml
│       ├── grafana/
│       │   ├── dashboards/
│       │   └── provisioning/
│       ├── node-exporter/
│       └── docker-compose.yml
└── README.md
```

---

## 🚀 Как запускался проект

### 1️⃣ Подготовка инфраструктуры (Vagrant)

#### Vagrantfile

Создавал три виртуальные машины:

```ruby
config.vm.define "manager"
config.vm.define "prod1"
config.vm.define "prod2"
```

С IP:

```
manager → 192.168.56.10
prod1   → 192.168.56.11
prod2   → 192.168.56.12
```

После `vagrant up` выполнялись скрипты:

* `install_docker.sh` — установка Docker.
* `swarm_init.sh` — инициализация Swarm.
* `join_worker.sh` — подключение нод к кластеру.

---

### 2️⃣ Настройка Docker Swarm

После установки Docker на всех VM:

```bash
docker swarm init --advertise-addr 192.168.56.10
```

Команда `docker swarm join` добавляла ноды `prod1` и `prod2`.

---

### 3️⃣ Сборка собственного контейнера web-demo

В папке `/app/web` создавались три файла:

#### 📄 Dockerfile

```Dockerfile
FROM php:8.2-fpm

RUN apt-get update && apt-get install -y nginx supervisor && rm -rf /var/lib/apt/lists/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY src/ /var/www/html/

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80 9000

CMD ["/usr/bin/supervisord", "-n"]
```

#### 📄 nginx.conf

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

#### 📄 supervisord.conf

```ini
[supervisord]
nodaemon=true

[program:php-fpm]
command=php-fpm8.2 -F

[program:nginx]
command=nginx -g "daemon off;"
```

#### 📄 src/index.php

```php
<?php
echo "<h1>Hello from " . gethostname() . "</h1>";
?>
```

---

### 4️⃣ Создание и загрузка контейнера

После написания Dockerfile:

```bash
docker build -t idishui/web-demo:latest .
docker save -o /vagrant/idishui_web_demo.tar idishui/web-demo:latest
```

На других нодах (prod1, prod2):

```bash
docker load -i /vagrant/idishui_web_demo.tar
```

---

### 5️⃣ Развёртывание стека с Traefik

Файл `/stack/docker-stack.yml`:

```yaml
version: "3.9"

networks:
  webnet:
    driver: overlay
    attachable: true

services:
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.network=webnet"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--api.insecure=true"
      - "--api.dashboard=true"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - webnet
    deploy:
      placement:
        constraints:
          - node.role == manager

  web:
    image: idishui/web-demo:latest
    networks:
      - webnet
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == worker
      labels:
        traefik.enable: "true"
        traefik.docker.network: "webnet"
        traefik.http.routers.web.rule: "Host(`web.local`)"
        traefik.http.routers.web.entrypoints: "web"
        traefik.http.services.web.loadbalancer.server.port: "80"
```

Запуск:

```bash
docker stack deploy -c /vagrant/stack/docker-stack.yml demo_stack
```

Проверка:

```bash
curl -H "Host: web.local" http://localhost
```

Результат:

```
<h1>Hello from prod1</h1>
<h1>Hello from prod2</h1>
```

---

## 📈 Настройка мониторинга: Prometheus + Grafana + Node Exporter

### 1️⃣ Node Exporter

На каждой VM:

```bash
docker run -d \
  --name=node_exporter \
  --net=host \
  --pid=host \
  quay.io/prometheus/node-exporter
```

Доступен по порту **9100**.

---

### 2️⃣ Prometheus

#### prometheus.yml

```yaml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets:
          - "manager:9100"
          - "prod1:9100"
          - "prod2:9100"
```

Запуск:

```bash
docker run -d \
  -p 9090:9090 \
  -v /vagrant/app/monitor/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

---

### 3️⃣ Grafana

#### docker-compose.yml

```yaml
version: "3"

services:
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

Запуск:

```bash
docker-compose up -d
```

Открыть:

```
http://192.168.56.10:3000/
```

Логин: `admin / admin`

Добавляем источник данных → Prometheus → URL: `http://manager:9090`

---

## ⚠️ Основные ошибки и решения

| Ошибка                        | Причина                       | Решение                                |
| ----------------------------- | ----------------------------- | -------------------------------------- |
| 404 page not found            | Traefik не видел labels       | Перенесли метки внутрь `deploy:`       |
| php код не исполняется        | php-fpm не запущен            | Добавили `supervisord.conf`            |
| Conflicting server name "_"   | Неудалён дефолтный nginx.conf | Удалён и заменён на кастомный          |
| Образ не загружался на worker | Не экспортирован .tar         | Использовали `docker save/load`        |
| Traefik не находил сеть       | Отсутствовала overlay сеть    | Добавили `webnet` с `attachable: true` |

---

## 🎓 Чему научились

* Создавать и настраивать **Docker Swarm кластер**
* Работать с **Traefik** и его правилами маршрутизации
* Правильно строить **Dockerfile** с Supervisor
* Разворачивать **Prometheus + Grafana**
* Устранять реальные ошибки деплоя
* Анализировать **docker service logs**
* Понимать связь между **контейнерами, сетями и сервисами**

---

## ✅ Итог

Собранный стек:

* Traefik управляет маршрутизацией HTTP.
* Swarm распределяет web-контейнеры по нодам.
* Prometheus и Grafana следят за состоянием кластера.
* Пользователь открывает `web.local` и получает балансированный ответ от разных нод.

-----------
