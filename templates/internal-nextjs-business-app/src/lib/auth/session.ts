import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify, SignJWT } from "jose";

import { isProduction } from "@/lib/env";
import type { UserRole } from "@/lib/domain/types";

export const SESSION_COOKIE = "app_session";
const EXPIRY_SECONDS = 12 * 60 * 60;

export interface AppSession {
  userId: string;
  email: string;
  name: string;
  role: UserRole;
  tenantId: string;
}

function sessionSecret(): Uint8Array {
  const secret = process.env.SESSION_SECRET;
  if (!secret && isProduction()) {
    throw new Error("SESSION_SECRET is required in production");
  }
  return new TextEncoder().encode(secret ?? "local-dev-session-secret-change-me");
}

export async function signSession(payload: AppSession): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${EXPIRY_SECONDS}s`)
    .sign(sessionSecret());
}

export async function verifySession(token: string | undefined): Promise<AppSession | null> {
  if (!token) return null;

  try {
    const { payload } = await jwtVerify(token, sessionSecret());
    return {
      userId: String(payload.userId),
      email: String(payload.email),
      name: String(payload.name),
      role: payload.role as UserRole,
      tenantId: String(payload.tenantId),
    };
  } catch {
    return null;
  }
}

export async function setSessionCookie(response: NextResponse, session: AppSession): Promise<void> {
  const token = await signSession(session);
  response.cookies.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: isProduction(),
    sameSite: "lax",
    path: "/",
    maxAge: EXPIRY_SECONDS,
  });
}

export function clearSessionCookie(response: NextResponse): void {
  response.cookies.set(SESSION_COOKIE, "", {
    httpOnly: true,
    secure: isProduction(),
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
}

export async function getSessionFromRequest(request: NextRequest): Promise<AppSession | null> {
  return verifySession(request.cookies.get(SESSION_COOKIE)?.value);
}

export async function getSessionFromCookies(): Promise<AppSession | null> {
  const cookieStore = await cookies();
  return verifySession(cookieStore.get(SESSION_COOKIE)?.value);
}
