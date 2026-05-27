#!/bin/bash
set -e

echo "============================================"
echo "  GEO 文案系统 — 服务器一键部署"
echo "============================================"
echo ""

# ── 1. 系统更新 + 安装基础 ──
echo "[1/6] 安装系统依赖..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv curl git nginx

# ── 2. 安装 Node.js 20 ──
echo "[2/6] 安装 Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

echo "Python: $(python3 --version)"
echo "Node:   $(node --version)"

# ── 3. 拉取代码 ──
echo "[3/6] 拉取项目代码..."
cd /opt
sudo rm -rf geo-generator
sudo git clone https://github.com/HarryXC09/geo-generator.git
sudo chown -R ubuntu:ubuntu geo-generator
cd geo-generator

# ── 4. 配置后端 ──
echo "[4/6] 配置后端..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt -q

cat > .env << 'ENVEOF'
DEEPSEEK_API_KEY=sk-6b1b2e51bc284d2c8b2b419cb6dcc619
LLM_MODEL=deepseek/deepseek-chat
APP_HOST=0.0.0.0
ENVEOF

# ── 5. 构建前端 ──
echo "[5/6] 构建前端..."
cd frontend
npm install --silent
npm run build

cat > .env << 'ENVEOF'
AUTH_PASSWORD=leilingbio888
AUTH_TOKEN=physicoat-geo
ENVEOF
cd ..

# ── 6. 创建系统服务 ──
echo "[6/6] 创建系统服务 + Nginx..."

sudo tee /etc/systemd/system/geo-backend.service > /dev/null << 'SEOF'
[Unit]
Description=PetCare GEO Backend
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/geo-generator
EnvironmentFile=/opt/geo-generator/.env
ExecStart=/opt/geo-generator/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SEOF

sudo tee /etc/systemd/system/geo-frontend.service > /dev/null << 'SEOF'
[Unit]
Description=PetCare GEO Frontend
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/geo-generator/frontend
ExecStart=/usr/bin/npx next start --port 3000 --hostname 0.0.0.0
Restart=always
RestartSec=5
Environment=NODE_ENV=production
[Install]
WantedBy=multi-user.target
SEOF

sudo systemctl daemon-reload
sudo systemctl enable geo-backend geo-frontend
sudo systemctl start geo-backend
sleep 3
sudo systemctl start geo-frontend

# ── Nginx ──
sudo tee /etc/nginx/sites-available/geo > /dev/null << 'NGX'
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400s;
    }
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_buffering off;
    }
}
NGX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/geo /etc/nginx/sites-enabled/geo
sudo systemctl enable nginx
sudo systemctl restart nginx

echo ""
echo "============================================"
echo "  部署完成！"
echo ""
echo "  ✅ 访问地址: http://124.221.98.120"
echo "  🔑 登录密码: leilingbio888"
echo ""
echo "  管理命令:"
echo "    sudo systemctl status geo-backend     # 后端状态"
echo "    sudo systemctl status geo-frontend    # 前端状态"
echo "    sudo journalctl -u geo-backend -f     # 查看日志"
echo ""
echo "  如需 HTTPS + 域名:"
echo "    购买域名 → DNS 指向 124.221.98.120"
echo "    运行: sudo certbot --nginx"
echo "============================================"
