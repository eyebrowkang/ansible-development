# `templates/_shared/` — de-duplicated template files

Canonical home for files that are **byte-identical** across the role
(`templates/role/template/`) and collection (`templates/collection/template/`)
subtrees. Each such file lives **once** here; both subtrees carry a **relative
symlink** pointing back to it.

This directory is **not** a copier `_subdirectory` and is never rendered on its
own — `_subdirectory: templates/{{ kind }}/template` only ever walks the role or
collection subtree. `_shared/` is reached *only* by following those subtrees'
symlinks.

## How it renders to a real file (not a symlink)

`copier.yml` sets **`_preserve_symlinks: false`**. With that, copier **follows**
each symlink at render time, reads its **target's** content, and writes a
**regular file** into the generated role/collection. No symlink ever leaks into
a generated artifact (verified: `find <generated> -type l` is empty). A
templated link (name ends in `.jinja`, e.g. `.copier-answers.yml.jinja`) is
still rendered through Jinja — the link's own name decides that, the target's
content supplies the body.

copier's render guard refuses a non-preserved symlink whose target resolves
**outside the template repo** (`ForbiddenPathError`). Two rules fall out of it:

1. **The shared files must live inside the repo** — hence `templates/_shared/`,
   not somewhere external.
2. **The symlinks must be *relative***, never absolute. copier clones the
   template into a temp dir before rendering (it generates from the latest
   **git tag** by default, or a `--vcs-ref`); a relative link resolves inside
   that clone, an absolute one would point at the original checkout (breaking,
   or tripping the guard).

A third, non-copier rule keeps `copier update` quiet for already-generated
repos: **the bytes in `_shared/` must equal what both subtrees rendered before
the file was de-duplicated.** Moving an identical copy here (rather than editing
it) guarantees that, so existing roles/collections see no spurious diff on their
next update.

## Current inventory

| `_shared/` file              | role symlink                                                              | collection symlink                                                                       |
| ---------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `.ansible-lint`              | `role/template/.ansible-lint`                                            | `collection/template/.ansible-lint`                                                      |
| `.copier-answers.yml.jinja`  | `role/template/.copier-answers.yml.jinja`                               | `collection/template/.copier-answers.yml.jinja`                                          |
| `.pre-commit-config.yaml`    | `role/template/.pre-commit-config.yaml`                                 | `collection/template/.pre-commit-config.yaml`                                            |
| `.python-version`            | `role/template/.python-version`                                          | `collection/template/.python-version`                                                    |
| `renovate.json`              | `role/template/{% if dependency_updates %}renovate.json{% endif %}`      | `collection/template/{% if dependency_updates %}renovate.json{% endif %}`                |
| `molecule/create.yml`        | `role/template/molecule/{…default…}/create.yml`                          | `collection/template/extensions/molecule/{…default…}/create.yml`                         |
| `molecule/destroy.yml`       | `role/template/molecule/{…default…}/destroy.yml`                         | `collection/template/extensions/molecule/{…default…}/destroy.yml`                        |

(`{…default…}` = `{% if include_docker %}default{% endif %}`.)

## Splitting later (when role and collection must diverge)

Sharing is a bet that these files *stay* identical. The moment one kind needs a
file the other shouldn't get, **split it** — don't add Jinja `{% if kind %}`
branches inside a shared file.

**Only one kind diverges** (the common case): replace *that* kind's symlink with
a real copy and edit it. The other kind keeps its symlink; the shared file stays.

```bash
# e.g. the collection needs a different .ansible-lint
rm "templates/collection/template/.ansible-lint"
cp "templates/_shared/.ansible-lint" "templates/collection/template/.ansible-lint"
# …now edit the collection copy. Role still symlinks to _shared/.
```

**Both kinds diverge:** give each its own real copy, then drop the shared file.

```bash
for k in role collection; do
  sub="templates/$k/template"
  rm "$sub/.ansible-lint"
  cp "templates/_shared/.ansible-lint" "$sub/.ansible-lint"
done
git rm "templates/_shared/.ansible-lint"   # and remove its row from the table above
```

For a conditional-name file, recreate the real file under the **Jinja path name**
(quote it), e.g. `cp templates/_shared/renovate.json "templates/collection/template/{% if dependency_updates %}renovate.json{% endif %}"`.

## Adding a new shared file

Confirm the two copies are byte-identical (`cmp role-copy coll-copy`), move one
into `_shared/`, delete the other, create a **relative** symlink from each
subtree, and add a row to the table above.

## Testing template changes locally

copier defaults to the latest **git tag**, so a bare `copier copy <repo>` tests
the last *release*, not your working tree. Generate from `HEAD` instead — pass
`--vcs-ref=HEAD` (what `.forgejo/workflows/test-template.yml` does), or generate
from a tagless copy of the tree. After rendering, `find <generated> -type l`
must come back empty.
