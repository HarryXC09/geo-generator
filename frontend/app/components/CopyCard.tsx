"use client";

import { Copy, Check } from "lucide-react";
import { useState, useCallback } from "react";

/* ── Types ────────────────────────────────────────────────────────────── */

export interface CopyData {
  index: number;
  angle: string;
  angle_description: string;
  content: string;
  status: "success" | "error";
  error?: string;
}

/* ── Props ────────────────────────────────────────────────────────────── */

interface CopyCardProps {
  data: CopyData;
}

/* ── Component ────────────────────────────────────────────────────────── */

export default function CopyCard({ data }: CopyCardProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(data.content);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // fallback for older browsers
      const textarea = document.createElement("textarea");
      textarea.value = data.content;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }, [data.content]);

  return (
    <article
      className="group relative flex flex-col rounded-xl border border-slate-200 bg-white shadow-sm transition-all hover:shadow-md animate-fade-in"
      style={{ animationDelay: `${data.index * 80}ms` }}
    >
      {/* ---- Header ---- */}
      <div className="flex items-start justify-between gap-3 border-b border-slate-100 px-4 py-3.5">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center rounded-md bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700 ring-1 ring-inset ring-emerald-600/20">
              #{data.index + 1}
            </span>
            <h3 className="text-sm font-semibold text-slate-800 truncate">
              {data.angle}
            </h3>
          </div>
          <p className="mt-0.5 text-xs text-slate-400 leading-relaxed line-clamp-1">
            {data.angle_description}
          </p>
        </div>

        {/* Copy button */}
        <button
          onClick={handleCopy}
          className="shrink-0 rounded-md p-1.5 text-slate-300 opacity-0 transition-all hover:bg-slate-100 hover:text-slate-600 group-hover:opacity-100 focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
          title="复制全文"
        >
          {copied ? <Check size={15} className="text-emerald-500" /> : <Copy size={15} />}
        </button>
      </div>

      {/* ---- Content ---- */}
      {data.status === "success" ? (
        <div className="px-4 py-3.5 max-h-[420px] overflow-y-auto">
          <pre className="whitespace-pre-wrap break-words text-sm text-slate-600 leading-relaxed font-sans">
            {data.content}
          </pre>
        </div>
      ) : (
        <div className="px-4 py-6 text-center">
          <p className="text-sm text-red-500">生成失败</p>
          {data.error && (
            <p className="mt-1 text-xs text-slate-400 line-clamp-2">
              {data.error}
            </p>
          )}
        </div>
      )}

      {/* ---- Copy toast ---- */}
      {copied && (
        <div className="absolute -top-2 right-10 rounded-md bg-emerald-600 px-2.5 py-1 text-xs font-medium text-white shadow-sm">
          已复制
        </div>
      )}
    </article>
  );
}
