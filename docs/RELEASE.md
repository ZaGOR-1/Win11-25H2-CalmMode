# Release Checklist

1. **Test dry-run**: Run `.\Win11-25H2-CalmMode.ps1 -Mode Audit` on `windows-latest` to ensure no errors.
   Also parse the main script and GUI with Windows PowerShell 5.1, then run GUI `-SelfTest`.
2. **Update version and dates**: Verify `CHANGELOG_EN.md` and `CHANGELOG_UA.md` are up to date and dates are realistic.
3. **Commit working tree**: Ensure all changes (`.gitignore`, toggle switches, parameter descriptions) are committed.
4. **Update changelogs**:
   - Ensure `CHANGELOG_UA.md` and `CHANGELOG_EN.md` list the release date and new version correctly.
5. **Build the archive**:
   - DO NOT create the zip manually.
   - Simply run `.\New-ReleaseArchive.ps1` in PowerShell. This script produces a clean
     `Win11-25H2-CalmMode-v<version>.zip` (version read from `VERSION`) containing only the
     safe distribution files — without `.git`, `.claude`, `.codex`, local backups, logs, or reports — and generates `checksums.txt`
     plus `Win11-25H2-CalmMode-v<version>.zip.sha256` next to it.
6. **Verify the archive**:
   - Inspect the zip contents (no `.git/`, `.claude/`, `.codex/`, `.reg`, logs, reports, or nested zip).
   - Confirm the value in `Win11-25H2-CalmMode-v<version>.zip.sha256` matches the actual zip hash.
7. **Publish**: Create a new GitHub Release for the `v<version>` tag, attaching the ZIP archive,
   its `.sha256`, and `checksums.txt`.
