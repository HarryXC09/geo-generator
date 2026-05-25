"""
宠可灵GEO文案生成系统 — FastAPI 后端
=====================================
技术栈: FastAPI, litellm, asyncio, tenacity, SSE
核心: 10种角度并发调用LLM, 流式逐篇推送
"""

import asyncio
import json
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from enum import Enum
from typing import AsyncGenerator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from litellm import acompletion
from pydantic import BaseModel, Field, field_validator
from knowledge_base import PETCARE_PRODUCTS, get_product_context
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("petcare-geo")

# ---------------------------------------------------------------------------
# Configuration  (可通过环境变量覆盖)
# ---------------------------------------------------------------------------
class Settings:
    LLM_MODEL: str = os.getenv("LLM_MODEL", "gpt-4o")
    LLM_TEMPERATURE: float = float(os.getenv("LLM_TEMPERATURE", "0.8"))
    LLM_MAX_TOKENS: int = int(os.getenv("LLM_MAX_TOKENS", "2048"))
    LLM_TIMEOUT: int = int(os.getenv("LLM_TIMEOUT", "60"))
    LLM_RETRY_ATTEMPTS: int = int(os.getenv("LLM_RETRY_ATTEMPTS", "3"))
    CONCURRENT_COUNT: int = int(os.getenv("CONCURRENT_COUNT", "10"))
    APP_HOST: str = os.getenv("APP_HOST", "127.0.0.1")
    APP_PORT: int = int(os.getenv("APP_PORT", "8000"))


settings = Settings()

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------
class CopyTypeEnum(str, Enum):
    XIAOHONGSHU = "小红书种草"
    ZHIHU = "知乎科普"
    NEWS = "新闻通稿"
    WECHAT = "公众号推文"
    DOUYIN = "抖音脚本"


class ToneEnum(str, Enum):
    HUMOROUS = "幽默"
    PROFESSIONAL = "专业"
    WARM = "亲切"
    URGENT = "紧迫感"
    AUTHORITATIVE = "权威"


class CopyRequest(BaseModel):
    product_id: str = Field(
        ...,
        min_length=1,
        max_length=128,
        description=(
            "产品标识符（英文简写）。可用值：\n"
            + "\n".join(
                f"  - `{k}`：{PETCARE_PRODUCTS[k]['name']}"
                for k in PETCARE_PRODUCTS
            )
        ),
    )
    copy_type: CopyTypeEnum = Field(..., description="文案类型")
    tone: ToneEnum = Field(default=ToneEnum.PROFESSIONAL, description="语气风格")
    use_emojis: bool = Field(default=False, description="是否使用emoji")

    @field_validator("product_id")
    @classmethod
    def validate_product_id(cls, v: str) -> str:
        v = v.strip()
        if v not in PETCARE_PRODUCTS:
            valid = ", ".join(PETCARE_PRODUCTS.keys())
            raise ValueError(f"无效 product_id，可用值: {valid}")
        return v


class CopyResult(BaseModel):
    angle: str
    angle_description: str
    content: str
    status: str = "success"
    error: str | None = None


class HealthResponse(BaseModel):
    status: str = "ok"
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    model: str = settings.LLM_MODEL


