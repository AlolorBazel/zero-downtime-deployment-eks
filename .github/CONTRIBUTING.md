# Contributing to Zero-Downtime Deployment Project

Thank you for your interest in contributing! This project serves as an educational reference for zero-downtime deployments on AWS EKS.

## 🎯 About This Project

This is a **reference implementation** designed to demonstrate best practices for:
- Blue-Green deployments
- Canary deployments
- Argo Rollouts configuration
- AWS EKS infrastructure

## 🤝 How to Contribute

### Reporting Issues

If you find issues or have suggestions:

1. **Check existing issues** to avoid duplicates
2. **Provide detailed information:**
   - What were you trying to do?
   - What happened instead?
   - Steps to reproduce
   - Environment details (OS, versions, etc.)

### Suggesting Enhancements

We welcome suggestions for:
- Documentation improvements
- Configuration optimizations
- Additional deployment strategies
- Cost optimization techniques
- Security enhancements

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
   - Follow existing code style
   - Update documentation as needed
   - Test your changes thoroughly
4. **Commit with clear messages**
   ```bash
   git commit -m "feat: add XYZ feature"
   ```
5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
6. **Open a Pull Request**
   - Describe your changes clearly
   - Reference any related issues
   - Include screenshots if applicable

## 📋 Contribution Guidelines

### Code Style

- **Terraform:** Follow HashiCorp best practices
- **Kubernetes:** Use standard YAML formatting
- **Python:** Follow PEP 8
- **Shell scripts:** Use shellcheck for validation

### Documentation

- Keep documentation up-to-date with code changes
- Use clear, concise language
- Include examples where helpful
- Update cost estimates if infrastructure changes

### Testing

Before submitting:
- Test Terraform configurations with `terraform plan`
- Validate Kubernetes manifests with `kubectl apply --dry-run`
- Test scripts in a clean environment
- Verify documentation accuracy

## 🔒 Security

- **Never commit secrets** (AWS keys, passwords, etc.)
- Use `.gitignore` for sensitive files
- Report security issues privately via email

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

All contributors will be acknowledged in the project documentation.

## 📧 Questions?

Feel free to open an issue for questions about contributing.

---

**Thank you for helping make this project better!** 🚀
