# Contributing to n8n Backup Solution

First off, thank you for considering contributing to the n8n Backup Solution! 🎉

This project aims to provide the best backup and disaster recovery solution for self-hosted n8n instances. Every contribution helps make it better for the entire n8n community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

### Our Pledge

We are committed to making participation in this project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

## How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed and what behavior you expected**
- **Include system information** (OS, Docker version, n8n version)
- **Add log files and error messages**

### 💡 Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description of the suggested enhancement**
- **Provide specific examples to demonstrate the steps**
- **Describe the current behavior and explain the behavior you expected**
- **Explain why this enhancement would be useful**

### 🛠️ Contributing Code

#### Areas We Need Help With

1. **🌐 Cloud Provider Support**
   - Add support for new cloud storage providers
   - Improve existing provider integrations
   - Add provider-specific optimizations

2. **🔐 Security & Encryption**
   - Enhance backup encryption methods
   - Add key management features
   - Implement security auditing

3. **📊 Monitoring & Alerting**
   - Build web dashboard for backup status
   - Add email/Slack/webhook notifications
   - Create health check endpoints

4. **🐳 Container & Orchestration**
   - Kubernetes deployment manifests
   - Helm charts
   - Docker Swarm support

5. **🧪 Testing & Quality**
   - Unit tests for backup scripts
   - Integration tests for restore procedures
   - Performance testing

6. **📚 Documentation**
   - User guides and tutorials
   - API documentation
   - Video tutorials
   - Translations

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Basic knowledge of bash scripting
- Understanding of n8n workflows (helpful but not required)

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork the repo on GitHub, then clone your fork
   git clone https://github.com/your-username/n8n-backup-solution.git
   cd n8n-backup-solution
   ```

2. **Set up development environment**
   ```bash
   # Copy environment configuration
   cp .env.example .env.dev
   
   # Start development services
   docker compose -f docker-compose.dev.yml up -d
   
   # Make scripts executable
   chmod +x *.sh
   ```

3. **Run tests**
   ```bash
   # Run the test suite
   ./run-tests.sh
   
   # Run specific test categories
   ./run-tests.sh backup
   ./run-tests.sh restore
   ./run-tests.sh cloud
   ```

4. **Verify setup**
   ```bash
   # Check services are running
   docker compose ps
   
   # Test basic backup
   ./backup-n8n.sh
   
   # Test backup listing
   ./restore-n8n.sh --list
   ```

### Development Tools

We provide several tools to make development easier:

- **`dev-setup.sh`** - Sets up development environment
- **`run-tests.sh`** - Runs all or specific tests
- **`lint.sh`** - Runs shellcheck and other linters
- **`format.sh`** - Formats code according to style guide
- **`build-docs.sh`** - Builds documentation locally

## Development Workflow

### Branch Naming

Use descriptive branch names that indicate the type of work:

- `feature/add-azure-support` - New features
- `fix/restore-permission-error` - Bug fixes
- `docs/update-cloud-setup-guide` - Documentation
- `test/add-backup-validation` - Testing improvements
- `refactor/improve-error-handling` - Code refactoring

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(cloud): add Azure Blob Storage support

Add support for Microsoft Azure Blob Storage as a backup destination.
Includes configuration wizard and upload/download functionality.

Closes #123
```

```
fix(restore): handle missing backup manifest files

Improve error handling when backup manifest files are corrupted
or missing during restore operations.

Fixes #456
```

### Testing Your Changes

Before submitting a pull request:

1. **Run the full test suite**
   ```bash
   ./run-tests.sh
   ```

2. **Test backup and restore workflows**
   ```bash
   # Test complete backup cycle
   ./backup-n8n.sh
   ./restore-n8n.sh --list
   
   # Test cloud integration (if applicable)
   ./cloud-backup.sh --upload-latest
   ./cloud-restore.sh --list
   ```

3. **Run linters**
   ```bash
   ./lint.sh
   ```

4. **Test with different configurations**
   ```bash
   # Test with different cloud providers
   # Test with/without encryption
   # Test with different retention settings
   ```

## Pull Request Process

### Before Submitting

1. **Ensure your code follows the style guidelines**
2. **Add or update tests for your changes**
3. **Update documentation if needed**
4. **Test your changes thoroughly**
5. **Rebase your branch on the latest main**

### Submitting Your PR

1. **Push your branch to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request on GitHub**
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what your changes do
   - Include testing instructions
   - Add screenshots if applicable

3. **PR Title Format**
   ```
   feat(cloud): add support for Azure Blob Storage
   fix(backup): resolve database connection timeout
   docs(readme): improve installation instructions
   ```

### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] I have tested my changes locally
- [ ] I have added tests for my changes
- [ ] All existing tests pass
- [ ] I have tested backup and restore workflows

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings

## Related Issues
Closes #123
```

### Review Process

1. **Automated Checks**
   - CI/CD pipeline runs tests
   - Code style checks
   - Security scans

2. **Code Review**
   - At least one maintainer review required
   - Address all feedback before merge
   - Be responsive to review comments

3. **Final Steps**
   - Squash commits if requested
   - Update branch if needed
   - Merge when approved

## Style Guidelines

### Shell Script Guidelines

1. **Use bash shebang**
   ```bash
   #!/bin/bash
   ```

2. **Enable strict mode**
   ```bash
   set -e  # Exit on error
   set -u  # Exit on undefined variable (optional)
   ```

3. **Use consistent formatting**
   ```bash
   # Good
   if [ "$variable" = "value" ]; then
       do_something
   fi
   
   # Bad
   if [$variable="value"]; then
   do_something
   fi
   ```

4. **Quote variables**
   ```bash
   # Good
   echo "Value: $variable"
   cp "$source" "$destination"
   
   # Bad
   echo Value: $variable
   cp $source $destination
   ```

5. **Use functions for repeated code**
   ```bash
   log() {
       echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
   }
   
   error() {
       echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
       exit 1
   }
   ```

6. **Add comments for complex logic**
   ```bash
   # Create temporary directory with proper cleanup
   temp_dir=$(mktemp -d)
   trap 'rm -rf "$temp_dir"' EXIT
   ```

### Documentation Guidelines

1. **Use clear, concise language**
2. **Include code examples**
3. **Add screenshots for UI features**
4. **Update table of contents**
5. **Use proper markdown formatting**

### Error Handling

1. **Always handle errors gracefully**
   ```bash
   if ! some_command; then
       error "Command failed"
   fi
   ```

2. **Provide helpful error messages**
   ```bash
   error "Failed to connect to cloud storage. Check credentials in .env file"
   ```

3. **Clean up on failure**
   ```bash
   trap cleanup_on_error ERR
   ```

## Community

### Getting Help

- **GitHub Discussions** - General questions and community help
- **GitHub Issues** - Bug reports and feature requests
- **Discord/Slack** - Real-time chat (if available)

### Recognition

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- GitHub contributors page
- Release notes for significant contributions
- Project documentation

### Becoming a Maintainer

Regular contributors who demonstrate:
- Deep understanding of the project
- High-quality contributions
- Helpful community participation
- Reliability and commitment

May be invited to become project maintainers with additional responsibilities:
- Reviewing pull requests
- Triaging issues
- Release management
- Community leadership

## Questions?

Don't hesitate to ask! You can:

1. **Open a Discussion** on GitHub for general questions
2. **Create an Issue** if you think you found a bug
3. **Join our community** channels for real-time help

Thank you for contributing! 🚀

---

*This contributing guide is inspired by and adapted from various open-source projects' best practices.*