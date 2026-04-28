import { NextResponse } from "next/server";

import { authMode } from "@/lib/env";
import { setSessionCookie } from "@/lib/auth/session";
import { jsonError } from "@/lib/http/json";
import { upsertDevAdmin } from "@/lib/users/repository";

export const runtime = "nodejs";

export async function POST() {
  if (authMode() !== "dev") {
    return jsonError("Dev login is disabled when AUTH_MODE is not dev.", 403);
  }

  const user = await upsertDevAdmin();

  const response = NextResponse.json({ ok: true });
  await setSessionCookie(response, {
    userId: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    tenantId: user.tenantId,
  });
  return response;
}
