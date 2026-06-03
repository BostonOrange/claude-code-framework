import { NextResponse } from "next/server";

import { isDatabaseHealthy } from "@/lib/db/health";
import { usesBlobStorage, usesLocalDatabase } from "@/lib/project-config";

export const runtime = "nodejs";

export async function GET() {
  const db: "ok" | "error" | "not_required" = usesLocalDatabase()
    ? (await isDatabaseHealthy()) ? "ok" : "error"
    : "not_required";

  const blob = usesBlobStorage()
    ? process.env.AZURE_STORAGE_CONNECTION_STRING ? "configured" : "not_configured"
    : "not_required";
  const status = db === "error" ? "degraded" : "ok";

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
