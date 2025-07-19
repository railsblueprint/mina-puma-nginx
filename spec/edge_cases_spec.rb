require 'spec_helper'
require 'erb'

RSpec.describe 'Nginx template edge cases' do
  let(:template_path) { File.expand_path('../../lib/mina/templates/nginx.conf.template', __FILE__) }
  let(:template_content) { File.read(template_path) }
  let(:erb_template) { ERB.new(template_content, trim_mode: '-') }
  
  # Mock Mina's fetch method with minimal settings
  def fetch(key, default = nil)
    value = case key
    when :nginx_config_unit then nginx_config_unit
    when :nginx_socket_path then '/tmp/puma.sock'
    when :nginx_socket_flags then 'fail_timeout=0'
    when :nginx_use_ssl then false
    when :nginx_use_http2 then false
    when :nginx_server_name then 'localhost'
    when :current_path then '/app/current'
    when :nginx_downstream_uses_ssl then false
    when :nginx_sts then false
    when :nginx_ssl_stapling then false
    when :nginx_ssl_certificate then nil
    when :nginx_ssl_certificate_key then nil
    when :nginx_ssl_dhparam then nil
    when :stage then stage_value
    when :rails_env then rails_env_value
    when :application_name then 'app'
    else
      nil
    end
    
    value.nil? ? default : value
  end
  
  let(:nginx_config_unit) { 'app_test' }
  let(:stage_value) { nil }
  let(:rails_env_value) { nil }
  let(:rendered_template) { erb_template.result(binding) }
  
  describe 'robots.txt with special characters in environment names' do
    context 'with hyphenated environment name' do
      let(:stage_value) { 'pre-production' }
      
      it 'handles hyphenated environment names correctly' do
        expect(rendered_template).to include('if (-f $document_root/robots-pre-production.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-pre-production.txt break;')
      end
    end
    
    context 'with underscored environment name' do
      let(:stage_value) { 'staging_v2' }
      
      it 'handles underscored environment names correctly' do
        expect(rendered_template).to include('if (-f $document_root/robots-staging_v2.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-staging_v2.txt break;')
      end
    end
    
    context 'with numeric environment name' do
      let(:stage_value) { 'staging2' }
      
      it 'handles numeric environment names correctly' do
        expect(rendered_template).to include('if (-f $document_root/robots-staging2.txt)')
        expect(rendered_template).to include('rewrite ^(.*)$ /robots-staging2.txt break;')
      end
    end
  end
  
  describe 'environment precedence' do
    context 'when both stage and rails_env are set' do
      let(:stage_value) { 'staging' }
      let(:rails_env_value) { 'production' }
      
      it 'prefers stage over rails_env' do
        expect(rendered_template).to include('if (-f $document_root/robots-staging.txt)')
        expect(rendered_template).not_to include('robots-production.txt')
      end
    end
    
    context 'when stage is explicitly nil but rails_env is set' do
      let(:stage_value) { nil }
      let(:rails_env_value) { 'development' }
      
      it 'falls back to rails_env' do
        expect(rendered_template).to include('if (-f $document_root/robots-development.txt)')
      end
    end
    
    context 'when stage is false' do
      let(:stage_value) { false }
      let(:rails_env_value) { 'test' }
      
      it 'treats false as a value and does not fall back' do
        expect(rendered_template).not_to include('location = /robots.txt')
      end
    end
  end
  
  describe 'nginx syntax safety' do
    context 'with various nginx_config_unit values' do
      ['app-name', 'app_name', 'app123', 'my-app_v2'].each do |unit_name|
        context "with nginx_config_unit = '#{unit_name}'" do
          let(:nginx_config_unit) { unit_name }
          let(:stage_value) { 'production' }
          
          it 'generates valid nginx configuration' do
            expect(rendered_template).to include("upstream puma_#{unit_name}")
            expect(rendered_template).to include("location @puma_#{unit_name}")
            expect(rendered_template).to include("proxy_pass http://puma_#{unit_name};")
            expect(rendered_template).to include("/var/log/nginx/#{unit_name}.access.log")
            expect(rendered_template).to include("/var/log/nginx/#{unit_name}.error.log")
          end
        end
      end
    end
  end
  
  describe 'complete nginx configuration structure' do
    let(:stage_value) { 'production' }
    
    it 'maintains proper nginx configuration order' do
      # Check that major sections appear in the correct order
      upstream_pos = rendered_template.index('upstream puma_')
      server_pos = rendered_template.index('server {')
      robots_pos = rendered_template.index('location = /robots.txt')
      
      expect(upstream_pos).to be < server_pos
      expect(server_pos).to be < robots_pos
    end
    
    it 'includes all essential nginx directives' do
      essential_directives = [
        'client_max_body_size',
        'keepalive_timeout',
        'error_page',
        'try_files',
        'proxy_http_version',
        'proxy_set_header X-Forwarded-For',
        'proxy_set_header Host',
        'gzip_static',
        'expires max'
      ]
      
      essential_directives.each do |directive|
        expect(rendered_template).to include(directive)
      end
    end
  end
end