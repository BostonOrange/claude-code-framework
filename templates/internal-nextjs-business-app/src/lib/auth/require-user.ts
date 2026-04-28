import { redirect } from "next/navigation";

import { getSessionFromCookies, getSessionFromRequest } from "@/lib/auth/session";
import { findUserById } from "@/lib/users/repository";
import type { NextRequest } from "next/server";

export async function getCurrentUser() {
  const session = await getSessionFromCookies();
  if (!session) return null;

  return findUserById(session.userId);
}

export async function requireUser() {
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  return user;
}

export async function requireApiUser(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session) return null;

  return findUserById(session.userId);
}
