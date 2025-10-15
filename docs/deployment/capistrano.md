# Capistrano Deployment Plan (Rails 8 + Solid Stack)

This document outlines how to add Capistrano-based SSH deployments to this app as an alternative to Kamal. It’s non-invasive and can live side-by-side, but do not run Capistrano and Kamal against the same server at the same time.

## Why Capistrano here
- SSH-based zero-downtime deploys with Puma and systemd
- Database migrations and asset build hooks
- Easy hooks to manage Solid Queue worker(s)

## Prerequisites
- Target OS: Ubuntu 22.04+ (recommended)
- System packages: git, curl, build-essential, libpq-dev, nodejs, yarn, nginx
- Ruby 3.4.2 installed on server (rbenv or asdf recommended)
- A deploy user with SSH access and passwordless sudo for service management
- PostgreSQL reachable from the app server
- Credentials and app config present on server

## High-level design
- Directory layout on server: /var/www/revnous (changeable via deploy_to)
- Puma served via systemd, binding to a Unix socket in shared/tmp/sockets/puma.sock
- NGINX reverse proxy to Puma socket
- Solid Queue run as a separate systemd service via bin/jobs
- Capistrano handles: code updates, bundle install, yarn build, assets:precompile, db:migrate, restart services

## Gems to add (development group)
Add these to Gemfile under group :development do (no runtime impact in production):

- capistrano (~> 3.18)
- capistrano-rails (assets + migrations)
- capistrano-bundler
- capistrano-rbenv (or capistrano-asdf, if you prefer asdf)
- capistrano3-puma (systemd integration for Puma)
- capistrano-yarn (for Node dependencies)

Example snippet:

  group :development do
    gem "capistrano", "~> 3.18", require: false
    gem "capistrano-rails", require: false
    gem "capistrano-bundler", require: false
    gem "capistrano-rbenv", require: false
    gem "capistrano3-puma", require: false
    gem "capistrano-yarn", require: false
  end

Then run on your dev machine:
- bundle install
- bundle exec cap install (generates Capfile and config/deploy/* skeleton)

## Capfile (example)
Require plugins and their tasks:

require "capistrano/setup"
require "capistrano/deploy"
require "capistrano/rbenv"
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"
require "capistrano/yarn"
require "capistrano/puma"
install_plugin Capistrano::Puma  # basic puma tasks
install_plugin Capistrano::Puma::Systemd

## config/deploy.rb (baseline)
Set the core options (tune names/paths as needed):

set :application, "revnous"
set :repo_url, "git@github.com:hoifoo/revnous.git" # adjust if different
set :deploy_to, "/var/www/revnous"

set :rbenv_type, :user
set :rbenv_ruby, "3.4.2"

append :linked_files, "config/master.key", "config/application.yml"
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "storage"

set :keep_releases, 5

# Puma (via capistrano3-puma)
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_workers,    ENV.fetch("WEB_CONCURRENCY", 1)
set :puma_threads,    [3, 3]  # matches puma.rb default for this app
set :puma_env,        fetch(:rails_env, :production)
set :puma_access_log, "#{shared_path}/log/puma.access.log"
set :puma_error_log,  "#{shared_path}/log/puma.error.log"
set :puma_init_active_record, true

# Yarn
set :yarn_flags, %w(--silent --no-progress)
set :yarn_roles, :web

# Hooks to restart services
namespace :deploy do
  after :publishing, :restart do
    invoke "puma:phased_restart"
    invoke "solid_queue:restart"
  end
end

## config/deploy/production.rb (example)
server "your.server.ip.or.name", user: "deploy", roles: %w[app db web], primary: true
set :branch, "main"
set :rails_env, "production"
set :migration_role, :db

## Solid Queue systemd unit
Create a unit on the server, e.g., /etc/systemd/system/solid-queue@revnous.service

[Unit]
Description=Solid Queue for revnous (%i)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/revnous/current
Environment=RAILS_ENV=production
ExecStart=/home/deploy/.rbenv/shims/bundle exec ruby bin/jobs
Restart=always
RestartSec=5
StandardOutput=append:/var/www/revnous/shared/log/solid_queue.log
StandardError=append:/var/www/revnous/shared/log/solid_queue.error.log

[Install]
WantedBy=multi-user.target

Cap tasks to control it (lib/capistrano/tasks/solid_queue.rake):

desc "Restart Solid Queue"
namespace :solid_queue do
  task :restart do
    on roles(:app) do
      execute :sudo, :systemctl, "restart", "solid-queue@revnous"
    end
  end
  task :start do
    on roles(:app) do
      execute :sudo, :systemctl, "start", "solid-queue@revnous"
    end
  end
  task :stop do
    on roles(:app) do
      execute :sudo, :systemctl, "stop", "solid-queue@revnous"
    end
  end
  task :enable do
    on roles(:app) do
      execute :sudo, :systemctl, "enable", "solid-queue@revnous"
    end
  end
end

Hook enable into first deploy or run manually once:
- cap production solid_queue:enable

## NGINX (example)
/etc/nginx/sites-available/revnous

upstream revnous_puma {
  server unix:/var/www/revnous/shared/tmp/sockets/puma.sock fail_timeout=0;
}
server {
  listen 80;
  server_name app.example.com; # change me

  root /var/www/revnous/current/public;

  location / {
    try_files $uri @puma;
  }

  location @puma {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://revnous_puma;
  }

  client_max_body_size 25M;
  keepalive_timeout 10;
}

Then:
- ln -s /etc/nginx/sites-available/revnous /etc/nginx/sites-enabled/revnous
- sudo nginx -t && sudo systemctl reload nginx

## First-time server prep (one-time)
- Create deploy user and SSH keys
- Install rbenv/asdf and Ruby 3.4.2
- Install Node.js and Yarn
- Install PostgreSQL client (libpq-dev) and NGINX
- Create directories: /var/www/revnous/shared/{config,log,tmp/pids,tmp/cache,tmp/sockets}
- Upload shared configs: config/master.key and config/application.yml to shared/config
- Ensure database.yml is configured for production (if not using ENV-only)
- Enable services once: cap production puma:systemd:config puma:systemd:enable and cap production solid_queue:enable

## Deploy flow
- cap production deploy:check      # sanity check
- cap production deploy            # standard deploy
- cap production deploy:rollback   # rollback to previous release

## Notes for this codebase
- Ruby version: 3.4.2 (from .ruby-version); use capistrano-rbenv with rbenv_ruby "3.4.2"
- JS/CSS bundling: jsbundling-rails + cssbundling-rails; ensure Node + Yarn present; capistrano-yarn handles yarn install; assets:precompile triggers bundling
- Solid Queue: either run inside Puma (SOLID_QUEUE_IN_PUMA=true) or separate systemd worker as above; prefer separate worker in multi-core/multi-host setups
- Kamal: already configured. Capistrano is an alternative path. Avoid mixing on same host

## Checklist to implement
1) Add the gems (development group) and bundle install
2) cap install and update Capfile, deploy.rb, production.rb as per examples
3) Add lib/capistrano/tasks/solid_queue.rake with tasks above
4) Prepare server (rbenv/asdf, NGINX, dirs, shared configs)
5) Configure Puma systemd via capistrano3-puma; configure NGINX site
6) cap production deploy
7) Verify health: nginx 200/301, puma running, solid_queue processing jobs, assets served

## Troubleshooting
- Missing libvips for image_processing: sudo apt-get install -y libvips
- Precompile fails: check Node/Yarn, increase RAM or swap
- Permissions: ensure deploy user owns /var/www/revnous and shared dirs
- master.key: ensure it lives in shared/config/master.key and is linked
