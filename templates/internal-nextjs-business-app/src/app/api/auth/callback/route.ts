import { NextRequest, NextResponse } from "next/server";

import { completeOidcLogin } from "@/lib/auth/oidc";
import { appUrl } from "@/lib/env";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  try {
    return await completeOidcLogin(request);
  } catch (error) {
    console.error("[auth] OIDC callback failed", error);
    return NextResponse.redirect(new URL("/login?error=sso-callback", appUrl()));
  }
}
