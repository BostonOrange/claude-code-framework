import type { Metadata } from "next";
import { projectIdentity } from "@/lib/project-config";
import "./globals.css";

export function generateMetadata(): Metadata {
  const project = projectIdentity();
  return {
    title: project.name,
    description: project.description,
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
