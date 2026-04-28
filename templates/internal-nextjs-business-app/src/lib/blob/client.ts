import { randomUUID } from "node:crypto";
import { BlobServiceClient } from "@azure/storage-blob";

import { requiredEnv } from "@/lib/env";

export interface UploadedBlob {
  blobName: string;
  size: number;
  contentType: string;
}

function blobServiceClient(): BlobServiceClient {
  return BlobServiceClient.fromConnectionString(requiredEnv("AZURE_STORAGE_CONNECTION_STRING"));
}

async function container() {
  const name = process.env.AZURE_STORAGE_CONTAINER ?? "app-files";
  const client = blobServiceClient().getContainerClient(name);
  await client.createIfNotExists();
  return client;
}

export async function uploadPrivateBlob(params: {
  filename: string;
  contentType: string;
  data: Uint8Array;
  ownerId: string;
}): Promise<UploadedBlob> {
  const safeName = params.filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const blobName = `${params.ownerId}/${randomUUID()}-${safeName}`;
  const blockBlob = (await container()).getBlockBlobClient(blobName);

  await blockBlob.uploadData(params.data, {
    blobHTTPHeaders: { blobContentType: params.contentType },
    metadata: {
      ownerId: params.ownerId,
      originalName: safeName,
    },
  });

  return {
    blobName,
    contentType: params.contentType,
    size: params.data.byteLength,
  };
}
