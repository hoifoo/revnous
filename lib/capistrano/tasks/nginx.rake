namespace :nginx do
  desc "Install NGINX site from template"
  task :install do
    on roles(:web) do
      within release_path do
        site = capture(:erb, "lib/capistrano/templates/nginx_site.erb")
        tmp = "/tmp/#{fetch(:nginx_site_name)}.conf"
        upload! StringIO.new(site), tmp
        execute :sudo, :mv, tmp, "/etc/nginx/sites-available/#{fetch(:nginx_site_name)}"
      end
    end
  end

  desc "Enable NGINX site"
  task :enable do
    on roles(:web) do
      execute :sudo, :ln, "-sf", "/etc/nginx/sites-available/#{fetch(:nginx_site_name)}", "/etc/nginx/sites-enabled/#{fetch(:nginx_site_name)}"
    end
  end

  desc "Test and reload NGINX"
  task :reload do
    on roles(:web) do
      execute :sudo, :nginx, "-t"
      execute :sudo, :systemctl, :reload, :nginx
    end
  end
end

namespace :deploy do
  after :publishing, "nginx:install"
  after :publishing, "nginx:enable"
  after :publishing, "nginx:reload"
end
