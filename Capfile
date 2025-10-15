# frozen_string_literal: true

# Load DSL and Setup Up Stages
require "capistrano/setup"

# Includes default deployment tasks
require "capistrano/deploy"

# rbenv for managing Ruby
require "capistrano/rbenv"

# Bundler integration
require "capistrano/bundler"

# Rails assets and migrations
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

# Yarn for JS dependencies
require "capistrano/yarn"

# Puma with systemd helpers
require "capistrano/puma"
install_plugin Capistrano::Puma
install_plugin Capistrano::Puma::Systemd

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
