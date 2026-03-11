---
name: core-commit
description: "Write WordPress core commit messages following official guidelines. Use when committing to WordPress core, drafting SVN commit messages, or preparing a PR for merge. Triggers include 'write commit message', 'core commit', 'draft commit message', 'prepare commit', 'wp core commit', or any WordPress core SVN commit task."
---

# WordPress Core Commit Message Skill

Draft commit messages for WordPress core following the official commit message guidelines at https://make.wordpress.org/core/handbook/best-practices/commit-messages/.

## Inputs Required

Before drafting a commit message, gather:

1. **The GitHub PR URL** - to read the PR description, diff, and props bot comment. Before asking the user, try to determine the PR URL from the current branch or context if possible.
2. **The Trac ticket number** - usually linked in the PR description (e.g. `https://core.trac.wordpress.org/ticket/XXXXX`)
3. **Whether this is a backport** - if so, note the branch and original changeset
4. **Whether the ticket is being fixed or just referenced** - determines `Fixes` vs `See`

## Gathering Props

Props are critical. Be generous - nearly everyone who contributed deserves credit.

### Step 1: GitHub Props Bot

Find the props bot comment on the PR (posted by `github-actions[bot]`). It contains a pre-built props line based on GitHub activity. Use this as your starting base.

To fetch it:
```
gh api repos/WordPress/wordpress-develop/issues/{PR_NUMBER}/comments --jq '.[] | select(.user.login == "github-actions[bot]") | .body'
```

### Step 2: Trac Ticket Contributors

Scrape the Trac ticket for ALL participants. Be generous: anyone who reported, commented, confirmed, tested, reviewed, or contributed patches deserves props.

To fetch Trac ticket participants:
```
curl -s "https://core.trac.wordpress.org/ticket/{TICKET_NUMBER}" | python3 -c "
import sys, re, html as htmlmod
page = sys.stdin.read()

# Get reporter
reporter = re.search(r'<td[^>]*headers=\"h_reporter\"[^>]*>\s*<a[^>]*>([^<]+)</a>', page)
if reporter:
    print(f'Reporter: {reporter.group(1).strip()}')

# Get owner
owner = re.search(r'<td[^>]*headers=\"h_owner\"[^>]*>\s*<a[^>]*>([^<]+)</a>', page)
if owner:
    print(f'Owner: {owner.group(1).strip()}')

# Get CC list
cc = re.search(r'<td[^>]*headers=\"h_cc\"[^>]*>(.*?)</td>', page, re.DOTALL)
if cc:
    cc_text = re.sub(r'<[^>]+>', '', cc.group(1)).strip()
    if cc_text:
        print(f'Cc: {cc_text}')

# Get all comment authors
authors = re.findall(r'class=\"trac-author-user\"[^>]*>([^<]+)<', page)
# Also check for other author patterns
authors += re.findall(r'class=\"author\"[^>]*>\s*<a[^>]*>([^<]+)</a>', page)
unique = sorted(set(a.strip() for a in authors if a.strip()))
if unique:
    print(f'Comment authors: {\", \".join(unique)}')

# Get attachment authors
attach_authors = re.findall(r'class=\"trac-author\"[^>]*>([^<]+)<', page)
unique_attach = sorted(set(a.strip() for a in attach_authors if a.strip()))
if unique_attach:
    print(f'Attachment/change authors: {\", \".join(unique_attach)}')
"
```

### Step 3: Merge Props Lists

Combine all usernames from both sources. Rules:
- Use **WordPress.org usernames** (not GitHub handles). The props bot already converts these.
- For Trac users, the displayed name IS the w.org username.
- If a user has a space in their display name, use the slug from their w.org profile URL.
- Do NOT prefix with `@`.
- The committer should generally omit themselves from props (their name is on the commit itself), UNLESS it was a major collaborative effort.
- Separate usernames with comma + space.
- End the props line with a period.

## Commit Message Format

```
Component: Brief summary.

Longer description explaining what changed and why. Use backticks for `function_names` and `hook_names`.

Additional paragraphs as needed.

Follow-up to [NNNNN], [NNNNN].

Reviewed by committer-username.
Merges [NNNNN] to the X.X branch.

Props person1, person2, person3.
Fixes #NNNNN. See #NNNNN, #NNNNN.
```

## Format Rules

### Line 1: Ticket Number
- The Trac ticket number alone on the first line.

### Line 2: Brief Summary
- `Component: Brief summary.`
- Aim for ~50 characters, max 70 (including component prefix).
- Use imperative mood: "Fix issue" not "Fixes issue" or "Fixed issue".
- Must end with a period.
- The component prefix should match the Trac component (e.g. `Editor:`, `Media:`, `Comments:`, `Taxonomy:`, `REST API:`).

### Description
- Separated from summary by a blank line.
- Explain what changed and why. Be direct and concise but thorough enough to stand alone.
- Use backticks around code references (`function_name`, `hook_name`, `$variable`).
- Can be multiple paragraphs separated by blank lines.
- Do NOT manually wrap lines.
- Each sentence/line should begin with a capital letter and end with a period.
- When referencing GitHub issues, use full URLs.
- Avoid the words "props", "backport", "backports", "backporting" in the description.

