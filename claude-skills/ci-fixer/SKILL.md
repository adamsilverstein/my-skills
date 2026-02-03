---
name: ci-fixer
description: "Fix failing CI tests on a PR and ensure all checks pass. Use when the user wants to fix CI failures, resolve failing tests, fix linting errors on a PR, or ensure all GitHub Actions/CI checks pass. Triggers include requests like 'fix the CI', 'fix failing tests on this PR', 'make the CI pass', 'fix linting errors', 'resolve CI failures', or any CI/test fixing task."
---

# CI Fixer Skill

Expert skill for diagnosing, fixing, and monitoring CI failures on GitHub Pull Requests. This skill is persistent and will continue working until all required CI checks pass.

## Core Workflow

### Phase 1: PR Analysis

1. **Identify the PR** - Get PR number from user or detect from current branch
2. **Fetch PR status** - Use `gh pr view` and `gh pr checks` to get current CI state
3. **Identify failing checks** - List all failing CI jobs with their status

### Phase 2: Diagnose Failures

For each failing check:

1. **Get failure logs** - Use `gh run view` to fetch detailed logs
2. **Identify failure type**:
   - Test failures (unit, integration, e2e)
   - Linting errors (ESLint, PHPStan, Prettier, etc.)
   - Build failures
   - Type checking errors
   - Security/dependency issues

### Phase 3: Fix Issues

Apply targeted fixes based on failure type:

**For Test Failures:**
- Read failing test files and implementation code
- Analyze test output to understand the failure
- Fix the implementation or update tests as appropriate
- Run tests locally to verify fix before pushing

**For Linting Errors:**
- Parse linting output for specific file:line:column errors
- Apply automatic fixes where available (`--fix` flags)
- Manually fix issues that require code changes
- Run linter locally to verify all issues resolved

**For Build Failures:**
- Check build logs for missing dependencies, syntax errors
- Fix import/export issues, type errors
- Verify build passes locally

**For Type Errors:**
- Analyze TypeScript/PHPStan/mypy output
- Fix type annotations and type mismatches
- Add missing type declarations

### Phase 4: Commit and Push

1. **Stage changes** - Add modified files
2. **Create atomic commit** - Clear message describing the fix
3. **Push to PR branch** - Push changes to trigger new CI run

### Phase 5: Monitor and Iterate

This is the persistent monitoring phase:

1. **Wait 3 minutes** - Allow CI jobs to start/progress
2. **Check CI status** - Use `gh pr checks` to get current state
3. **Evaluate results**:
   - **All checks pass** - Report success and exit
   - **Checks still running** - Continue waiting and monitoring
   - **New failures** - Return to Phase 2 to diagnose and fix
4. **Repeat** - Continue until all required checks pass

## Commands Reference

### PR Status Commands

```bash
# Get PR details
gh pr view [PR_NUMBER] --json number,title,headRefName,state,statusCheckRollup

# Check CI status
gh pr checks [PR_NUMBER]

# List all check runs with details
gh pr checks [PR_NUMBER] --json name,state,conclusion,startedAt,completedAt
```

### CI Run Commands

```bash
# List workflow runs for the PR
gh run list --branch [BRANCH_NAME] --limit 10

# View specific run details
gh run view [RUN_ID]

# View run logs (shows failure details)
gh run view [RUN_ID] --log-failed

# Download run logs for analysis
gh run view [RUN_ID] --log > ci-logs.txt
```

### Fix and Push Commands

```bash
# Stage specific files
git add [FILES...]

# Commit with descriptive message
git commit -m "Fix: [description of CI fix]"

# Push to PR branch
git push origin [BRANCH_NAME]
```

## Monitoring Loop Implementation

When monitoring CI, use this pattern:

```bash
# Check if all required checks pass
gh pr checks [PR_NUMBER] --json name,state,conclusion | jq '.[] | select(.conclusion != "success" and .conclusion != "skipped" and .state != "pending")'
```

**Status interpretation:**
- `state: "completed"` + `conclusion: "success"` = Passed
- `state: "completed"` + `conclusion: "failure"` = Failed (needs fix)
- `state: "completed"` + `conclusion: "skipped"` = Skipped (OK)
- `state: "pending"` or `state: "queued"` = Still running (wait)
- `state: "in_progress"` = Currently running (wait)

## Detailed Fix Strategies

### JavaScript/TypeScript Linting (ESLint)

```bash
# Run ESLint with auto-fix
npx eslint --fix [FILES_OR_DIRS]

# Check what would be fixed
npx eslint [FILES_OR_DIRS]
```

Common fixes:
- Missing semicolons, trailing commas
- Unused variables (remove or prefix with `_`)
- Import ordering
- Consistent quotes

### Prettier Formatting

```bash
# Auto-fix formatting
npx prettier --write [FILES_OR_DIRS]

# Check formatting
npx prettier --check [FILES_OR_DIRS]
```

### PHP Linting (PHPCS/PHPStan)

```bash
# Auto-fix PHPCS issues
./vendor/bin/phpcbf [FILES_OR_DIRS]

# Run PHPStan
./vendor/bin/phpstan analyse [FILES_OR_DIRS]
```

### Test Failures

1. Read the test file and understand what it's testing
2. Read the implementation being tested
3. Determine if the test or implementation is wrong
4. Fix the appropriate code
5. Run tests locally: `npm test`, `phpunit`, `pytest`, etc.

### TypeScript Type Errors

```bash
# Run type checking
npx tsc --noEmit

# Check specific files
npx tsc --noEmit [FILES]
```

Common fixes:
- Add missing type annotations
- Fix type mismatches
- Add null checks
- Update interface definitions

## Robustness Features

### Handling Flaky Tests

If a test passes locally but fails in CI:
1. Check for environment-specific issues
2. Look for race conditions or timing issues
3. Check for missing test fixtures in CI
4. Consider adding retry logic or test isolation

### Handling Rate Limits

If hitting GitHub API rate limits:
1. Increase wait time between checks
2. Use `gh api --cache 60s` for cacheable requests
3. Batch API calls where possible

### Handling Long-Running CI

For CI jobs that take >10 minutes:
1. Extend monitoring interval to 5 minutes
2. Check only the slowest jobs' status
3. Report progress to user during wait

## Success Criteria

The skill completes successfully when:
1. `gh pr checks` shows all required checks with `conclusion: "success"` or `conclusion: "skipped"`
2. No checks are in `state: "pending"` or `state: "in_progress"`
3. The PR is ready for review/merge from a CI perspective

## Example Usage

**User request:** "Fix the failing CI on PR #42"

**Skill execution:**
1. `gh pr checks 42` - Identify failing: "lint", "test-unit"
2. `gh run view [RUN_ID] --log-failed` - Get error details
3. Fix lint errors with `npx eslint --fix`
4. Fix test by updating implementation
5. `git add . && git commit -m "Fix: Resolve ESLint errors and update user validation"`
6. `git push origin feature-branch`
7. Wait 3 minutes, check `gh pr checks 42`
8. Repeat until all checks pass
9. Report: "All CI checks now passing on PR #42"

## Important Notes

- **Always run fixes locally first** before pushing to verify they work
- **Make atomic commits** - One commit per logical fix when possible
- **Don't blindly auto-fix** - Review changes to ensure they're correct
- **Preserve code intent** - Don't change functionality to pass tests unless the test is wrong
- **Ask for clarification** - If a fix is ambiguous or could break functionality, ask the user
- **Be persistent** - Continue the monitor/fix loop until truly passing or user cancels
