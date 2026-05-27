#!/bin/bash
set -e

echo "============================================"
echo " 宠可灵 GEO 文案系统 — 服务器部署脚本"
echo "============================================"
echo ""

# ── 1. 系统更新 + 安装依赖 ──
echo "[1/6] 更新系统并安装依赖..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv curl git nginx certbot python3-certbot-nginx

# ── 2. 安装 Node.js 18 ──
echo "[2/6] 安装 Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install -g npm@latest

echo "Python: $(python3 --version)"
echo "Node:   $(node --version)"
echo "npm:    $(npm --version)"

# ── 3. 拉取代码 ──
echo "[3/6] 拉取项目代码..."
cd /opt
rm -rf geo-generator
git clone https://github.com/HarryXC09/geo-generator.git
cd geo-generator

# ── 4. 配置后端 ──
echo "[4/6] 配置后端..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 替换 API Key 为实际的
sed -i 's/YOUR_DEEPSEEK_API_KEY/sk-6b1b2e51bc284d2c8b2b419cb6dcc619/' start.bat start_backend.bat 2>/dev/null || true

# 创建 .env 配置文件
cat > /opt/geo-generator/.env << 'EOF'
DEEPSEEK_API_KEY=sk-6b1b2e51bc284d2c8b2b419cb6dcc619
LLM_MODEL=deepseek/deepseek-chat
APP_HOST=0.0.0.0
EOF

# ── 5. 配置前端 ──
echo "[5/6] 构建前端..."
cd /opt/geo-generator/frontend
npm install
npm run build

# 创建前端 .env
cat > /opt/geo-generator/frontend/.env << 'EOF'
AUTH_PASSWORD=leilingbio888
AUTH_TOKEN=physicoat-geo
EOF

# ── 6. 创建 systemd 服务 ──
echo "[6/6] 创建系统服务..."

cat > /etc/systemd/system/geo-backend.service << 'SERVICE'
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
SERVICE

cat > /etc/systemd/system/geo-frontend.service << 'SERVICE'
[Unit]
Description=PetCare GEO Frontend
After=network.target geo-backend.service
Requires=geo-backend.service

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
SERVICE

systemctl daemon-reload
systemctl enable geo-backend geo-frontend
systemctl start geo-backend geo-frontend

# ── 7. 配置 Nginx ──
echo "[7/7] 配置 Nginx..."
cat > /etc/nginx/sites-available/geo << 'NGINX'
server {
    listen 80 default_server;
    server_name _;

    # 前端静态资源
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

    # API 反向代理到后端
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
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/geo /etc/nginx/sites-enabled/geo
systemctl enable nginx
systemctl restart nginx

# ── 防火墙 ──
echo "[+] 配置防火墙..."
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true

echo ""
echo "============================================"
echo " 部署完成！"
echo ""
echo " 访问地址: http://124.221.98.120"
echo " 登录密码: leilingbio888"
echo ""
echo " 后续如果需要配置 HTTPS + 域名:"
echo "   1. 将域名 A 记录指向 124.221.98.120"
echo "   2. 运行: certbot --nginx -d 你的域名.com"
echo ""
echo " 管理命令:"
echo "   systemctl status geo-backend   # 查看后端状态"
echo "   systemctl status geo-frontend  # 查看前端状态"
echo "   systemctl restart geo-backend  # 重启后端"
echo "   journalctl -u geo-backend -f   # 查看后端日志"
echo "============================================"
