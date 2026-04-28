import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

import { generateBusinessAdvice } from "@/lib/ai/provider";
import { requireApiUser } from "@/lib/auth/require-user";
import { jsonError } from "@/lib/http/json";
import { clientIp, isRateLimited } from "@/lib/http/rate-limit";

export const runtime = "nodejs";

const chatInput = z.object({
  prompt: z.string().trim().min(10).max(4000),
});

export async function POST(request: NextRequest) {
  const user = await requireApiUser(request);
  if (!user) return jsonError("Unauthorized", 401);

  if (isRateLimited(`${user.id}:${clientIp(request)}`, "ai", 10, 60_000)) {
    return jsonError("Too many AI requests.", 429);
  }

  const parsed = chatInput.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonError("Invalid AI prompt.", 400);

  try {
    const advice = await generateBusinessAdvice(parsed.data.prompt, user);
    return NextResponse.json({ advice });
  } catch (error) {
    console.error("[ai] generation failed", error);
    return jsonError("AI provider failed.", 502);
  }
}
