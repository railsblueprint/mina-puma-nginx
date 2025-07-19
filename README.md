# Mina Nginx

[Mina](https://github.com/nadarei/mina) tasks for handle with
[Nginx](http://nginx.com/).

This gem provides several mina tasks:

    mina nginx:install  # Install template config to host repo for easy overrides
    mina nginx:setup    # Install config file to the server's shared dir + symlink
    mina nginx:print    # Parse & print the nginx config

    mina nginx:reload   # Reload Nginx
    mina nginx:restart  # Restart Nginx
    mina nginx:start    # Start Nginx
    mina nginx:status   # Status Nginx
    mina nginx:stop     # Stop Nginx
    
    mina nginx:certbot  # Obtain/renew SSL certificate using Certbot

## Installation

Add this line to your application's Gemfile, then `bundle install`:

    gem 'mina-nginx', :require => false

Once installed, add this to your `config/deploy.rb` file:

    require 'mina/nginx'

Install the base template to your repo's `lib/mina/templates` directory:

    $ bundle exec mina nginx:install

Consider variables used by the nginx config, particularly:

* `application_name`   - application name; defaults to 'application'
* `nginx_socket_path` - path to socket file used in nginx upstream directive
* `server_name`       - application's nginx server_name (e.g. example.com); defaults to value for `domain`
* `domain`            - fqdn you are deploying to
* `deploy_to`         - deployment path
* `current_path`      - current revision path

For SSL certificate management with Certbot:

* `certbot_email`      - email for Let's Encrypt notifications (optional if certbot is already configured)
* `certbot_domains`    - domains to obtain certificate for; defaults to `nginx_server_name` (comma-separated)
* `certbot_extra_flags` - additional certbot flags (e.g., `--dry-run --staging` for testing)

Edit installed template as required.

## Recommended Usage

1. Follow install steps above; and
2. Invoke `nginx:setup` in your main `setup` task
3. Run `nginx:setup` (or base `setup`) to install config changes

n.b. if the config template has not been installed locally, `mina-nginx` will
fall back to the default template gracefully.

### SSL Certificate Setup with Certbot

To obtain an SSL certificate using Let's Encrypt:

1. Ensure certbot is installed with the nginx plugin:
   ```bash
   sudo apt-get install certbot python3-certbot-nginx  # Debian/Ubuntu
   ```

2. Configure your `deploy.rb`:
   ```ruby
   set :nginx_server_name, 'example.com www.example.com'
   set :certbot_email, 'admin@example.com'  # Optional if certbot is already configured
   ```

3. Run the certbot task:
   ```bash
   $ bundle exec mina nginx:certbot
   ```

Certbot will automatically:
- Obtain the SSL certificate
- Update your nginx configuration
- Reload nginx

For testing, use the staging environment:
```ruby
set :certbot_extra_flags, '--dry-run --staging'
```

Note: The nginx plugin for certbot automatically handles all nginx configuration updates and service reloads.

## Contributing

1. Fork it ( http://github.com/hbin/mina-nginx/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
