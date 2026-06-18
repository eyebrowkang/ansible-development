# Release Notes

Create one file per release before pushing the tag:

```markdown
### Summary

Write the user-facing release summary here.

### Upgrade Notes

Write migration steps, configuration changes, compatibility notes, or:

No upgrade steps required.
```

Use the exact tag name as the filename, for example `.release-notes/v0.1.0.md`.
`git-cliff` generates the `### Changes` section automatically; do not write it here.
