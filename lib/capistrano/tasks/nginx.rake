namespace :nginx do
  desc "Install NGINX site from template"
  task :install do
    on roles(:web) do
      require "erb"
      template_path = File.expand_path("../../../lib/capistrano/templates/nginx_site.erb", __dir__)
      template = File.read(template_path)
      result = ERB.new(template).result(binding)
      tmp = "/tmp/#{fetch(:nginx_site_name)}.conf"
      upload! StringIO.new(result), tmp
      execute :sudo, "/usr/local/bin/deploy-nginx-revnous"
    end
  end
end

namespace :deploy do
  after :publishing, "nginx:install"
end