# ---------------------------------------------------------------------------
# 10 Writing Angles  — 保证并发输出的多样性与GEO覆盖
# ---------------------------------------------------------------------------
ANGLES: list[dict[str, str]] = [
    {
        "name": "痛点切入",
        "description": "从养宠用户的常见痛点（掉毛、泪痕、挑食等）切入，引发共鸣后自然引出产品解决方案",
        "prompt_suffix": "请用「先抛痛点 → 分析原因 → 引出方案」的结构，开头用一句扎心的问句抓住读者",
    },
    {
        "name": "成分解析",
        "description": "深入分析产品的核心成分/配方，用科学数据和专业术语建立信任感",
        "prompt_suffix": "请详细拆解产品成分表，引用具体的营养成分数据和配比，用「研究表明」「根据XX检测」等事实性表述",
    },
    {
        "name": "场景带入",
        "description": "构建一个具体的养宠生活场景（遛狗后清洁、出差前准备等），在场景中自然植入产品使用",
        "prompt_suffix": "请用叙事手法构建一个具体场景，使用「上周末」「前天晚上」等时间锚点，让读者有代入感",
    },
    {
        "name": "对比评测",
        "description": "将产品与市面同类产品进行多维度对比，突出差异化优势",
        "prompt_suffix": "请使用表格化思维做对比，从价格、成分、效果、安全性等维度列出差异，给出推荐理由",
    },
    {
        "name": "数据背书",
        "description": "引用销量数据、用户增长、实验室检测报告等硬数据，增强说服力",
        "prompt_suffix": "请引用具体数据（销量、好评率、复购率、检测报告编号等），用「数据显示」「据统计」等事实性表述",
    },
    {
        "name": "用户见证",
        "description": "以真实用户口吻讲述使用前后的变化，用「素人视角」增强可信度",
        "prompt_suffix": "请以第一人称「我」的口吻讲述，包含具体的时间线和使用前后对比，突出真实感",
    },
    {
        "name": "专家视角",
        "description": "以宠物医生/营养师/行为顾问等专业身份，从专业角度推荐产品",
        "prompt_suffix": "请以「作为一名宠物XX师」开头，引用专业术语和临床经验，用「建议」「推荐」等权威措辞",
    },
    {
        "name": "趋势分析",
        "description": "从宠物行业趋势、消费升级视角切入，把产品定位为「行业新标准」",
        "prompt_suffix": "请从行业宏观趋势入手，引用市场报告数据，分析养宠消费升级的大背景，再落到产品本身",
    },
    {
        "name": "问题答疑",
        "description": "用Q&A形式组织内容，每个问题对应一个产品卖点，结构清晰易于AI摘要抓取",
        "prompt_suffix": "请用「Q1/A1、Q2/A2」的格式组织，每个问答对应一个产品核心卖点，小标题用加粗标记",
    },
    {
        "name": "故事叙述",
        "description": "用品牌故事/创始故事/产品研发故事串联卖点，情感驱动转化",
        "prompt_suffix": "请用「起承转合」的故事结构，包含研发过程中的某个真实细节，让卖点自然融入叙事",
    },
]

# ---------------------------------------------------------------------------
# Prompt Builder  (GEO 优化)
# ---------------------------------------------------------------------------
GEO_SYSTEM_PROMPT = """你是一个专业的宠物行业文案写手，擅长为AI搜索引擎（如Perplexity、Google AI Overview）编写高可见度内容。

## GEO 写作规则（必须遵守）
1.  **结构清晰**：必须包含抓人的标题 + 分层小标题 + 段落分明
2.  **事实优先**：多使用事实性描述（"研究表明""数据显示""根据实验室检测"），少用空洞形容词
3.  **逻辑连接**：多用「因此」「例如」「具体来说」「值得注意的是」「从另一个角度来看」等逻辑连接词
4.  **关键词自然融入**：将「宠物」「猫狗」「喂养」「健康」等核心关键词自然地分布在全文各处
5.  **段落短小**：每段不超过 3-4 句，便于AI摘要片段截取
6.  **拒绝营销腔**：禁止使用「赶紧抢购」「限时优惠」「错过等一年」等促销话术，保持客观推荐语调
7.  **结尾引导**：以开放式结尾收束，引导读者进一步了解产品细节"""


def build_system_prompt(
    copy_type: str,
    tone: str,
    use_emojis: bool,
    angle_name: str,
    angle_desc: str,
    product_context: str,
) -> str:
    """构建 GEO 系统级 prompt，注入 RAG 产品上下文与反幻觉护栏"""
    emoji_rule = ""
    if use_emojis:
        emoji_rule = "- 在标题和段落结尾适当使用 1-2 个相关 emoji 增强表现力（如 🐱🐶✨）"

    tone_map = {
        "幽默": "语言轻松幽默，适当使用拟人化表达，让读者会心一笑",
        "专业": "语言严谨专业，使用行业术语和数据支撑，建立权威感",
        "亲切": "语言温暖贴心，像朋友聊天一样娓娓道来，拉近距离",
        "紧迫感": "语气略带紧迫，强调问题的严重性和及时解决的重要性",
        "权威": "语言笃定自信，引用权威来源，结论明确不模棱两可",
    }
    tone_instruction = tone_map.get(tone, tone_map["专业"])

    return f"""{GEO_SYSTEM_PROMPT}

## 产品上下文（RAG 知识挂载 — 精准创作依据）
{product_context}

## ⚠️ 严格创作约束（法律合规 — 必须遵守）
你必须严格基于 <Product_Context> 中提供的产品原理、检测数据和竞品优势进行创作。
绝对禁止编造产品不存在的成分、功效或夸大检测数据。
必须重点突出产品的"纯物理机制"和"经口无毒/安全性"特征。
否则将引发严重的法律风险。

## 本次写作要求
- **文案类型**：{copy_type}
- **写作角度**：{angle_name} — {angle_desc}
- **语气风格**：{tone_instruction}
{emoji_rule}

## 角度补充指导
{angle_desc}。
写作时请始终围绕这个核心角度展开，确保与其他角度有明显差异。"""


