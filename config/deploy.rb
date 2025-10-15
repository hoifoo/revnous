# frozen_string_literal: true

set :application, "revnous"
set :repo_url, "git@github.com:hoifoo/revnous.git"

# Default deploy_to directory
set :deploy_to, "/var/www/revnous"

 # rbenv configuration
 set :rbenv_type, :user
 set :rbenv_ruby, "3.4.2"
 # rbenv binary is installed system-wide at /usr/bin/rbenv, but versions live under $HOME/.rbenv
 set :rbenv_path, "$HOME/.rbenv"        # for version directory validation
 set :rbenv_prefix, "/usr/bin/rbenv exec" # for executing commands via the correct binary

# Keep release history
set :keep_releases, 5

# Linked files and directories
append :linked_files, "config/application.yml", "config/master.key"
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "storage"

# Yarn
set :yarn_flags, %w[--silent --no-progress]
set :yarn_roles, :web

# Puma settings (capistrano3-puma)
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_workers,    (ENV["WEB_CONCURRENCY"] || 1).to_i
set :puma_threads,    [ 3, 3 ]
set :puma_env,        fetch(:rails_env, :production)
set :puma_access_log, "#{shared_path}/log/puma.access.log"
set :puma_error_log,  "#{shared_path}/log/puma.error.log"
set :puma_init_active_record, true
# Use user-level systemd for Puma (matches current working state)
set :puma_systemctl_user, true

# NGINX configuration (override in stage if needed)
set :nginx_site_name, "revnous"
set :nginx_server_name, [ "www.revnous.com", "revnous.com" ] # replace with your domain when ready

namespace :deploy do
  desc "Restart application"
  task :restart do
    invoke "puma:smart_restart"
    invoke "solid_queue:restart"
  end

  after :publishing, :restart
end
