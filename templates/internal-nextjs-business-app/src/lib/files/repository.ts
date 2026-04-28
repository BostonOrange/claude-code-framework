import type { FileObject } from "@/generated/prisma/client";
import { prisma } from "@/lib/db/prisma";
import type { FileObjectRecord } from "@/lib/domain/types";

function toFileObjectRecord(file: FileObject): FileObjectRecord {
  return {
    id: file.id,
    blobName: file.blobName,
    filename: file.filename,
    contentType: file.contentType,
    size: file.size,
    uploadedAt: file.uploadedAt,
    uploadedById: file.uploadedById,
  };
}

export async function listRecentFiles(limit = 8): Promise<FileObjectRecord[]> {
  const files = await prisma.fileObject.findMany({
    orderBy: { uploadedAt: "desc" },
    take: limit,
  });

  return files.map(toFileObjectRecord);
}

export async function createFileObject(params: {
  blobName: string;
  filename: string;
  contentType: string;
  size: number;
  uploadedById: string;
}): Promise<FileObjectRecord> {
  const file = await prisma.fileObject.create({
    data: params,
  });

  return toFileObjectRecord(file);
}
