"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function TaskComposer() {
  const router = useRouter();
  const [prompt, setPrompt] = useState("Build a small internal tool for tracking customer onboarding risks.");
  const [title, setTitle] = useState("");
  const [advice, setAdvice] = useState<string | null>(null);
  const [pendingAi, setPendingAi] = useState(false);
  const [pendingCreate, setPendingCreate] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function generateAdvice() {
    setPendingAi(true);
    setError(null);
    const response = await fetch("/api/ai/chat", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ prompt }),
    });
    setPendingAi(false);

    const body = (await response.json().catch(() => null)) as { advice?: string; error?: string } | null;
    if (!response.ok) {
      setError(body?.error ?? "Could not generate advice.");
      return;
    }
    setAdvice(body?.advice ?? "");
    if (!title) setTitle(prompt.slice(0, 80));
  }

  async function createTask() {
    setPendingCreate(true);
    setError(null);
    const response = await fetch("/api/tasks", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        title,
        summary: advice ?? prompt,
        status: "todo",
      }),
    });
    setPendingCreate(false);

    const body = (await response.json().catch(() => null)) as { error?: string } | null;
    if (!response.ok) {
      setError(body?.error ?? "Could not create task.");
      return;
    }
    setTitle("");
    router.refresh();
  }

  return (
    <div className="form-stack">
      <div className="field">
        <label htmlFor="ai-prompt">Business problem</label>
        <textarea id="ai-prompt" value={prompt} onChange={(event) => setPrompt(event.target.value)} />
      </div>
      <div className="button-row">
        <button className="button" type="button" onClick={generateAdvice} disabled={pendingAi || prompt.length < 10}>
          {pendingAi ? "Generating..." : "Generate plan"}
        </button>
      </div>
      {advice ? <div className="advice">{advice}</div> : null}
      <div className="field">
        <label htmlFor="task-title">Task title</label>
        <input id="task-title" value={title} onChange={(event) => setTitle(event.target.value)} />
      </div>
      <button className="button secondary" type="button" onClick={createTask} disabled={pendingCreate || title.length < 3}>
        {pendingCreate ? "Creating..." : "Create task"}
      </button>
      {error ? <p className="error">{error}</p> : null}
    </div>
  );
}
