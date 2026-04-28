import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

import { requireApiUser } from "@/lib/auth/require-user";
import { recordAuditLog } from "@/lib/audit-log/repository";
import { TASK_STATUSES } from "@/lib/domain/types";
import { jsonError } from "@/lib/http/json";
import { clientIp, isRateLimited } from "@/lib/http/rate-limit";
import { createTask, listDashboardTasks } from "@/lib/tasks/repository";

export const runtime = "nodejs";

const taskInput = z.object({
  title: z.string().trim().min(3).max(160),
  summary: z.string().trim().max(4000).optional().nullable(),
  status: z.enum(TASK_STATUSES).default("todo"),
});

export async function GET(request: NextRequest) {
  const user = await requireApiUser(request);
  if (!user) return jsonError("Unauthorized", 401);
  return NextResponse.json({ tasks: await listDashboardTasks() });
}

export async function POST(request: NextRequest) {
  const user = await requireApiUser(request);
  if (!user) return jsonError("Unauthorized", 401);

  if (isRateLimited(`${user.id}:${clientIp(request)}`, "tasks", 30)) {
    return jsonError("Too many task requests.", 429);
  }

  const parsed = taskInput.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonError("Invalid task payload.", 400);

  const task = await createTask({
    title: parsed.data.title,
    summary: parsed.data.summary || null,
    status: parsed.data.status,
    createdById: user.id,
  });

  await recordAuditLog({
    actorId: user.id,
    action: "task.create",
    target: task.id,
    metadata: { title: task.title },
  });

  return NextResponse.json({ task }, { status: 201 });
}
