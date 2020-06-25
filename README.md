![Super Duper Linter](https://repository-images.githubusercontent.com/273591146/90b83f80-b3e8-11ea-9b88-9608d0b23aa1)
Inspired by [super-linter](https://github.com/github/super-linter) by GitHub, but using Powershell.

# Improvements
- Powershell 7 Runner Script
- Linters run independently, a failure in one won't impact others
- Linters are defined as structured objects
- Configuration System for Linters
- Problem Matcher and Github Annotations Support
- Linter Plugin Support
- Linters run in parallel for huge performance increase
- Files to lint are evaluated prior to run, better performance
- Linter Results are posted as annotations to the action, where possible
- Linters that can process multiple files at once are supported, e.g. for static type checking
- Supports Github Actions Inputs
- Provides a JSON representation of the results as an output