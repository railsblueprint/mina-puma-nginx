# Changelog

## [1.1.0] - 2025-01-19

### Added
- Environment-specific robots.txt rewrite rule in nginx template
  - Automatically serves `robots-<environment>.txt` files when present
  - Falls back to regular `robots.txt` if environment-specific file doesn't exist
- New `nginx:certbot` task for automated SSL certificate management
  - Uses certbot's nginx plugin for seamless integration
  - Automatically detects domains from `nginx_server_name`
  - Email is optional (assumes certbot may already be configured)
  - Supports dry-run/staging mode for testing
- Comprehensive test suite with RSpec
  - 42 tests covering all functionality
  - Template syntax validation
  - Edge case handling
  - Integration tests

### Changed
- Updated README with documentation for new features
- Added RSpec as development dependency

## [1.0.4] - Previous releases
- Initial gem functionality
- Basic nginx configuration management
- Puma integration