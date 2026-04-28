import type { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db/prisma";

export async function recordAuditLog(params: {
  actorId: string;
  action: string;
  target: string;
  metadata?: Prisma.InputJsonValue;
}): Promise<void> {
  await prisma.auditLog.create({
    data: {
      actorId: params.actorId,
      action: params.action,
      target: params.target,
      metadata: params.metadata,
    },
  });
}
