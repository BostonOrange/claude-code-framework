import Link from "next/link";

import { DevLoginForm } from "@/components/DevLoginForm";
import { authMode } from "@/lib/env";

export default function LoginPage() {
  const mode = authMode();

  return (
    <main className="login-wrap">
      <section className="login-panel">
        <h1>App Creator</h1>
        <p>Sign in to the internal tools workspace.</p>
        {mode === "dev" ? (
          <DevLoginForm />
        ) : (
          <Link className="button" href="/api/auth/login">
            Continue with SSO
          </Link>
        )}
      </section>
    </main>
  );
}
