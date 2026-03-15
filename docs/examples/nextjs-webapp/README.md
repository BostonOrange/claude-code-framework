# Example: Next.js Web Application

## Setup

```bash
cd my-nextjs-app/
bash ~/Developer/claude-code-framework/setup.sh
# Choose: 6 (React/Next.js), 4 (GitHub Issues), 1 (GitHub Actions), main, 1 (Slack)
```

## Domain Skills to Add

### API Endpoints
```
/add-reference api endpoints      # Scan app/api/ for route handlers
/add-reference api middleware      # Document middleware patterns
```

### Database
```
/add-reference db schema          # Scan Prisma schema or migrations
/add-reference db queries         # Document query patterns
```

### Components
```
/add-reference ui components      # Scan components/ directory
/add-reference ui hooks           # Document custom hooks
```

## CLAUDE.md Additions

### Code Standards
- Use TypeScript strict mode
- Server Components by default, `'use client'` only when needed
- Zod for runtime validation at system boundaries
- Error boundaries for each route segment

### Testing
```bash
npm test                    # Jest unit tests
npm run test:e2e           # Playwright end-to-end
npm run lint               # ESLint
npm run type-check         # TypeScript compiler
```

### Deployment
```bash
vercel deploy              # Preview deployment
vercel deploy --prod       # Production deployment
```

## Factory Pipeline Customization

The factory validate workflow deploys a Vercel preview:

```yaml
# .github/workflows/factory-validate.yml
- name: Deploy preview
  run: |
    PREVIEW_URL=$(npx vercel deploy --token=${{ secrets.VERCEL_TOKEN }})
    echo "PREVIEW_URL=$PREVIEW_URL" >> $GITHUB_ENV

- name: Post preview link
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.createComment({
        issue_number: context.payload.pull_request.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Preview Deploy ✅\n\n${process.env.PREVIEW_URL}`
      });
```
