import { NextResponse } from "next/server";

import { isDatabaseHealthy } from "@/lib/db/health";

export const runtime = "nodejs";

export async function GET() {
  const db: "ok" | "error" = (await isDatabaseHealthy()) ? "ok" : "error";

  const blob = process.env.AZURE_STORAGE_CONNECTION_STRING ? "configured" : "not_configured";
  const status = db === "ok" ? "ok" : "degraded";

  return NextResponse.json(
    {
      status,
      db,
      blob,
      authMode: process.env.AUTH_MODE ?? "dev",
      aiProvider: process.env.AI_PROVIDER ?? "mock",
      timestamp: new Date().toISOString(),
    },
    { status: status === "ok" ? 200 : 503 },
  );
}