### Follow-up to (optional)
- Use when the commit directly relates to previous changesets.
- Preceded by a blank line.
- Wrap changeset numbers in square brackets: `Follow-up to [27195], [41062].`

### Reviewed by / Merges (backports only)
- Use only when backporting to a release branch.
- Preceded by a blank line.
- `Reviewed by committer1, committer2.` on one line.
- `Merges [NNNNN] to the X.X branch.` on the next line (no blank line between them).

### Props
- Preceded by a blank line.
- Format: `Props username1, username2, username3.`
- No colon after "Props".
- No `@` prefix on usernames.
- End with a period.
- Be generous: include bug reporters, patch authors, reviewers, testers, and anyone who contributed meaningfully to discussion.

### Ticket References
- Directly below props (no blank line).
- `Fixes #NNNNN.` closes the ticket in Trac.
- `See #NNNNN.` references without closing.
- Multiple: `Fixes #19867, #9864. See #31696.`

## Tone and Style Guide

Match this voice and level of detail (based on the committer's established style):

- **Direct and concise.** Lead with what changed, then explain why. No filler.
- **Technical but accessible.** Reference specific functions, hooks, and parameters with backticks. Explain the user-facing impact when relevant.
- **1-3 sentences for the description** is typical. Use more only when the change is architecturally significant or affects multiple areas.
- **Link to related GitHub issues** when the change originated from or relates to Gutenberg issues.
- **Use plain, active language.** "Fix an issue where..." or "Ensure that..." or "Prevent X from Y."
- **Explain edge cases briefly** when relevant: "This fix only affects the 'note' type."
- **For larger features**, provide an "Overview of changes:" bulleted list.

### Example messages (for tone reference):

```
Notes: trash (or delete) child notes when parent is deleted.

Ensure that when a top level note is trashed (or deleted), all of its replies (children) are also trashed or deleted. If EMPTY_TRASH_DAYS is 0, notes are deleted immediately; otherwise they are marked as trash for later cleanup.

Props adamsilverstein, desrosj, wildworks, mamaduka, karthickmurugan, jeffpaul, shailu25.
Fixes #64240.
```

```
Editor: Notes should not appear in the context of comments.

Prevent notes from inadvertently showing up in the context of comments - including on the Dashboard recent comments widget and the "Mine" count on the Comments page. Notes are stored as a custom 'note' comment type and this change ensures the note type is only returned when explicitly requested, or when 'all' types are requested.

The query for note children is modified to return all child notes. This fixes an issue where children were no longer being returned for the 'note' type.

Also fixes https://github.com/WordPress/gutenberg/issues/72548 and https://core.trac.wordpress.org/ticket/64152.

Props adamsilverstein, timothyblynjacobs, shailu25, peterwilsoncc, westonruter, mamaduka, kadamwhite.
Fixes #64145.
Fixes #64152.
```

```
Editor: Introduce the PHP-related code for Notes.

Bring the PHP part of the new Notes feature into core for the 6.9 release. See related Gutenberg Issue: https://github.com/WordPress/gutenberg/issues/71826. These changes do not impact any user facing functionality, they simply prepare core for the JavaScript functionality that will come over in a separate sync.

Overview of changes:
- Ensure Notes are not included in comment counts
- Enable the note type (REST API)
- Adjust capabilities so edit_post cap implies ability to edit notes
- Enable empty and duplicate notes for resolve/re-open actions
- Add control over notes with post type supports check
- Register new note resolution status meta

Props ristojovanovic, adamsilverstein, jeffpaul, wildworks, mamaduka, swissspidy, timothyblynjacobs, kadamwhite.

Fixes #64096.
```

## Workflow

When asked to draft a commit message:

1. **Determine the PR URL** ask the user when unable to determine automatically.
2. **Fetch the PR** to get the title, description, diff summary, and linked Trac ticket.
3. **Fetch the props bot comment** from the PR.
4. **Fetch the Trac ticket** to get all participants.
5. **Merge the props lists** from both sources (be generous).
6. **Determine the component** from the Trac ticket or PR title prefix.
7. **Draft the commit message** following the format above.
8. **Present the message** for review, noting any props uncertainties (e.g. unlinked GitHub accounts that may need manual w.org username lookup).
9. **Ask for review** and iterate as needed on the message.
10. **Post to PR description** once approved for visibility and feedback before committing to SVN.

## Dependencies

This skill requires the following CLI tools to be available in your environment:

- **`gh`** — GitHub CLI, used to fetch PR details and props bot comments
- **`curl`** — used to scrape Trac ticket pages for contributor information
- **`python3`** — used to parse HTML from Trac ticket pages

## Important Notes

- Ticket numbers `#NNNNN` and changeset numbers `[NNNNN]` auto-link in Trac and Slack.
- Do NOT use `#` followed by numbers for anything other than Trac ticket references.
- Never commit to multiple branches in the same commit.
- During RC stage, all patches must be reviewed by a second committer.
- The committer's username should generally be omitted from props (it's implied by the commit attribution).
