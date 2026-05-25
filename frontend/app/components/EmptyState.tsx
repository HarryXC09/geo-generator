import { FileText } from "lucide-react";

export default function EmptyState() {
  return (
    <div className="flex h-full flex-col items-center justify-center text-center px-8">
      <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-100">
        <FileText size={28} className="text-slate-300" />
      </div>
      <h2 className="text-base font-semibold text-slate-500">
        等待生成文案
      </h2>
      <p className="mt-1.5 max-w-sm text-sm text-slate-400 leading-relaxed">
        在左侧选择一个产品并配置文案参数，
        <br />
        点击「一键生成」按钮开始创作。
        <br />
        系统将并发生成 10 篇不同角度的 GEO 优化文案。
      </p>
      <div className="mt-6 grid grid-cols-5 gap-2">
        {[
          "痛点切入",
          "成分解析",
          "场景带入",
          "对比评测",
          "数据背书",
          "用户见证",
          "专家视角",
          "趋势分析",
          "问题答疑",
          "故事叙述",
        ].map((angle) => (
          <span
            key={angle}
            className="rounded-md bg-slate-50 px-2 py-1 text-[11px] text-slate-400 ring-1 ring-slate-200"
          >
            {angle}
          </span>
        ))}
      </div>
    </div>
  );
}
