import { NextResponse } from "next/server";

import { beginOidcLogin } from "@/lib/auth/oidc";
import { authMode } from "@/lib/env";

export const runtime = "nodejs";

export async function GET() {
  if (authMode() === "dev") {
    return NextResponse.redirect(new URL("/login", process.env.APP_URL ?? "http://localhost:3000"));
  }

  try {
    return await beginOidcLogin();
  } catch (error) {
    console.error("[auth] OIDC login failed", error);
    return NextResponse.redirect(new URL("/login?error=sso", process.env.APP_URL ?? "http://localhost:3000"));
  }
}
