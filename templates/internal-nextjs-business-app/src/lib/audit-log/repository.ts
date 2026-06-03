import type { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db/prisma";
import { usesLocalDatabase } from "@/lib/project-config";

export async function recordAuditLog(params: {
  actorId: string;
  action: string;
  target: string;
  metadata?: Prisma.InputJsonValue;
}): Promise<void> {
  if (!usesLocalDatabase()) return;

  await prisma.auditLog.create({
    data: {
      actorId: params.actorId,
      action: params.action,
      target: params.target,
      metadata: params.metadata,
    },
  });
}
