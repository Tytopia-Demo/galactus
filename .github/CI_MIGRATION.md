# CI Migration from Kokoro to GitHub Actions

This document describes the migration from Kokoro CI to GitHub Actions.

## Overview

This repository has been migrated from Kokoro (Google's internal CI system) to GitHub Actions for continuous integration and deployment.

## What Was Migrated

### Build Triggers

**Before (Kokoro):**
- Presubmit builds on pull requests
- Continuous builds on merges to master
- Post builds for link checking
- Nightly builds via schedule
- Release builds on tags

**After (GitHub Actions):**
- CI workflow runs on pull requests and pushes to master
- Scheduled nightly builds via cron
- Link checking on master branch pushes
- Release workflow on version tags
- All workflows support manual triggering via workflow_dispatch

### Test Matrix

**Before (Kokoro):**
- Linux (Docker-based)
- macOS
- Windows

**After (GitHub Actions):**
- ubuntu-latest
- macos-latest
- windows-latest
- Matrix includes Ruby versions: 2.6, 2.7, 3.0, 3.1, 3.2

### Credential Management

**Before (Kokoro):**
- Credentials stored in Kokoro's internal keystore
- Service account JSON files from GCS buckets
- Environment variables injected via Kokoro configuration

**After (GitHub Actions):**
- Secrets stored in GitHub repository/organization secrets
- Required secrets:
  - `GOOGLE_APPLICATION_CREDENTIALS` - For Google Cloud integration tests
  - `RUBYGEMS_API_TOKEN` - For publishing to RubyGems
- Credentials accessed via `${{ secrets.SECRET_NAME }}` syntax

### Artifact Publishing

**Before (Kokoro):**
- Gem publishing via custom scripts
- Documentation publishing via custom tasks
- Sponge XML log collection

**After (GitHub Actions):**
- Gem publishing to RubyGems in release workflow
- Documentation publishing via existing Rake tasks
- GitHub Releases for distribution
- Built-in artifact and log management

### Workflows Created

1. **ci.yml** - Main CI workflow
   - Runs tests on all platforms and Ruby versions
   - Executes RuboCop, unit tests, integration tests, and RSpec
   - Performs link checking on master branch

2. **release.yml** - Release workflow
   - Triggers on version tags (v*)
   - Builds and publishes gem to RubyGems
   - Publishes documentation
   - Creates GitHub Release with gem artifact

3. **code-quality.yml** - Code quality workflow
   - Runs RuboCop style checks
   - Generates code coverage reports
   - Uploads coverage to Codecov

4. **frogbot.yml** - Security scanning (pre-existing)
   - Maintained from previous configuration

## Required Setup

### Repository Secrets

Configure the following secrets in the GitHub repository settings:

1. **RUBYGEMS_API_TOKEN**
   - Generate from https://rubygems.org/settings/edit
   - Required for release workflow

2. **GOOGLE_APPLICATION_CREDENTIALS** (optional)
   - Service account JSON for integration tests
   - Can be stored as a secret if needed for integration tests

### GitHub Environments

For enhanced security, configure a `release` environment with:
- Required reviewers for release approvals
- Deployment branches restricted to tags matching `v*`

## Status Badge

The README now includes a GitHub Actions CI status badge:
```markdown
[![CI](https://github.com/googleapis/google-auth-library-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/googleapis/google-auth-library-ruby/actions/workflows/ci.yml)
```

## Removed Files

The `.kokoro` directory containing Kokoro configuration files has been retained for reference but is no longer actively used. It can be removed in a future cleanup PR if desired.

## Migration Benefits

1. **Transparency**: All CI configuration is in the repository and visible to contributors
2. **Modern tooling**: GitHub Actions provides better integration with GitHub features
3. **Community access**: External contributors can see and understand the CI process
4. **Cost efficiency**: GitHub Actions provides generous free tier for open source
5. **Unified platform**: CI/CD on the same platform as code hosting

## Troubleshooting

### Integration Tests Failing

Integration tests require Google Cloud credentials. If these tests fail in PRs from external contributors, this is expected and the `continue-on-error: true` flag prevents workflow failure.

### Release Workflow Not Running

Ensure:
1. The tag follows the `v*` pattern (e.g., `v1.0.0`)
2. `RUBYGEMS_API_TOKEN` secret is configured
3. The release environment is properly set up (if using environment protection)

### Platform-Specific Failures

Some tests may behave differently on different platforms. Check:
1. File path separators (use `File.join` instead of string concatenation)
2. Line endings (configure Git attributes appropriately)
3. Platform-specific dependencies
