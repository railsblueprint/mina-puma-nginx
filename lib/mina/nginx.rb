require 'mina/nginx/version'
require "erb"

namespace :nginx do
  set :nginx_path,        '/etc/nginx'
  set :nginx_socket_path, -> { "#{fetch(:shared_path)}/tmp/sockets/puma.sock" }
  set :nginx_socket_flags, "fail_timeout=0"
  set :nginx_config_unit, -> { "#{fetch(:application_name)}_#{fetch(:stage, fetch(:rails_env))}" }
  set :nginx_config_name, -> { "#{fetch(:nginx_config_unit)}.conf" }

  set :nginx_sites_available_path, -> { "#{fetch(:nginx_path)}/sites-available" }
  set :nginx_sites_enabled_path,   -> { "#{fetch(:nginx_path)}/sites-enabled" }


  set :nginx_config,      -> { "#{fetch(:nginx_sites_available_path)}/#{fetch(:nginx_config_name)}" }
  set :nginx_config_e,    -> { "#{fetch(:nginx_sites_enabled_path)}/#{fetch(:nginx_config_name)}" }
  set :nginx_use_ssl,             true
  set :nginx_use_http2,           true
  set :nginx_sts,                 true
  set :nginx_ssl_stapling,        true
  set :nginx_ssl_certificate,     nil
  set :nginx_ssl_certificate_key, nil
  set :nginx_ssl_dhparam,         nil



  desc 'Install Nginx config to repo'
  task :install do
    run :local do
      installed_path = path_for_template

      if File.exist? installed_path
        error! %(file exists; please rm to continue: #{installed_path})
      else
        command %(mkdir -p config/deploy/templates)
        command %(cp #{nginx_template} #{installed_path})
      end
    end
  end

  desc 'Print nginx config in local terminal'
  task :print do
    puts processed_nginx_template
  end

  desc 'Setup Nginx on server'
  task :setup do
    nginx_config = fetch(:nginx_config)
    nginx_enabled_config = fetch(:nginx_config_e)

    comment %(Installing nginx config file to #{nginx_config})
    command %(echo -ne '#{escaped_nginx_template}' | sudo tee #{nginx_config})

    comment %(Symlinking nginx config file to #{nginx_enabled_config})
    command %(sudo ln -nfs #{nginx_config} #{nginx_enabled_config})

    invoke :'nginx:restart'
  end

  %w(stop start restart reload status).each do |action|
    desc "#{action.capitalize} Nginx"
    task action.to_sym do
      comment %(#{action.capitalize} Nginx)
      command "sudo service nginx #{action}"
    end
  end

  private

  def nginx_template
    installed_path = path_for_template
    template_path = path_for_template installed: false

    File.exist?(installed_path) ? installed_path : template_path
  end

  def processed_nginx_template
    erb = File.read(nginx_template)
    ERB.new(erb, trim_mode: '-').result(binding)
  end

  def escaped_nginx_template
    processed_nginx_template.gsub("\n","\\n").gsub("'","\\'")
  end

  def path_for_template installed: true
    installed ?
      File.expand_path('./config/deploy/templates/nginx.conf.template') :
      File.expand_path('../templates/nginx.conf.template', __FILE__)
  end
end
