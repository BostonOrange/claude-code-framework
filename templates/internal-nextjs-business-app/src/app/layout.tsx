import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "App Creator",
  description: "AI-enabled internal tools starter with SSO, Postgres, and blob storage.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