def build_user_prompt(product_id: str, angle_prompt_suffix: str) -> str:
    """构建用户 prompt"""
    return f"""请为宠物产品「{product_id}」生成一篇 {settings.CONCURRENT_COUNT} 篇系列文案之一。

{angle_prompt_suffix}

要求：标题醒目、正文不少于 400 字、段落层次分明、信息密度高。"""


# ---------------------------------------------------------------------------
# LLM 调用 （含 tenacity 重试 + 超时熔断）
# ---------------------------------------------------------------------------
class LLMTimeoutError(Exception):
    """自定义 LLM 超时异常"""
    pass


@retry(
    stop=stop_after_attempt(settings.LLM_RETRY_ATTEMPTS),
    wait=wait_exponential(multiplier=1, min=2, max=15),
    retry=retry_if_exception_type(
        (TimeoutError, ConnectionError, LLMTimeoutError)
    ),
    before_sleep=lambda retry_state: logger.warning(
        "LLM 调用第 %d 次失败 (%s)，%.0fs 后重试...",
        retry_state.attempt_number,
        retry_state.outcome.exception() if retry_state.outcome else "unknown",
        retry_state.next_action.sleep if retry_state.next_action else 0,
    ),
)
async def call_llm(messages: list[dict]) -> str:
    """调用 litellm acompletion，携带超时熔断"""
    try:
        response = await asyncio.wait_for(
            acompletion(
                model=settings.LLM_MODEL,
                messages=messages,
                temperature=settings.LLM_TEMPERATURE,
                max_tokens=settings.LLM_MAX_TOKENS,
                request_timeout=settings.LLM_TIMEOUT,
                fallbacks=[],
            ),
            timeout=settings.LLM_TIMEOUT + 10,
        )
    except asyncio.TimeoutError:
        raise LLMTimeoutError(
            f"LLM 调用超时 (>{settings.LLM_TIMEOUT + 10}s)"
        ) from None

    # 提取文本
    content = response.choices[0].message.content
    if not content or not content.strip():
        raise ValueError("LLM 返回空内容")
    return content.strip()


