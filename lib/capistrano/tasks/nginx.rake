namespace :nginx do
  desc "Install NGINX site from template (only if SSL not configured)"
  task :install do
    on roles(:web) do
      require "erb"
      # Check if SSL is already configured (Certbot has run)
      ssl_configured = test("grep -q 'managed by Certbot' /etc/nginx/sites-available/#{fetch(:nginx_site_name)} 2>/dev/null")

      if ssl_configured
        info "SSL already configured by Certbot - skipping NGINX template update"
        info "Manually update /etc/nginx/sites-available/#{fetch(:nginx_site_name)} if needed"
      else
        template_path = File.expand_path("../../../lib/capistrano/templates/nginx_site.erb", __dir__)
        template = File.read(template_path)
        result = ERB.new(template).result(binding)
        tmp = "/tmp/#{fetch(:nginx_site_name)}.conf"
        upload! StringIO.new(result), tmp
        execute :sudo, "/usr/local/bin/deploy-nginx-revnous"
        info "NGINX config installed. Run certbot to enable SSL."
      end
    end
  end
end

namespace :deploy do
  after :publishing, "nginx:install"
end
