# GitHub Actions Runner Selection Guidelines

This document provides guidelines for selecting appropriate GitHub Actions runner types based on workflow resource requirements.

## Runner Types and Use Cases

### Small Runners (ubuntu-latest, 2-core)

**Recommended for:**
- Security scans (Frogbot, dependency scanning)
- Linting and code formatting checks
- Simple build tasks
- Documentation generation
- Workflows with < 10 minute expected runtime

**Current workflows using this tier:**
- `frogbot.yml` - Security vulnerability scanning

### Medium Runners (ubuntu-latest-4-core)

**Recommended for:**
- Unit test suites
- Integration tests with moderate complexity
- Builds with parallel compilation
- Workflows with 10-30 minute expected runtime

### Large Runners (ubuntu-latest-8-core or custom)

**Recommended for:**
- Full integration test suites
- Performance testing
- Large-scale builds
- Multi-platform matrix builds
- Workflows with > 30 minute expected runtime

## Optimization Best Practices

### 1. Always Set Timeout Minutes

```yaml
jobs:
  my-job:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Adjust based on expected runtime
```

**Benefits:**
- Prevents runaway processes from consuming runner time
- Faster failure detection
- More predictable costs

**Recommended timeouts by workflow type:**
- Security scans: 15-30 minutes
- Linting: 5-10 minutes
- Unit tests: 15-30 minutes
- Integration tests: 30-60 minutes

### 2. Add Resource Monitoring

Include resource monitoring steps to track actual usage:

```yaml
steps:
  - name: Log workflow start time
    run: |
      echo "Workflow started at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
      echo "Runner: $(uname -a)"
      echo "CPU cores: $(nproc)"
      echo "Memory: $(free -h | grep Mem | awk '{print $2}')"

  # Your workflow steps here

  - name: Log resource usage
    if: always()
    run: |
      echo "Workflow completed at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
      echo "CPU usage during workflow:"
      top -bn1 | head -n 20
      echo "Memory usage:"
      free -h
      echo "Disk usage:"
      df -h
```

### 3. Optimize Matrix Strategies

- Only use matrix strategies when you need parallel execution
- Avoid single-value matrices (they add no parallelization benefit)
- Consider job dependencies and ordering

**Bad:**
```yaml
strategy:
  matrix:
    branch: ["master"]  # Single value, no benefit
```

**Good:**
```yaml
strategy:
  matrix:
    ruby-version: ["2.6", "2.7", "3.0", "3.1"]  # True parallelization
```

### 4. Choose Appropriate Runner Size

Consider these factors:
- **CPU requirements**: Does your workflow benefit from more cores?
- **Memory requirements**: Does your workflow need more RAM?
- **Duration**: Longer workflows may benefit from faster runners
- **Frequency**: High-frequency workflows should be optimized for cost

## Monitoring and Continuous Optimization

1. Review workflow run times monthly
2. Analyze resource usage logs to identify bottlenecks
3. Adjust runner sizes based on actual usage patterns
4. Remove or consolidate redundant workflows

## Questions?

For questions about runner selection or workflow optimization, please:
- Open an issue with the `github-actions` label
- Review the [GitHub Actions documentation](https://docs.github.com/en/actions)
- Consult with the DevOps team
