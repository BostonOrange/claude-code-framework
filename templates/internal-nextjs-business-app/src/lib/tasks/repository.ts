import { randomUUID } from "node:crypto";

import { prisma } from "@/lib/db/prisma";
import type { DashboardTask, TaskStatus } from "@/lib/domain/types";
import { projectIdentity, usesLocalDatabase } from "@/lib/project-config";

const createdAt = new Date("2026-01-01T00:00:00.000Z");
const localCreatedTasks: DashboardTask[] = [];

function initialMemoryTasks(): DashboardTask[] {
  const project = projectIdentity();
  return [
    {
      id: "local-task-brief",
      title: "Confirm the first workflow",
      summary: `Use the brief to turn this into one testable workflow: ${project.what}`,
      status: "todo",
      createdAt,
      updatedAt: createdAt,
      createdBy: { name: "Demo User", email: "local@example.com" },
    },
    {
      id: "local-task-demo-data",
      title: "Use safe demo data first",
      summary: `Data sensitivity is ${project.dataSensitivity}. Do not paste exports, secrets, or production credentials into the local prototype.`,
      status: "doing",
      createdAt,
      updatedAt: createdAt,
      createdBy: { name: "Demo User", email: "local@example.com" },
    },
    {
      id: "local-task-agent",
      title: "Ask Claude Code or Codex for the first change",
      summary: "Use the prompt on this page or run npm run start-here to copy the project-aware build prompt.",
      status: "todo",
      createdAt,
      updatedAt: createdAt,
      createdBy: { name: "Demo User", email: "local@example.com" },
    },
  ];
}

export async function listDashboardTasks(): Promise<DashboardTask[]> {
  if (!usesLocalDatabase()) return [...localCreatedTasks, ...initialMemoryTasks()];

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
  if (!usesLocalDatabase()) {
    const now = new Date();
    const task: DashboardTask = {
      id: randomUUID(),
      title: params.title,
      summary: params.summary,
      status: params.status,
      createdAt: now,
      updatedAt: now,
      createdBy: { name: "Local User", email: "local@example.com" },
    };
    localCreatedTasks.unshift(task);
    return task;
  }

  return prisma.task.create({
    data: params,
  });
}
