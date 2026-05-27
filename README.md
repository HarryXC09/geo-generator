# GEO 文案生成系统

基于 FastAPI + Next.js 14 的 AI 营销文案批量生成工具。内置 RAG 产品知识库，支持 10 种写作角度并行输出，适用于中小型企业 SEO 内容生产。

## 功能特点

- **10 种角度并行生成** — 产品故事、痛点解决、场景化、数据驱动、KOL 叙事等
- **RAG 产品知识库** — 上传产品信息，AI 基于真实数据进行创作，减少幻觉
- **多种写作风格** — 专业严谨、温暖治愈、幽默风趣、简洁有力、数据权威
- **Streaming 流式输出** — 逐字实时显示生成结果
- **密码认证** — 内置登录页面保护
- **局域网 + 公网访问** — 支持 Cloudflare 快速隧道
- **支持多种 LLM** — DeepSeek / OpenAI / Claude 等(通过 litellm)

## 快速开始

### 1. 环境要求

- Python 3.10+
- Node.js 18+
- npm

### 2. 配置 API Key

编辑 `start.bat`，找到 `YOUR_DEEPSEEK_API_KEY` 替换为你的真实 Key（从 [platform.deepseek.com](https://platform.deepseek.com/api_keys) 获取）。

编辑 `frontend/.env`（参考 `frontend/.env.example`）：

```env
AUTH_PASSWORD=your-password
AUTH_TOKEN=your-token
```

### 3. 一键启动

Windows 下双击 **`start.bat`**，自动完成：
1. 安装 Python 依赖
2. 安装前端依赖并构建
3. 启动后端服务 (127.0.0.1:8000)
4. 启动前端服务 (0.0.0.0:3000)
5. （如存在 cloudflared.exe）自动启动公网隧道

启动后访问 `http://localhost:3000`，输入密码登录即可。

### 4. 公网访问

双击 **`start_tunnel.bat`**（或 start.bat 会自动检测并启动），通过 Cloudflare 快速隧道生成一个公网 HTTPS 地址，可直接分享给他人使用。

### 5. 开机自启（可选）

双击 **`install_startup.bat`**，安装后每次电脑重启自动在后台启动服务。

## 项目结构

```
├── main.py                    # FastAPI 后端入口
├── knowledge_base.py          # RAG 产品知识库
├── requirements.txt           # Python 依赖
├── start.bat                  # 一键启动（后端+前端+隧道）
├── start_tunnel.bat           # Cloudflare 隧道启动（单独）
├── install_startup.bat        # 安装开机自启
├── remove_startup.bat         # 卸载开机自启
├── stop.bat                   # 停止所有服务
└── frontend/
    ├── .env.example           # 认证配置模板
    ├── app/
    │   ├── page.tsx           # 主页面
    │   ├── login/page.tsx     # 登录页
    │   ├── components/        # UI 组件
    │   └── api/auth/login/    # 登录 API
    ├── middleware.ts          # 认证中间件
    └── next.config.mjs        # Next.js 配置（含 API 代理）
```

## 自定义产品知识库

编辑 `knowledge_base.py` 中的 `PETCARE_PRODUCTS` 字典，每个产品包含：

| 字段 | 说明 | 必填 |
|------|------|------|
| name | 产品名称 | 是 |
| principle | 技术原理 | 推荐 |
| functions | 功能列表 | 推荐 |
| usage | 使用方法 | 否 |
| advantages | 产品优势 | 推荐 |
| use_scenarios | 使用场景 | 否 |

## 支持的模型

通过 [litellm](https://docs.litellm.ai/docs/providers) 支持 100+ LLM 提供商：

```
# DeepSeek
LLM_MODEL=deepseek/deepseek-chat

# OpenAI
LLM_MODEL=openai/gpt-4o

# Claude
LLM_MODEL=claude/claude-sonnet-4-20250514

# 更多见: https://docs.litellm.ai/docs/providers
```

## 技术栈

- **后端**: FastAPI + uvicorn + litellm + tenacity
- **前端**: Next.js 14 App Router + Tailwind CSS + Lucide React
- **流式**: SSE (Server-Sent Events) + ReadableStream
- **部署**: Cloudflare Tunnel (可选)
- **认证**: Next.js Middleware + httpOnly Cookie
