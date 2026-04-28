import { prisma } from "@/lib/db/prisma";
import type { DashboardTask, TaskStatus } from "@/lib/domain/types";

export async function listDashboardTasks(): Promise<DashboardTask[]> {
  return prisma.task.findMany({
    orderBy: [{ status: "asc" }, { updatedAt: "desc" }],
    include: {
      createdBy: {
        select: { name: true, email: true },
      },
    },
  });
}

export async function createTask(params: {
  title: string;
  summary: string | null;
  status: TaskStatus;
  createdById: string;
}) {
  return prisma.task.create({
    data: params,
  });
}
