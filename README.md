![Super Duper Linter](https://repository-images.githubusercontent.com/273591146/90b83f80-b3e8-11ea-9b88-9608d0b23aa1)
Inspired by github/super-linter, but using Powershell.

# Improvements
- Powershell 7 Runner Script
- Linters run independently, a failure in one won't impact others
- Linters are defined as structured objects
- Configuration System for Linters
- Linter Plugin Support
- Linters run in parallel for huge performance increase
- Files to lint are evaluated prior to run, better performance
- Linter Results are posted as annotations to the action, where possible