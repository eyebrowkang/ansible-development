# Release Notes

Create one file per scaffold release before pushing the tag:

```markdown
### Summary

Write the user-facing release summary here.

### Upgrade Notes

Write migration steps, configuration changes, compatibility notes, or:

No upgrade steps required.
```

Use the exact tag name as the filename, for example `.release-notes/v1.2.0.md`.
`git-cliff` generates the `### Changes` section automatically; do not write it here.
