import { NextResponse } from "next/server";

import { clearSessionCookie } from "@/lib/auth/session";
import { appUrl } from "@/lib/env";

export const runtime = "nodejs";

function logout() {
  const response = NextResponse.redirect(new URL("/login", appUrl()));
  clearSessionCookie(response);
  return response;
}

export function GET() {
  return logout();
}

export function POST() {
  return logout();
}
