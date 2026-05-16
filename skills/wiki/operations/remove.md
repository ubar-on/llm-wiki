# remove

Delete a wiki and all its contents.

Syntax: `/llm-wiki:wiki remove <name>`

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. Read `QMD=<bool>` as `QMD_AVAILABLE`.

---

## Steps

### 1. Resolve wiki path
`${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/`

### 2. Verify it exists
If not, abort: "Wiki '<name>' does not exist."

### 3. Confirm with user
List directory contents and ask:
> "This will permanently delete the '<name>' wiki and all its contents. Proceed? (y/n)"

Do NOT proceed until the user confirms with `y`.

`[llm-wiki:remove] step=3 CONFIRMED=<bool>`

### 4. Remove qmd collection
If `QMD_AVAILABLE=true`:
```bash
"${QMD}" collection remove <name>
```

### 5. Remove from filesystem
If `GIT=true` from the READY line:
```bash
git -C ${VAULT_ROOT} rm -rf "${WIKI_SUBDIR}/<name>/" && git -C ${VAULT_ROOT} commit -m "remove: <name> wiki"
```
Otherwise:
```bash
rm -rf "${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/"
```

### 6. Confirm
Print: "Wiki '<name>' has been removed."

`[llm-wiki:remove] DONE`
