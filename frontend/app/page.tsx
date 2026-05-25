"use client";

import { useRef, useState, useCallback } from "react";
import ControlPanel from "@/app/components/ControlPanel";
import CopyCard from "@/app/components/CopyCard";
import EmptyState from "@/app/components/EmptyState";
import type { CopyData } from "@/app/components/CopyCard";

/* ── Types ────────────────────────────────────────────────────────────── */

interface SseStartEvent {
  event: "start";
  total: number;
  request_id: string;
}

interface SseCopyEvent {
  event: "copy";
  index: number;
  total: number;
  angle: string;
  angle_description: string;
  content: string;
  status: "success" | "error";
  error?: string;
  request_id: string;
}

interface SseDoneEvent {
  event: "done";
  total: number;
  success_count: number;
  request_id: string;
}

interface SseErrorEvent {
  event: "error";
  error: string;
}

type SseEvent = SseStartEvent | SseCopyEvent | SseDoneEvent | SseErrorEvent;

const TOTAL_COPIES = 10;

/* ────────────────────────────────────────────────────────────────────── */

export default function HomePage() {
  /* ---- Form state ---- */
  const [productId, setProductId] = useState("");
  const [copyType, setCopyType] = useState("小红书种草");
  const [tone, setTone] = useState("专业");
  const [useEmojis, setUseEmojis] = useState(false);

  /* ---- Result state ---- */
  const [results, setResults] = useState<(CopyData | null)[]>(
    Array(TOTAL_COPIES).fill(null),
  );
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const abortRef = useRef<AbortController | null>(null);

  /* ---- Generate ---- */
  const handleGenerate = useCallback(async () => {
    // Cleanup previous request
    abortRef.current?.abort();
    abortRef.current = new AbortController();
    const { signal } = abortRef.current;

    setIsLoading(true);
    setError(null);
    setResults(Array(TOTAL_COPIES).fill(null));

    try {
      const res = await fetch("/api/v1/generate_copy", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          product_id: productId,
          copy_type: copyType,
          tone,
          use_emojis: useEmojis,
        }),
        signal,
      });

      if (!res.ok) {
        const text = await res.text().catch(() => "");
        throw new Error(`请求失败 (${res.status}): ${text || res.statusText}`);
      }

      const reader = res.body?.getReader();
      if (!reader) throw new Error("响应体为空");

      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? ""; // keep incomplete trailing fragment

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith("data: ")) continue;

          try {
            const data: SseEvent = JSON.parse(trimmed.slice(6));

            if (data.event === "start") {
              // Optionally store request_id
            } else if (data.event === "copy") {
              setResults((prev) => {
                const next = [...prev];
                // index is 0-based from backend
                if (data.index >= 0 && data.index < TOTAL_COPIES) {
                  next[data.index] = {
                    index: data.index,
                    angle: data.angle,
                    angle_description: data.angle_description,
                    content: data.content,
                    status: data.status,
                    error: data.error,
                  };
                }
                return next;
              });
            } else if (data.event === "done") {
              // All done — stop loading
              setIsLoading(false);
            } else if (data.event === "error") {
              setError(data.error);
              setIsLoading(false);
            }
          } catch {
            // Malformed JSON on this line — skip
          }
        }
      }
    } catch (err: unknown) {
      if (err instanceof DOMException && err.name === "AbortError") {
        return; // intentional abort, ignore
      }
      setError(err instanceof Error ? err.message : "未知错误");
    } finally {
      setIsLoading(false);
    }
  }, [productId, copyType, tone, useEmojis]);

  /* ---- Loading cards: fill null slots with skeleton ---- */
  const displayResults = results.slice(0, TOTAL_COPIES);
  const hasResults = displayResults.some((r) => r !== null);

  return (
    <main className="flex h-screen overflow-hidden">
      {/* ===== Left Panel ===== */}
      <ControlPanel
        productId={productId}
        onChangeProduct={setProductId}
        copyType={copyType}
        onChangeCopyType={setCopyType}
        tone={tone}
        onChangeTone={setTone}
        useEmojis={useEmojis}
        onChangeEmojis={setUseEmojis}
        onGenerate={handleGenerate}
        loading={isLoading}
      />

      {/* ===== Right Panel ===== */}
      <section className="flex-1 flex flex-col h-screen overflow-hidden">
        {/* Header bar */}
        <div className="flex items-center justify-between px-6 py-3 border-b border-slate-200 bg-white shrink-0">
          <h2 className="text-sm font-semibold text-slate-600">
            {isLoading
              ? "正在生成…"
              : hasResults
                ? `生成结果 (${results.filter((r) => r?.status === "success").length}/${TOTAL_COPIES})`
                : "准备就绪"}
          </h2>
          {error && (
            <span className="text-xs text-red-500 bg-red-50 px-2.5 py-1 rounded-md">
              {error}
            </span>
          )}
        </div>

        {/* Cards grid */}
        <div className="flex-1 overflow-y-auto px-6 py-6">
          {!hasResults && !isLoading ? (
            <EmptyState />
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 auto-rows-max">
              {displayResults.map((item, i) =>
                item ? (
                  <CopyCard key={i} data={item} />
                ) : (
                  <LoadingSkeleton key={i} index={i} />
                ),
              )}
            </div>
          )}
        </div>
      </section>
    </main>
  );
}

/* ── Loading Skeleton ─────────────────────────────────────────────────── */

function LoadingSkeleton({ index }: { index: number }) {
  return (
    <div
      className="flex flex-col rounded-xl border border-slate-200 bg-white shadow-sm animate-fade-in"
      style={{ animationDelay: `${index * 80}ms` }}
    >
      <div className="border-b border-slate-100 px-4 py-3.5">
        <div className="flex items-center gap-2">
          <div className="h-5 w-12 rounded-md bg-slate-100 animate-pulse" />
          <div className="h-4 w-24 rounded bg-slate-100 animate-pulse" />
        </div>
        <div className="mt-1.5 h-3 w-48 rounded bg-slate-100 animate-pulse" />
      </div>
      <div className="px-4 py-3.5 space-y-2">
        <div className="h-3 w-full rounded bg-slate-100 animate-pulse" />
        <div className="h-3 w-5/6 rounded bg-slate-100 animate-pulse" />
        <div className="h-3 w-4/6 rounded bg-slate-100 animate-pulse" />
        <div className="h-3 w-full rounded bg-slate-100 animate-pulse" />
        <div className="h-3 w-3/4 rounded bg-slate-100 animate-pulse" />
      </div>
    </div>
  );
}
