# frozen_string_literal: true

server "104.250.128.180", user: "deploy", roles: %w[app db web], primary: true

set :branch, "main"
set :rails_env, "production"
set :migration_role, :db

# If you use a non-default SSH key or port, uncomment and adjust:
# set :ssh_options, {
#   keys: [File.expand_path("~/.ssh/id_rsa")],
#   forward_agent: true,
#   auth_methods: %w(publickey)
# }
