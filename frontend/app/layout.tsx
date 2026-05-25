import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "宠可灵 GEO 文案工作台",
  description: "宠可灵GEO文案生成系统 — AI驱动的宠物行业文案创作工具",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN">
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
