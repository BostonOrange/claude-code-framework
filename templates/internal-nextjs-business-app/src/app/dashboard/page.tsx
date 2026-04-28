import { FileUploadForm } from "@/components/FileUploadForm";
import { LogoutButton } from "@/components/LogoutButton";
import { TaskComposer } from "@/components/TaskComposer";
import { requireUser } from "@/lib/auth/require-user";
import { listRecentFiles } from "@/lib/files/repository";
import { listDashboardTasks } from "@/lib/tasks/repository";

export default async function DashboardPage() {
  const user = await requireUser();
  const [tasks, files] = await Promise.all([
    listDashboardTasks(),
    listRecentFiles(8),
  ]);

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand">
          <strong>App Creator</strong>
          <span>Internal tools starter</span>
        </div>
        <div className="topbar-actions">
          <span className="pill">{user.role}</span>
          <LogoutButton />
        </div>
      </header>

      <main className="page">
        <div className="page-header">
          <div>
            <h1>Workspace</h1>
            <p>{user.name} signed in with {user.email}</p>
          </div>
          <span className="pill">{tasks.length} tasks</span>
        </div>

        <div className="grid">
          <section className="section">
            <div className="section-header">
              <div>
                <h2>Operating backlog</h2>
                <p>Replace this with the first real workflow object for the business team.</p>
              </div>
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
                  <h2>AI planner</h2>
                  <p>Server-side adapter, mock by default, OpenAI when configured.</p>
                </div>
              </div>
              <TaskComposer />
            </section>

            <section className="section">
              <div className="section-header">
                <div>
                  <h2>Blob storage</h2>
                  <p>Private uploads backed by Azurite locally or Azure Blob in production.</p>
                </div>
              </div>
              <FileUploadForm />
              <div className="file-list">
                {files.map((file) => (
                  <div className="file-row" key={file.id}>
                    <span>{file.filename}</span>
                    <span>{Math.ceil(file.size / 1024)} KB</span>
                  </div>
                ))}
              </div>
            </section>
          </aside>
        </div>
      </main>
    </div>
  );
}
