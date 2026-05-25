import { NextResponse } from "next/server";

export async function POST(request: Request) {
  try {
    const { password } = await request.json();

    if (!password || password !== process.env.AUTH_PASSWORD) {
      return NextResponse.json(
        { error: "密码错误" },
        { status: 401 },
      );
    }

    const response = NextResponse.json({ success: true });
    response.cookies.set("auth_token", process.env.AUTH_TOKEN!, {
      httpOnly: true,
      secure: true,
      sameSite: "lax",
      maxAge: 60 * 60 * 24, // 24 hours
      path: "/",
    });

    return response;
  } catch {
    return NextResponse.json(
      { error: "请求格式错误" },
      { status: 400 },
    );
  }
}
