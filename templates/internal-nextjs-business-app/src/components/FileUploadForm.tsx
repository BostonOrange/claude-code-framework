"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function FileUploadForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function upload(formData: FormData) {
    setPending(true);
    setError(null);
    const response = await fetch("/api/files", {
      method: "POST",
      body: formData,
    });
    setPending(false);

    const body = (await response.json().catch(() => null)) as { error?: string } | null;
    if (!response.ok) {
      setError(body?.error ?? "Could not upload file.");
      return;
    }

    router.refresh();
  }

  return (
    <form action={upload} className="form-stack">
      <div className="field">
        <label htmlFor="file">Private file</label>
        <input id="file" name="file" type="file" />
      </div>
      <button className="button secondary" type="submit" disabled={pending}>
        {pending ? "Uploading..." : "Upload to blob"}
      </button>
      {error ? <p className="error">{error}</p> : null}
    </form>
  );
}
