import type { AppUser } from "@/lib/domain/types";
import { requiredEnv } from "@/lib/env";

const SYSTEM_INSTRUCTIONS = [
  "You help turn business enablement ideas into concrete internal-tool implementation plans.",
  "Be concise, operational, and security-aware.",
  "Prefer small data models, clear permissions, auditability, and measurable next steps.",
].join(" ");

interface ResponsesApiResult {
  output_text?: string;
  output?: Array<{
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
}

function extractOutputText(result: ResponsesApiResult): string | null {
  if (typeof result.output_text === "string") return result.output_text;

  for (const item of result.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && content.text) return content.text;
    }
  }

  return null;
}

function mockAdvice(prompt: string, user: Pick<AppUser, "name" | "role">): string {
  return [
    `Draft for ${user.name} (${user.role}):`,
    "",
    "1. Identify the core object the business team operates on.",
    "2. Define the minimum fields, owner, lifecycle states, and access rules.",
    "3. Add one create/read/update workflow before reporting or automation.",
    "4. Store private files in blob storage and relational state in Postgres.",
    "5. Add an audit event for each state change before widening access.",
    "",
    `Input: ${prompt}`,
  ].join("\n");
}

export async function generateBusinessAdvice(prompt: string, user: Pick<AppUser, "name" | "role">): Promise<string> {
  if ((process.env.AI_PROVIDER ?? "mock") !== "openai") {
    return mockAdvice(prompt, user);
  }

  const apiKey = requiredEnv("OPENAI_API_KEY");
  const model = requiredEnv("OPENAI_MODEL");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      instructions: SYSTEM_INSTRUCTIONS,
      input: prompt,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`AI provider failed with ${response.status}: ${body.slice(0, 500)}`);
  }

  const result = (await response.json()) as ResponsesApiResult;
  return extractOutputText(result) ?? "The AI provider returned no text output.";
}
