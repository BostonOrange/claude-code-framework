import { NextRequest, NextResponse } from "next/server";

import { requireApiUser } from "@/lib/auth/require-user";
import { jsonError } from "@/lib/http/json";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const user = await requireApiUser(request);
  if (!user) return jsonError("Unauthorized", 401);

  return NextResponse.json({
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    tenantId: user.tenantId,
  });
}
