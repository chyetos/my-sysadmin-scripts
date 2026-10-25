#!/bin/bash
set -e

echo "=== Сборка Docker-образа ==="
docker build -t my-script .

echo "=== Запуск контейнера ==="
docker run -d -p 8080:8080 --name my-app my-script

echo "=== Создание loop-устройств ==="
sudo mkdir -p /mnt/raid-lab && cd /mnt/raid-lab
sudo dd if=/dev/zero of=disk1.img bs=1M count=512
sudo dd if=/dev/zero of=disk2.img bs=1M count=512
sudo dd if=/dev/zero of=disk3.img bs=1M count=512

LOOP1=$(sudo losetup -fP --show disk1.img)
LOOP2=$(sudo losetup -fP --show disk2.img)
LOOP3=$(sudo losetup -fP --show disk3.img)

echo "=== Настройка RAID 1 ==="
yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
sudo mkfs.ext4 /dev/md0
sudo mkdir -p /mnt/raid && sudo mount /dev/md0 /mnt/raid

echo "=== Настройка LVM ==="
yes | sudo pvcreate "$LOOP3"
sudo vgcreate vg_data "$LOOP3"
yes | sudo lvcreate -L 200M -n lv_logs vg_data
sudo mkfs.ext4 /dev/vg_data/lv_logs
sudo mkdir -p /mnt/logs && sudo mount /dev/vg_data/lv_logs /mnt/logs

echo "=== Установка и настройка Nginx ==="
sudo apt install -y nginx

sudo bash -c 'cat > /etc/nginx/sites-available/my-app <<EOF
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/ssl/certs/my-app.crt;
    ssl_certificate_key /etc/ssl/private/my-app.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF'

sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "=== Генерация TLS сертификата ==="
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key \
  -out /etc/ssl/certs/my-app.crt \
  -subj "/CN=my-app.local"

sudo nginx -t && sudo systemctl reload nginx

echo "=== Настройка systemd-службы ==="
sudo bash -c 'cat > /etc/systemd/system/my-app.service <<EOF
[Unit]
Description=my-app service
After=docker.service
Requires=docker.service

[Service]
ExecStart=docker start -a my-app
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable my-app
sudo systemctl start my-app

sleep 3

echo "=== Проверка ==="
curl -kI https://127.0.0.1
