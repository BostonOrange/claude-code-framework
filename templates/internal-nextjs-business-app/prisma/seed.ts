import { PrismaClient, TaskStatus, UserRole } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required");

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: databaseUrl }),
});

async function main() {
  const user = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {
      name: "Demo Admin",
      role: UserRole.owner,
      lastLoginAt: new Date(),
    },
    create: {
      email: "admin@example.com",
      name: "Demo Admin",
      role: UserRole.owner,
      tenantId: "default",
      lastLoginAt: new Date(),
    },
  });

  const existing = await prisma.task.count({ where: { createdById: user.id } });
  if (existing === 0) {
    await prisma.task.createMany({
      data: [
        {
          title: "Connect production SSO",
          summary: "Fill OIDC issuer, client id, and client secret for the customer tenant.",
          status: TaskStatus.todo,
          createdById: user.id,
        },
        {
          title: "Model the first internal workflow",
          summary: "Replace the demo task model with the business object the team needs to operate.",
          status: TaskStatus.doing,
          createdById: user.id,
        },
        {
          title: "Upload the first reference file",
          summary: "Use the blob route to store private customer documents or exports.",
          status: TaskStatus.done,
          createdById: user.id,
        },
      ],
    });
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
