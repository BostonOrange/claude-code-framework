import { prisma } from "@/lib/db/prisma";
import { usesLocalDatabase } from "@/lib/project-config";

export async function isDatabaseHealthy(): Promise<boolean> {
  if (!usesLocalDatabase()) return true;

  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch (error) {
    console.error("[health] Database check failed", error);
    return false;
  }
}
