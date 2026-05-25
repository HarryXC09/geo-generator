"use client";

import { Sparkles } from "lucide-react";

/* ── data ─────────────────────────────────────────────────────────────── */

export const PRODUCTS: Record<string, string> = {
  external_repellent_spray: "外驱防护喷雾（145ml）",
  deodorant_spray: "免洗除臭喷雾（145ml）",
  ear_drops: "耳怡滴液（30ml/60ml）",
  eye_drops: "宠星眸滴眼液（8ml）",
  cleaning_mousse: "宠物清洁慕斯（100ml）",
  oral_spray: "宠物口腔喷雾（60ml）",
  nasal_drops: "宠物滴鼻液（8ml）",
  exotic_pet_spray: "异宠清洁喷雾（100ml）",
  household_spray: "家居喷雾（300ml）",
  environmental_deodorizer: "环境除臭喷雾（300ml）",
  cleaning_gloves: "宠物免洗清洁手套",
  paw_gel: "宠物爪垫清洁护理凝胶（50g）",
};

export const COPY_TYPES = [
  "小红书种草",
  "知乎科普",
  "新闻通稿",
  "公众号推文",
  "抖音脚本",
] as const;

export const TONES = ["幽默", "专业", "亲切", "紧迫感", "权威"] as const;

/* ── Props ────────────────────────────────────────────────────────────── */

interface ControlPanelProps {
  productId: string;
  onChangeProduct: (v: string) => void;
  copyType: string;
  onChangeCopyType: (v: string) => void;
  tone: string;
  onChangeTone: (v: string) => void;
  useEmojis: boolean;
  onChangeEmojis: (v: boolean) => void;
  onGenerate: () => void;
  loading: boolean;
}

/* ── Component ────────────────────────────────────────────────────────── */

export default function ControlPanel({
  productId,
  onChangeProduct,
  copyType,
  onChangeCopyType,
  tone,
  onChangeTone,
  useEmojis,
  onChangeEmojis,
  onGenerate,
  loading,
}: ControlPanelProps) {
  return (
    <aside className="w-[350px] shrink-0 h-screen overflow-y-auto border-r border-slate-200 bg-white flex flex-col">
      {/* ---- Header ---- */}
      <div className="px-6 pt-6 pb-4 border-b border-slate-100">
        <div className="flex items-center gap-2.5 mb-1">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-emerald-600 text-white">
            <Sparkles size={18} />
          </div>
          <span className="text-sm font-semibold tracking-wide text-emerald-700 uppercase">
            宠可灵
          </span>
        </div>
        <h1 className="text-base font-bold text-slate-800">
          GEO 文案工作台
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          AI 驱动的宠物行业内容生成
        </p>
      </div>

      {/* ---- Form ---- */}
      <div className="flex-1 px-6 py-5 space-y-5">
        {/* 产品选择 */}
        <Field label="产品">
          <select
            value={productId}
            onChange={(e) => onChangeProduct(e.target.value)}
            disabled={loading}
            className="field-select"
          >
            <option value="" disabled>
              请选择产品…
            </option>
            {Object.entries(PRODUCTS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </select>
        </Field>

        {/* 文案类型 */}
        <Field label="文案类型">
          <select
            value={copyType}
            onChange={(e) => onChangeCopyType(e.target.value)}
            disabled={loading}
            className="field-select"
          >
            {COPY_TYPES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </Field>

        {/* 语气风格 */}
        <Field label="语气风格">
          <select
            value={tone}
            onChange={(e) => onChangeTone(e.target.value)}
            disabled={loading}
            className="field-select"
          >
            {TONES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </Field>

        {/* Emoji 开关 */}
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-slate-700">
            使用 Emoji
          </span>
          <SwitchToggle
            checked={useEmojis}
            onChange={onChangeEmojis}
            disabled={loading}
          />
        </div>
      </div>

      {/* ---- Generate Button ---- */}
      <div className="px-6 pb-6 pt-2 border-t border-slate-100">
        <button
          onClick={onGenerate}
          disabled={loading || !productId}
          className="btn-primary"
        >
          {loading ? (
            <span className="flex items-center justify-center gap-2">
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
              生成中…
            </span>
          ) : (
            <span className="flex items-center justify-center gap-2">
              <Sparkles size={16} />
              一键生成 10 篇 GEO 文案
            </span>
          )}
        </button>

        {!productId && !loading && (
          <p className="text-xs text-slate-400 text-center mt-2">
            请先选择一个产品
          </p>
        )}
      </div>
    </aside>
  );
}

/* ── Sub-components ───────────────────────────────────────────────────── */

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-1.5">
      <span className="text-sm font-medium text-slate-700">{label}</span>
      {children}
    </label>
  );
}

function SwitchToggle({
  checked,
  onChange,
  disabled,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2 ${
        checked ? "bg-emerald-600" : "bg-slate-200"
      }`}
    >
      <span
        className={`pointer-events-none inline-block h-4 w-4 rounded-full bg-white shadow transition-transform ${
          checked ? "translate-x-4" : "translate-x-0"
        }`}
      />
    </button>
  );
}
