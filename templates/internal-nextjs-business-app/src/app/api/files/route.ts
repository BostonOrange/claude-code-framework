import { NextRequest, NextResponse } from "next/server";

import { requireApiUser } from "@/lib/auth/require-user";
import { recordAuditLog } from "@/lib/audit-log/repository";
import { uploadPrivateBlob } from "@/lib/blob/client";
import { createFileObject } from "@/lib/files/repository";
import { jsonError } from "@/lib/http/json";
import { clientIp, isRateLimited } from "@/lib/http/rate-limit";

export const runtime = "nodejs";

const MAX_FILE_SIZE = 10 * 1024 * 1024;

export async function POST(request: NextRequest) {
  const user = await requireApiUser(request);
  if (!user) return jsonError("Unauthorized", 401);

  if (isRateLimited(`${user.id}:${clientIp(request)}`, "files", 20, 60_000)) {
    return jsonError("Too many upload requests.", 429);
  }

  const formData = await request.formData();
  const file = formData.get("file");
  if (!(file instanceof File)) return jsonError("Missing file.", 400);
  if (file.size > MAX_FILE_SIZE) return jsonError("File is too large.", 413);

  const uploaded = await uploadPrivateBlob({
    ownerId: user.id,
    filename: file.name,
    contentType: file.type || "application/octet-stream",
    data: new Uint8Array(await file.arrayBuffer()),
  });

  const record = await createFileObject({
    blobName: uploaded.blobName,
    filename: file.name,
    contentType: uploaded.contentType,
    size: uploaded.size,
    uploadedById: user.id,
  });

  await recordAuditLog({
    actorId: user.id,
    action: "file.upload",
    target: record.id,
    metadata: { filename: record.filename, size: record.size },
  });

  return NextResponse.json({ file: record }, { status: 201 });
}
