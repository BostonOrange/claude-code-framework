import type { NextRequest } from "next/server";

interface Entry {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, Map<string, Entry>>();

export function clientIp(request: NextRequest): string {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    request.headers.get("x-real-ip") ??
    "127.0.0.1"
  );
}

export function isRateLimited(key: string, bucket = "default", max = 20, windowMs = 60_000): boolean {
  const now = Date.now();
  const entries = buckets.get(bucket) ?? new Map<string, Entry>();
  buckets.set(bucket, entries);

  const entry = entries.get(key);
  if (!entry || now >= entry.resetAt) {
    entries.set(key, { count: 1, resetAt: now + windowMs });
    if (entries.size % 100 === 0) {
      for (const [entryKey, value] of entries) {
        if (now >= value.resetAt) entries.delete(entryKey);
      }
    }
    return false;
  }

  if (entry.count >= max) return true;
  entry.count += 1;
  return false;
}
