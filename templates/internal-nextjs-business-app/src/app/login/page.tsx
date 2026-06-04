import Link from "next/link";

import { DevLoginForm } from "@/components/DevLoginForm";
import { authMode } from "@/lib/env";
import { projectIdentity } from "@/lib/project-config";

export default function LoginPage() {
  const mode = authMode();
  const project = projectIdentity();

  return (
    <main className="login-wrap">
      <section className="login-panel">
        <p className="eyebrow">Internal tools starter</p>
        <h1>{project.name}</h1>
        <p>{project.description}</p>
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