# ---------------------------------------------------------------------------
# SSE Generator  — 10个并发任务 + Queue 逐篇推送
# ---------------------------------------------------------------------------
async def generate_copies_sse(
    request_id: str,
    product_id: str,
    copy_type: str,
    tone: str,
    use_emojis: bool,
) -> AsyncGenerator[str, None]:
    """
    核心并发逻辑：
    1. 为每个角度构建 prompt
    2. 通过 asyncio.gather 并发发起10个LLM请求
    3. 每完成一篇立即通过 SSE 推送给前端
    4. 全部完成后发送 [DONE] 信号
    """
    queue: asyncio.Queue = asyncio.Queue()
    total = len(ANGLES)

    # 用于在断开时取消后台任务
    worker_tasks: list[asyncio.Task] = []
    monitor_task: asyncio.Task | None = None

    # 先发送一个开始事件（含元信息）
    yield f"data: {json.dumps({'event': 'start', 'total': total, 'request_id': request_id})}\n\n"

    async def worker(angle: dict) -> None:
        """单个角度的工作协程"""
        angle_name = angle["name"]
        try:
            product_context = get_product_context(product_id)
            messages = [
                {"role": "system", "content": build_system_prompt(
                    copy_type, tone, use_emojis,
                    angle_name, angle["description"],
                    product_context,
                )},
                {"role": "user", "content": build_user_prompt(product_id, angle["prompt_suffix"])},
            ]
            logger.info("[%s] 开始生成「%s」角度...", request_id[:8], angle_name)

            content = await call_llm(messages)

            logger.info("[%s] 「%s」角度生成完成 (%d chars)", request_id[:8], angle_name, len(content))

            await queue.put({
                "event": "copy",
                "index": 0,  # 由 monitor 填充
                "total": total,
                "angle": angle_name,
                "angle_description": angle["description"],
                "content": content,
                "status": "success",
                "request_id": request_id,
            })
        except Exception as exc:
            logger.error("[%s] 「%s」角度生成失败: %s", request_id[:8], angle_name, exc)
            await queue.put({
                "event": "copy",
                "index": 0,
                "total": total,
                "angle": angle_name,
                "angle_description": angle["description"],
                "content": "",
                "status": "error",
                "error": str(exc),
                "request_id": request_id,
            })

    # 启动所有 worker
    worker_tasks = [asyncio.create_task(worker(angle)) for angle in ANGLES]

    async def monitor() -> None:
        """等待所有任务完成，然后发送 sentinel"""
        await asyncio.gather(*worker_tasks, return_exceptions=True)
        await queue.put(None)  # sentinel

    monitor_task = asyncio.create_task(monitor())

    # 从队列读取结果，逐篇推送
    completed = 0
    success_count = 0
    try:
        while completed < total:
            result = await queue.get()
            if result is None:
                break
            # 填充 index
            result["index"] = completed
            if result.get("status") == "success":
                success_count += 1
            yield f"data: {json.dumps(result, ensure_ascii=False)}\n\n"
            completed += 1
    except (GeneratorExit, asyncio.CancelledError):
        # 客户端断开连接 → 取消所有后台任务
        logger.warning("[%s] 客户端断开，正在取消 %d 个后台任务...", request_id[:8], len(worker_tasks))
        raise
    finally:
        # 清理后台任务
        if monitor_task and not monitor_task.done():
            monitor_task.cancel()
        for t in worker_tasks:
            if not t.done():
                t.cancel()
        if worker_tasks or (monitor_task and not monitor_task.done()):
            await asyncio.gather(
                *[t for t in [monitor_task, *worker_tasks] if t and not t.done()],
                return_exceptions=True,
            )

    # 发送完成事件
    yield (
        f"data: {json.dumps({
            'event': 'done',
            'total': total,
            'success_count': success_count,
            'request_id': request_id,
        }, ensure_ascii=False)}\n\n"
    )
    logger.info(
        "[%s] 推送完毕: %d/%d 成功", request_id[:8], success_count, total,
    )


# ---------------------------------------------------------------------------
# FastAPI App
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("宠可灵GEO文案生成系统启动 — 模型: %s", settings.LLM_MODEL)
    logger.info("产品知识库已加载，共 %d 款产品", len(PETCARE_PRODUCTS))
    for key, product in PETCARE_PRODUCTS.items():
        logger.debug("  [%s] %s", key, product["name"])
    yield
    logger.info("服务关闭")


app = FastAPI(
    title="宠可灵GEO文案生成系统",
    description="基于FastAPI + LiteLLM的GEO文案并发生成接口，支持SSE流式推送",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — 允许前端跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/health", response_model=HealthResponse, tags=["系统"])
async def health_check():
    """健康检查"""
    return HealthResponse()


@app.post("/api/v1/generate_copy")
async def generate_copy(req: CopyRequest):
    """
    生成 10 篇 GEO 优化文案（流式 SSE）
    - 使用 asyncio.gather 并发调用 10 次 LLM
    - 每完成一篇即 SSE 推送
    - 支持重试熔断
    """
    request_id = uuid.uuid4().hex
    logger.info(
        "[%s] 收到请求 — product=%s type=%s tone=%s emoji=%s",
        request_id[:8], req.product_id, req.copy_type.value, req.tone.value, req.use_emojis,
    )

    return StreamingResponse(
        generate_copies_sse(
            request_id=request_id,
            product_id=req.product_id,
            copy_type=req.copy_type.value,
            tone=req.tone.value,
            use_emojis=req.use_emojis,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
            "X-Request-ID": request_id,
        },
    )


# ---------------------------------------------------------------------------
# Global Exception Handlers
# ---------------------------------------------------------------------------
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """全局异常兜底"""
    logger.exception("未捕获的异常: %s", exc)
    return StreamingResponse(
        iter([
            f"data: {json.dumps({'event': 'error', 'error': f'服务器内部错误: {str(exc)}'})}\n\n"
        ]),
        media_type="text/event-stream",
        status_code=500,
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.APP_HOST,
        port=settings.APP_PORT,
        reload=False,
        log_level="info",
    )
