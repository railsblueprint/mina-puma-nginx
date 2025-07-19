require 'spec_helper'
require 'erb'

RSpec.describe 'nginx.conf.template' do
  let(:template_path) { File.expand_path('../../lib/mina/templates/nginx.conf.template', __FILE__) }
  let(:template_content) { File.read(template_path) }
  let(:erb_template) { ERB.new(template_content, trim_mode: '-') }
  
  # Mock Mina's fetch method
  def fetch(key, default = nil)
    value = case key
    when :nginx_config_unit then 'myapp_test'
    when :nginx_socket_path then '/var/www/myapp/shared/tmp/sockets/puma.sock'
    when :nginx_socket_flags then 'fail_timeout=0'
    when :nginx_use_ssl then nginx_use_ssl
    when :nginx_use_http2 then false
    when :nginx_server_name then 'example.com'
    when :current_path then '/var/www/myapp/current'
    when :nginx_downstream_uses_ssl then false
    when :nginx_sts then false
    when :nginx_ssl_stapling then false
    when :nginx_ssl_certificate then nil
    when :nginx_ssl_certificate_key then nil
    when :nginx_ssl_dhparam then nil
    when :stage then stage_value
    when :rails_env then rails_env_value
    when :application_name then 'myapp'
    else
      nil
    end
    
    value.nil? ? default : value
  end

  let(:nginx_use_ssl) { false }
  let(:stage_value) { nil }
  let(:rails_env_value) { nil }
  let(:rendered_template) { erb_template.result(binding) }

  describe 'robots.txt rewrite rule' do
    context 'when stage is set to production' do
      let(:stage_value) { 'production' }
      
      it 'includes robots.txt location block with production environment' do
        expect(rendered_template).to include('location = /robots.txt')
        expect(rendered_template).to include('if (-f $document_root/robots-production.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-production.txt break;')
      end
    end

    context 'when stage is set to staging' do
      let(:stage_value) { 'staging' }
      
      it 'includes robots.txt location block with staging environment' do
        expect(rendered_template).to include('location = /robots.txt')
        expect(rendered_template).to include('if (-f $document_root/robots-staging.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-staging.txt break;')
      end
    end

    context 'when rails_env is set but stage is not' do
      let(:stage_value) { nil }
      let(:rails_env_value) { 'development' }
      
      it 'falls back to rails_env for environment' do
        expect(rendered_template).to include('location = /robots.txt')
        expect(rendered_template).to include('if (-f $document_root/robots-development.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-development.txt break;')
      end
    end

    context 'when neither stage nor rails_env is set' do
      let(:stage_value) { nil }
      let(:rails_env_value) { nil }
      
      it 'uses production as default environment' do
        expect(rendered_template).to include('location = /robots.txt')
        expect(rendered_template).to include('if (-f $document_root/robots-production.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-production.txt break;')
      end
    end

    context 'when environment is empty string' do
      let(:stage_value) { '' }
      
      it 'does not include robots.txt location block' do
        expect(rendered_template).not_to include('location = /robots.txt')
        expect(rendered_template).not_to include('robots-')
      end
    end
  end

  describe 'nginx configuration structure' do
    it 'includes upstream configuration' do
      expect(rendered_template).to include('upstream puma_myapp_test')
      expect(rendered_template).to include('server unix:/var/www/myapp/shared/tmp/sockets/puma.sock fail_timeout=0;')
    end

    it 'includes server block' do
      expect(rendered_template).to include('server {')
      expect(rendered_template).to include('server_name example.com;')
      expect(rendered_template).to include('root /var/www/myapp/current/public;')
    end

    it 'includes maintenance mode handling' do
      expect(rendered_template).to include('location @503')
      expect(rendered_template).to include('if (-f $document_root/system/maintenance.html)')
    end

    context 'with SSL enabled' do
      let(:nginx_use_ssl) { true }
      
      it 'includes SSL configuration' do
        expect(rendered_template).to include('listen 443 ssl;')
        expect(rendered_template).to include('listen 80;')
        expect(rendered_template).to include('return 301 https://$host$1$request_uri;')
      end
    end

    context 'without SSL' do
      let(:nginx_use_ssl) { false }
      
      it 'only listens on port 80' do
        expect(rendered_template).to include('listen 80;')
        expect(rendered_template).not_to include('listen 443')
      end
    end
  end

  describe 'template syntax' do
    it 'produces valid nginx configuration' do
      # Check for balanced braces
      expect(rendered_template.count('{')).to eq(rendered_template.count('}'))
      
      # Check for proper semicolon endings on statements
      expect(rendered_template).to match(/server_name\s+\S+;/)
      expect(rendered_template).to match(/listen\s+\d+;/)
      
      # Check location blocks are properly formatted
      expect(rendered_template).to match(/location\s+[@=~^]?\s*\/[^\s]*\s*\{/)
    end
  end
end