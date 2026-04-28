"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function DevLoginForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signIn() {
    setPending(true);
    setError(null);
    const response = await fetch("/api/auth/dev-login", { method: "POST" });
    setPending(false);

    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as { error?: string } | null;
      setError(body?.error ?? "Could not create a local dev session.");
      return;
    }

    router.push("/dashboard");
    router.refresh();
  }

  return (
    <div className="form-stack">
      <button className="button" type="button" onClick={signIn} disabled={pending}>
        {pending ? "Signing in..." : "Sign in as demo admin"}
      </button>
      {error ? <p className="error">{error}</p> : null}
    </div>
  );
}
