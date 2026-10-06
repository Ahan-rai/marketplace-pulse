# Push to GitHub

The repository is initialized on branch `main` and all project files are staged.
A commit was not created automatically because Git identity is machine-specific.

Run once:

```bash
git config user.name "Ahan Rai"
git config user.email "YOUR_GITHUB_EMAIL"
```

Then:

```bash
git commit -m "Build marketplace pulse analytics and real data findings"
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin main
```

Before publishing, verify that `.env` and the raw CSVs are not staged:

```bash
git status
```

The raw Olist files are intentionally ignored by `.gitignore`.
