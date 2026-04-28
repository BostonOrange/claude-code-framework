import { prisma } from "@/lib/db/prisma";

export async function isDatabaseHealthy(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch (error) {
    console.error("[health] Database check failed", error);
    return false;
  }
}
