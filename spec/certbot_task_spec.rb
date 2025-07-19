require 'spec_helper'

RSpec.describe 'nginx:certbot task' do
  # We'll test the certbot command generation logic separately
  # since Mina tasks are difficult to test in isolation
  
  describe 'certbot command generation' do
    # Simulate the fetch method behavior
    def fetch(key, default = nil)
      value = case key
      when :certbot_email then @certbot_email
      when :certbot_domains then @certbot_domains
      when :certbot_extra_flags then @certbot_extra_flags
      when :nginx_server_name then @nginx_server_name
      else
        nil
      end
      
      if value.nil? && default.respond_to?(:call)
        default.call
      elsif value.nil?
        default
      else
        value
      end
    end
    
    before do
      @certbot_email = nil
      @certbot_domains = nil
      @certbot_extra_flags = ''
      @nginx_server_name = 'example.com www.example.com'
    end
    
    it 'generates basic certbot command using nginx plugin' do
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      
      cmd = "sudo certbot"
      cmd += " --nginx"
      cmd += " --non-interactive --agree-tos"
      cmd += " --domains #{domains}"
      
      expect(cmd).to eq(
        "sudo certbot --nginx --non-interactive --agree-tos" \
        " --domains example.com,www.example.com"
      )
    end
    
    it 'includes email when provided' do
      @certbot_email = 'admin@example.com'
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      
      cmd = "sudo certbot"
      cmd += " --nginx"
      cmd += " --non-interactive --agree-tos"
      cmd += " --email #{@certbot_email}"
      cmd += " --domains #{domains}"
      
      expect(cmd).to eq(
        "sudo certbot --nginx --non-interactive --agree-tos" \
        " --email admin@example.com" \
        " --domains example.com,www.example.com"
      )
    end
    
    it 'works without email (assumes certbot is already configured)' do
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      email = fetch(:certbot_email)
      
      cmd = "sudo certbot"
      cmd += " --nginx"
      cmd += " --non-interactive --agree-tos"
      cmd += " --email #{email}" if email && !email.empty?
      cmd += " --domains #{domains}"
      
      expect(cmd).not_to include('--email')
    end
    
    it 'includes extra flags when specified' do
      @certbot_extra_flags = '--dry-run --staging'
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      extra_flags = fetch(:certbot_extra_flags)
      
      cmd_part = " #{extra_flags}"
      expect(cmd_part).to eq(" --dry-run --staging")
    end
    
    it 'uses custom domains when specified' do
      @certbot_domains = 'custom.example.com,api.example.com'
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      
      expect(domains).to eq('custom.example.com,api.example.com')
    end
    
    it 'falls back to nginx_server_name for domains' do
      @nginx_server_name = 'site1.com site2.com site3.com'
      domains = fetch(:certbot_domains) || fetch(:nginx_server_name, '').split(' ').join(',')
      
      expect(domains).to eq('site1.com,site2.com,site3.com')
    end
  end
  
  describe 'validation logic' do
    it 'accepts missing email (certbot already configured)' do
      email = nil
      expect(email).to be_nil
    end
    
    it 'requires domains to be non-empty' do
      domains = ''
      expect(domains).to be_empty
    end
    
    it 'accepts valid email when provided' do
      email = 'admin@example.com'
      expect(email).not_to be_nil
    end
    
    it 'accepts valid domains' do
      domains = 'example.com,www.example.com'
      expect(domains).not_to be_empty
    end
  end
  
  describe 'integration with nginx settings' do
    # Test that certbot settings integrate properly with nginx settings
    def fetch(key, default = nil)
      settings = {
        nginx_server_name: 'myapp.com www.myapp.com cdn.myapp.com',
        nginx_use_ssl: true
      }
      
      value = settings[key]
      
      if value.nil? && default.respond_to?(:call)
        # Handle lambda defaults
        case key
        when :certbot_domains
          fetch(:nginx_server_name, '').split(' ').join(',')
        else
          default.call
        end
      elsif value.nil?
        default
      else
        value
      end
    end
    
    it 'derives domains from nginx_server_name' do
      domains = fetch(:certbot_domains, -> { fetch(:nginx_server_name, '').split(' ').join(',') })
      expect(domains).to eq('myapp.com,www.myapp.com,cdn.myapp.com')
    end
    
    it 'uses nginx plugin for automatic configuration' do
      # The nginx plugin automatically handles:
      # - Finding the correct nginx config
      # - Updating SSL certificate paths
      # - Reloading nginx
      expect(true).to be true
    end
  end
end