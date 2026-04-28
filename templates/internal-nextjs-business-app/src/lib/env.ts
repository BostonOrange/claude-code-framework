export function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export function appUrl(): string {
  return process.env.APP_URL ?? "http://localhost:3000";
}

export function authMode(): "dev" | "oidc" {
  return process.env.AUTH_MODE === "oidc" ? "oidc" : "dev";
}

export function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}
