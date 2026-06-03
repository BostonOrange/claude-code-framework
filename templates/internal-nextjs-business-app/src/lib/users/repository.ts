import type { User } from "@/generated/prisma/client";
import { prisma } from "@/lib/db/prisma";
import type { AppUser } from "@/lib/domain/types";
import { usesLocalDatabase } from "@/lib/project-config";

function localUser(params?: { email?: string; name?: string }): AppUser {
  const now = new Date();
  return {
    id: params?.email ? `local-${params.email.replace(/[^a-zA-Z0-9._-]/g, "_")}` : "local-dev-admin",
    email: params?.email ?? "admin@example.com",
    name: params?.name ?? "Demo Admin",
    role: "owner",
    tenantId: "local",
    createdAt: now,
    updatedAt: now,
    lastLoginAt: now,
  };
}

function toAppUser(user: User): AppUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    tenantId: user.tenantId,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
    lastLoginAt: user.lastLoginAt,
  };
}

export async function countUsers(): Promise<number> {
  if (!usesLocalDatabase()) return 1;
  return prisma.user.count();
}

export async function findUserById(id: string): Promise<AppUser | null> {
  if (!usesLocalDatabase()) {
    if (id === "local-dev-admin") return localUser();
    return id.startsWith("local-") ? localUser({ email: id.replace(/^local-/, "") }) : localUser();
  }

  const user = await prisma.user.findUnique({ where: { id } });
  return user ? toAppUser(user) : null;
}

export async function upsertDevAdmin(): Promise<AppUser> {
  if (!usesLocalDatabase()) return localUser();

  const user = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {
      name: "Demo Admin",
      role: "owner",
      lastLoginAt: new Date(),
    },
    create: {
      email: "admin@example.com",
      name: "Demo Admin",
      role: "owner",
      tenantId: "default",
      lastLoginAt: new Date(),
    },
  });

  return toAppUser(user);
}

export async function upsertOidcUser(params: { email: string; name: string }): Promise<AppUser> {
  if (!usesLocalDatabase()) return localUser(params);

  const existingUsers = await countUsers();
  const user = await prisma.user.upsert({
    where: { email: params.email },
    update: {
      name: params.name,
      lastLoginAt: new Date(),
    },
    create: {
      email: params.email,
      name: params.name,
      role: existingUsers === 0 ? "owner" : "member",
      tenantId: "default",
      lastLoginAt: new Date(),
    },
  });

  return toAppUser(user);
}
