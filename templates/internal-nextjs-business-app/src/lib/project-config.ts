import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export const LOCAL_PERSISTENCE_KINDS = [
  "memory",
  "folder",
  "sqlite",
  "local-postgres",
  "full-stack",
  "review-required",
] as const;

export type LocalPersistenceKind = (typeof LOCAL_PERSISTENCE_KINDS)[number];

const defaultPersistenceKind: LocalPersistenceKind = "full-stack";

export interface ProjectIdentity {
  name: string;
  description: string;
  who: string;
  what: string;
  why: string;
  ownerDisplay: string;
  ownerEmail: string;
  division: string;
  layer: string;
  expectedUsers: string;
  dataSensitivity: string;
  localPersistenceKind: LocalPersistenceKind;
  localPersistence: string;
}

export interface ProjectCanvas {
  appType: string;
  localBasePlan: string[];
  mockDataPlan: string[];
  firstScreenPlan: string[];
  designRequirements: string[];
  infrastructure: string[];
  sharedInfrastructure: string[];
}

function normalizePersistenceKind(value: unknown): LocalPersistenceKind | null {
  if (typeof value !== "string") return null;
  return LOCAL_PERSISTENCE_KINDS.includes(value as LocalPersistenceKind) ? (value as LocalPersistenceKind) : null;
}

function readBlueprintPersistenceKind(): LocalPersistenceKind | null {
  const path = join(process.cwd(), "PROJECT_BLUEPRINT.json");
  if (!existsSync(path)) return null;

  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as { localPersistenceKind?: unknown };
    return normalizePersistenceKind(parsed.localPersistenceKind);
  } catch {
    return null;
  }
}

function readJsonFile<T>(path: string): T | null {
  if (!existsSync(path)) return null;

  try {
    return JSON.parse(readFileSync(path, "utf8")) as T;
  } catch {
    return null;
  }
}

function stringValue(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stringList(value: unknown, fallback: string[]): string[] {
  if (!Array.isArray(value)) return fallback;

  const items = value.map((item) => String(item).trim()).filter(Boolean);
  return items.length > 0 ? items : fallback;
}

export function projectIdentity(): ProjectIdentity {
  const manifest = readJsonFile<{
    project?: {
      name?: unknown;
      description?: unknown;
      who?: unknown;
      what?: unknown;
      why?: unknown;
      expectedUsers?: unknown;
      dataSensitivity?: unknown;
      layer?: unknown;
      blueprint?: {
        localPersistenceKind?: unknown;
        localPersistence?: unknown;
        firstAgentPrompt?: unknown;
      };
    };
    owner?: {
      displayName?: unknown;
      email?: unknown;
      division?: unknown;
    };
  }>(join(process.cwd(), ".claude", "project-manifest.json"));

  const blueprint = readJsonFile<{
    localPersistenceKind?: unknown;
    localPersistence?: unknown;
  }>(join(process.cwd(), "PROJECT_BLUEPRINT.json"));

  const manifestBlueprint = manifest?.project?.blueprint;
  const localKind =
    normalizePersistenceKind(manifestBlueprint?.localPersistenceKind) ??
    normalizePersistenceKind(blueprint?.localPersistenceKind) ??
    localPersistenceKind();

  return {
    name: stringValue(manifest?.project?.name, "Internal Tool Starter"),
    description: stringValue(
      manifest?.project?.description,
      "A local starter app for internal tools.",
    ),
    who: stringValue(manifest?.project?.who, "The project owner and invited internal users."),
    what: stringValue(manifest?.project?.what, "Build the first useful internal workflow."),
    why: stringValue(manifest?.project?.why, "Make repeated work easier to see and manage."),
    ownerDisplay: stringValue(manifest?.owner?.displayName, "Project owner"),
    ownerEmail: stringValue(manifest?.owner?.email, "owner@example.com"),
    division: stringValue(manifest?.owner?.division, "Team"),
    layer: stringValue(manifest?.project?.layer, "1"),
    expectedUsers: stringValue(manifest?.project?.expectedUsers, "Just me"),
    dataSensitivity: stringValue(manifest?.project?.dataSensitivity, "internal"),
    localPersistenceKind: localKind,
    localPersistence: stringValue(
      manifestBlueprint?.localPersistence ?? blueprint?.localPersistence,
      localKind === "memory" ? "In-memory state only" : "Configured by the project blueprint",
    ),
  };
}

export function projectCanvas(): ProjectCanvas {
  const blueprint = readJsonFile<{
    appType?: unknown;
    localBasePlan?: unknown;
    mockDataPlan?: unknown;
    firstScreenPlan?: unknown;
    designRequirements?: unknown;
    infrastructure?: unknown;
    sharedInfrastructure?: unknown;
  }>(join(process.cwd(), "PROJECT_BLUEPRINT.json"));
  const project = projectIdentity();

  return {
    appType: stringValue(blueprint?.appType, "Internal work tool"),
    localBasePlan: stringList(blueprint?.localBasePlan, [
      "Run entirely on this laptop using localhost.",
      `Use the configured local persistence mode: ${project.localPersistenceKind}.`,
      "Use safe mock data before connecting real business systems.",
    ]),
    mockDataPlan: stringList(blueprint?.mockDataPlan, [
      "Create realistic demo records for the first workflow.",
      "Include enough records to test filters, empty states, and summary metrics.",
    ]),
    firstScreenPlan: stringList(blueprint?.firstScreenPlan, [
      `Show ${project.name} with the main workflow in plain business language.`,
      "Add summary metrics, a working list or table, and one useful filter.",
    ]),
    designRequirements: stringList(blueprint?.designRequirements, [
      "Follow docs/design-system.md.",
      "Use the project brand color, Inter/system typography, semantic color tokens, and business-first wording.",
    ]),
    infrastructure: stringList(blueprint?.infrastructure, ["Local laptop", "Localhost app"]),
    sharedInfrastructure: stringList(blueprint?.sharedInfrastructure, []),
  };
}

export function firstAgentPrompt(project = projectIdentity()): string {
  const manifest = readJsonFile<{
    project?: {
      blueprint?: {
        firstAgentPrompt?: unknown;
      };
    };
  }>(join(process.cwd(), ".claude", "project-manifest.json"));
  const blueprint = readJsonFile<{ firstAgentPrompt?: unknown }>(join(process.cwd(), "PROJECT_BLUEPRINT.json"));
  const configuredPrompt = stringValue(
    manifest?.project?.blueprint?.firstAgentPrompt ?? blueprint?.firstAgentPrompt,
    "",
  );
  if (configuredPrompt) return configuredPrompt;

  return [
    "Read PROJECT_BRIEF.md, PROJECT_BLUEPRINT.json, LOCAL_BASELINE.md, SETUP_MODE.md, LAYER.md, AGENTS.md, NEXT_STEPS.md, and docs/design-system.md.",
    `Then help me build the first useful version of ${project.name}.`,
    `Keep it Layer ${project.layer} and use the configured local persistence mode: ${project.localPersistenceKind}.`,
    "Use mock data first and follow the design system.",
    "Start by proposing the smallest workflow I can test today, then make the first code change.",
  ].join(" ");
}

export function localPersistenceKind(): LocalPersistenceKind {
  return (
    normalizePersistenceKind(process.env.APP_LOCAL_PERSISTENCE) ??
    readBlueprintPersistenceKind() ??
    defaultPersistenceKind
  );
}

export function usesLocalDatabase(): boolean {
  const kind = localPersistenceKind();
  return kind === "local-postgres" || kind === "full-stack";
}

export function usesBlobStorage(): boolean {
  return localPersistenceKind() === "full-stack";
}
