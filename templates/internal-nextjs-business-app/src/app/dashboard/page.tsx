import { FileUploadForm } from "@/components/FileUploadForm";
import { LogoutButton } from "@/components/LogoutButton";
import { requireUser } from "@/lib/auth/require-user";
import { listRecentFiles } from "@/lib/files/repository";
import { firstAgentPrompt, projectCanvas, projectIdentity, usesBlobStorage } from "@/lib/project-config";
import { listDashboardTasks } from "@/lib/tasks/repository";

function PlanList({ title, items }: { title: string; items: string[] }) {
  return (
    <section className="canvas-panel">
      <h3>{title}</h3>
      <ul className="check-list">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  );
}

export default async function DashboardPage() {
  const user = await requireUser();
  const project = projectIdentity();
  const canvas = projectCanvas();
  const prompt = firstAgentPrompt(project);
  const blobEnabled = usesBlobStorage();
  const [tasks, files] = await Promise.all([
    listDashboardTasks(),
    blobEnabled ? listRecentFiles(8) : Promise.resolve([]),
  ]);

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand">
          <strong>{project.name}</strong>
          <span>Internal tools starter</span>
        </div>
        <div className="topbar-actions">
          <span className="pill">Layer {project.layer}</span>
          <span className="pill">{user.role}</span>
          <LogoutButton />
        </div>
      </header>

      <main className="page">
        <div className="page-header">
          <div>
            <p className="eyebrow">{canvas.appType}</p>
            <h1>{project.name}</h1>
            <p>{project.description}</p>
          </div>
          <span className="pill">{project.localPersistenceKind}</span>
        </div>

        <section className="hero-canvas" aria-label="Project canvas">
          <div>
            <p className="eyebrow">Starter canvas</p>
            <h2>Build the first useful version locally</h2>
            <p>
              This app has been prepared from the setup conversation. It starts with safe local data, the
              selected persistence mode, and a first-screen plan that Claude Code or Codex can build from.
            </p>
          </div>
          <div className="metric-strip">
            <div>
              <span>Layer</span>
              <strong>{project.layer}</strong>
            </div>
            <div>
              <span>Users</span>
              <strong>{project.expectedUsers}</strong>
            </div>
            <div>
              <span>Data</span>
              <strong>{project.dataSensitivity}</strong>
            </div>
          </div>
        </section>

        <section className="section brief-section">
          <div className="section-header">
            <div>
              <h2>What this should become</h2>
              <p>
                Signed in as {user.name} ({user.email}). Keep the first version small and testable on localhost.
              </p>
            </div>
          </div>
          <dl className="brief-grid">
            <div>
              <dt>Who</dt>
              <dd>{project.who}</dd>
            </div>
            <div>
              <dt>What</dt>
              <dd>{project.what}</dd>
            </div>
            <div>
              <dt>Why</dt>
              <dd>{project.why}</dd>
            </div>
          </dl>
        </section>

        <div className="canvas-grid" aria-label="Setup plan">
          <PlanList title="First screen" items={canvas.firstScreenPlan} />
          <PlanList title="Mock data" items={canvas.mockDataPlan} />
          <PlanList title="Local base" items={canvas.localBasePlan} />
          <PlanList title="Design rules" items={canvas.designRequirements} />
        </div>

        <div className="grid">
          <section className="section">
            <div className="section-header">
              <div>
                <h2>First build checklist</h2>
                <p>These are starter tasks for turning the folder into the first useful version.</p>
              </div>
              <span className="pill">{tasks.length} tasks</span>
            </div>
            <div className="task-list">
              {tasks.map((task) => (
                <article className="task-card" key={task.id}>
                  <div className="task-meta">
                    <span className={`pill ${task.status}`}>{task.status}</span>
                    <span className="muted">{task.createdBy.name}</span>
                  </div>
                  <h3>{task.title}</h3>
                  {task.summary ? <p>{task.summary}</p> : null}
                </article>
              ))}
            </div>
          </section>

          <aside>
            <section className="section">
              <div className="section-header">
                <div>
                  <h2>Use your local coding agent</h2>
                  <p>Open Claude Code or Codex CLI in this folder. The project files already contain this prompt.</p>
                </div>
              </div>
              <pre className="prompt-box">{prompt}</pre>
              <p className="muted">You can print this again any time with npm run start-here.</p>
            </section>

            <section className="section">
              <div className="section-header">
                <div>
                  <h2>Local setup</h2>
                  <p>
                    {project.localPersistenceKind}: {project.localPersistence}
                  </p>
                </div>
              </div>
              {blobEnabled ? (
                <>
                  <p className="muted">Private uploads are backed by Azurite locally or Azure Blob in production.</p>
                  <FileUploadForm />
                  <div className="file-list">
                    {files.map((file) => (
                      <div className="file-row" key={file.id}>
                        <span>{file.filename}</span>
                        <span>{Math.ceil(file.size / 1024)} KB</span>
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <p className="muted">File and blob upload is off for this setup mode. Ask Claude Code or Codex to add local file handling only if the workflow needs it.</p>
              )}
            </section>
          </aside>
        </div>
      </main>
    </div>
  );
}
