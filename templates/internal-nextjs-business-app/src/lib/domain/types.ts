export const USER_ROLES = ["owner", "admin", "member", "viewer"] as const;
export type UserRole = (typeof USER_ROLES)[number];

export const TASK_STATUSES = ["todo", "doing", "done"] as const;
export type TaskStatus = (typeof TASK_STATUSES)[number];

export interface AppUser {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  tenantId: string;
  createdAt: Date;
  updatedAt: Date;
  lastLoginAt: Date | null;
}

export interface DashboardTask {
  id: string;
  title: string;
  summary: string | null;
  status: TaskStatus;
  createdAt: Date;
  updatedAt: Date;
  createdBy: {
    name: string;
    email: string;
  };
}

export interface FileObjectRecord {
  id: string;
  blobName: string;
  filename: string;
  contentType: string;
  size: number;
  uploadedAt: Date;
  uploadedById: string;
}
