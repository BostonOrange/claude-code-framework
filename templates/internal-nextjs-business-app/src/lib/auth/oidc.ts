import { createHash, randomBytes } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { createRemoteJWKSet, jwtVerify } from "jose";

import { appUrl, requiredEnv } from "@/lib/env";
import { setSessionCookie } from "@/lib/auth/session";
import { upsertOidcUser } from "@/lib/users/repository";

const STATE_COOKIE = "oidc_state";
const VERIFIER_COOKIE = "oidc_verifier";
const NONCE_COOKIE = "oidc_nonce";
const TEMP_COOKIE_MAX_AGE = 10 * 60;

interface OidcDiscovery {
  issuer: string;
  authorization_endpoint: string;
  token_endpoint: string;
  jwks_uri: string;
}

function base64url(buffer: Buffer): string {
  return buffer.toString("base64url");
}

function randomToken(): string {
  return base64url(randomBytes(32));
}

function codeChallenge(verifier: string): string {
  return createHash("sha256").update(verifier).digest("base64url");
}

function callbackUrl(): string {
  return new URL("/api/auth/callback", appUrl()).toString();
}

async function discovery(): Promise<OidcDiscovery> {
  const issuer = requiredEnv("OIDC_ISSUER").replace(/\/$/, "");
  const response = await fetch(`${issuer}/.well-known/openid-configuration`, {
    cache: "force-cache",
  });

  if (!response.ok) {
    throw new Error(`OIDC discovery failed with ${response.status}`);
  }

  return response.json() as Promise<OidcDiscovery>;
}

function setTempCookie(response: NextResponse, name: string, value: string) {
  response.cookies.set(name, value, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: TEMP_COOKIE_MAX_AGE,
  });
}

function clearTempCookies(response: NextResponse) {
  for (const name of [STATE_COOKIE, VERIFIER_COOKIE, NONCE_COOKIE]) {
    response.cookies.set(name, "", {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 0,
    });
  }
}

export async function beginOidcLogin(): Promise<NextResponse> {
  const config = await discovery();
  const state = randomToken();
  const verifier = randomToken();
  const nonce = randomToken();

  const authorizeUrl = new URL(config.authorization_endpoint);
  authorizeUrl.searchParams.set("client_id", requiredEnv("OIDC_CLIENT_ID"));
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("redirect_uri", callbackUrl());
  authorizeUrl.searchParams.set("scope", "openid profile email");
  authorizeUrl.searchParams.set("state", state);
  authorizeUrl.searchParams.set("nonce", nonce);
  authorizeUrl.searchParams.set("code_challenge", codeChallenge(verifier));
  authorizeUrl.searchParams.set("code_challenge_method", "S256");

  const response = NextResponse.redirect(authorizeUrl);
  setTempCookie(response, STATE_COOKIE, state);
  setTempCookie(response, VERIFIER_COOKIE, verifier);
  setTempCookie(response, NONCE_COOKIE, nonce);
  return response;
}

function assertAllowedEmail(email: string) {
  const allowed = process.env.OIDC_ALLOWED_EMAIL_DOMAINS?.split(",")
    .map((domain) => domain.trim().toLowerCase())
    .filter(Boolean);

  if (!allowed?.length) return;

  const domain = email.split("@")[1]?.toLowerCase();
  if (!domain || !allowed.includes(domain)) {
    throw new Error("Email domain is not allowed for this app");
  }
}

export async function completeOidcLogin(request: NextRequest): Promise<NextResponse> {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const state = requestUrl.searchParams.get("state");
  const storedState = request.cookies.get(STATE_COOKIE)?.value;
  const verifier = request.cookies.get(VERIFIER_COOKIE)?.value;
  const nonce = request.cookies.get(NONCE_COOKIE)?.value;

  if (!code || !state || !storedState || state !== storedState || !verifier || !nonce) {
    throw new Error("Invalid OIDC callback state");
  }

  const config = await discovery();
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: callbackUrl(),
    client_id: requiredEnv("OIDC_CLIENT_ID"),
    client_secret: requiredEnv("OIDC_CLIENT_SECRET"),
    code_verifier: verifier,
  });

  const tokenResponse = await fetch(config.token_endpoint, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!tokenResponse.ok) {
    throw new Error(`OIDC token exchange failed with ${tokenResponse.status}`);
  }

  const tokens = (await tokenResponse.json()) as { id_token?: string };
  if (!tokens.id_token) throw new Error("OIDC provider did not return an id_token");

  const jwks = createRemoteJWKSet(new URL(config.jwks_uri));
  const { payload } = await jwtVerify(tokens.id_token, jwks, {
    issuer: config.issuer,
    audience: requiredEnv("OIDC_CLIENT_ID"),
  });

  if (payload.nonce !== nonce) throw new Error("OIDC nonce mismatch");

  const email = String(payload.email ?? payload.preferred_username ?? payload.upn ?? "");
  if (!email.includes("@")) throw new Error("OIDC profile did not include an email address");
  assertAllowedEmail(email);

  const name = String(payload.name ?? email);
  const user = await upsertOidcUser({ email, name });

  const response = NextResponse.redirect(new URL("/dashboard", appUrl()));
  clearTempCookies(response);
  await setSessionCookie(response, {
    userId: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    tenantId: user.tenantId,
  });
  return response;
}
