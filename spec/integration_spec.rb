require 'spec_helper'
require 'erb'

RSpec.describe 'Nginx template integration' do
  let(:template_path) { File.expand_path('../../lib/mina/templates/nginx.conf.template', __FILE__) }
  let(:template_content) { File.read(template_path) }
  let(:erb_template) { ERB.new(template_content, trim_mode: '-') }
  
  # Simulate a real Mina deployment context
  class MinaContext
    attr_reader :settings
    
    def initialize(settings = {})
      @settings = {
        nginx_config_unit: 'myapp_production',
        nginx_socket_path: '/var/www/myapp/shared/tmp/sockets/puma.sock',
        nginx_socket_flags: 'fail_timeout=0',
        nginx_use_ssl: true,
        nginx_use_http2: true,
        nginx_server_name: 'www.example.com example.com',
        current_path: '/var/www/myapp/current',
        nginx_downstream_uses_ssl: false,
        nginx_sts: true,
        nginx_ssl_stapling: true,
        nginx_ssl_certificate: '/etc/letsencrypt/live/example.com/fullchain.pem',
        nginx_ssl_certificate_key: '/etc/letsencrypt/live/example.com/privkey.pem',
        nginx_ssl_dhparam: '/etc/ssl/certs/dhparam.pem',
        application_name: 'myapp',
        stage: 'production'
      }.merge(settings)
    end
    
    def fetch(key, default = nil)
      @settings.fetch(key, default)
    end
    
    def render_template(template_content)
      ERB.new(template_content, trim_mode: '-').result(binding)
    end
  end
  
  describe 'production deployment with SSL' do
    let(:context) { MinaContext.new }
    let(:rendered) { context.render_template(template_content) }
    
    it 'generates valid nginx configuration' do
      expect(rendered).to include('upstream puma_myapp_production')
      expect(rendered).to include('listen 443 ssl http2;')
      expect(rendered).to include('ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;')
      expect(rendered).to include('location = /robots.txt')
      expect(rendered).to include('if (-f $document_root/robots-production.txt)')
    end
    
    it 'includes HTTP to HTTPS redirect' do
      expect(rendered).to include('listen 80;')
      expect(rendered).to include('return 301 https://$host$1$request_uri;')
    end
  end
  
  describe 'staging deployment without SSL' do
    let(:context) { MinaContext.new(nginx_use_ssl: false, stage: 'staging', nginx_config_unit: 'myapp_staging') }
    let(:rendered) { context.render_template(template_content) }
    
    it 'generates valid nginx configuration for staging' do
      expect(rendered).to include('upstream puma_myapp_staging')
      expect(rendered).to include('listen 80;')
      expect(rendered).not_to include('listen 443')
      expect(rendered).to include('location = /robots.txt')
      expect(rendered).to include('if (-f $document_root/robots-staging.txt)')
      expect(rendered).to include('rewrite ^(.*)$ /robots-staging.txt break;')
    end
  end
  
  describe 'custom environment deployment' do
    let(:context) { MinaContext.new(stage: 'qa', nginx_config_unit: 'myapp_qa', nginx_use_ssl: false) }
    let(:rendered) { context.render_template(template_content) }
    
    it 'uses custom environment for robots.txt' do
      expect(rendered).to include('if (-f $document_root/robots-qa.txt)')
      expect(rendered).to include('rewrite ^(.*)$ /robots-qa.txt break;')
    end
  end
  
  describe 'nginx configuration validation' do
    let(:context) { MinaContext.new }
    let(:rendered) { context.render_template(template_content) }
    
    it 'has balanced braces' do
      open_braces = rendered.count('{')
      close_braces = rendered.count('}')
      expect(open_braces).to eq(close_braces)
    end
    
    it 'has proper location blocks' do
      location_blocks = rendered.scan(/location\s+[@=~^]*\s*[^\s]+\s*\{/)
      expect(location_blocks).to include('location @puma_myapp_production {')
      expect(location_blocks).to include('location ^~ /assets/ {')
      expect(location_blocks).to include('location @503 {')
      expect(location_blocks).to include('location = /robots.txt {')
    end
    
    it 'has all required directives end with semicolons' do
      # Check common directives that must end with semicolons
      expect(rendered).to match(/server_name\s+[^;]+;/)
      expect(rendered).to match(/root\s+[^;]+;/)
      expect(rendered).to match(/client_max_body_size\s+[^;]+;/)
      expect(rendered).to match(/keepalive_timeout\s+[^;]+;/)
    end
  end
end