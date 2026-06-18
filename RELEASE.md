# Release Checklist

1. **Test dry-run**: Run `.\Win11-25H2-CalmMode.ps1 -Mode Audit` on `windows-latest` to ensure no errors.
2. **Update version and dates**: Verify `CHANGELOG_EN.md` and `CHANGELOG_UA.md` are up to date and dates are realistic.
3. **Commit working tree**: Ensure all changes (`.gitignore`, toggle switches, parameter descriptions) are committed.
4. **Generate SHA256**:
   ```powershell
   Get-FileHash -Path .\Win11-25H2-CalmMode.ps1 -Algorithm SHA256
   ```
   Add the hash to the release notes.
4. **Update CHANGELOG.md**:
   - Ensure the release date and new version are correctly listed.
5. **Guard archive content**: 
   - DO NOT create the zip manually.
   - Simply run `.\New-ReleaseArchive.ps1` in PowerShell. This script automatically generates a clean `.zip` archive containing only the safe distribution files, without `.git` or `.claude` folders, and automatically generates `checksums.txt`.
6. **Publish**: Create a new GitHub Release, attaching the script (and the ZIP archive) and pasting the SHA256 hash in the release description.
