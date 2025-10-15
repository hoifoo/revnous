desc "Manage Solid Queue via systemd"
namespace :solid_queue do
  set :solid_queue_unit, ENV.fetch("SOLID_QUEUE_UNIT", "solid-queue@revnous")

  task :restart do
    on roles(:app) do
      # Try user-level systemd first (no sudo)
      begin
        execute :systemctl, "--user", :restart, fetch(:solid_queue_unit)
      rescue SSHKit::Command::Failed
        # Fallback to system-level via sudo
        begin
          execute :sudo, :systemctl, :restart, fetch(:solid_queue_unit)
        rescue SSHKit::Command::Failed
          warn "solid_queue:restart skipped (no permission or unit not found)"
        end
      end
    end
  end

  task :start do
    on roles(:app) do
      execute :sudo, :systemctl, :start, fetch(:solid_queue_unit)
    end
  end

  task :stop do
    on roles(:app) do
      execute :sudo, :systemctl, :stop, fetch(:solid_queue_unit)
    end
  end

  task :enable do
    on roles(:app) do
      execute :sudo, :systemctl, :enable, fetch(:solid_queue_unit)
    end
  end

    desc "Upload .env.systemd file to shared config"
    task :upload_env do
      on roles(:app) do
        upload! "shared/.env.systemd.example", "#{shared_path}/.env.systemd"
      end
    end

    desc "Install Solid Queue systemd unit from template"
    task :install_unit do
      on roles(:app) do
        within release_path do
          unit_file = capture(:erb, "lib/capistrano/templates/solid_queue_systemd.service.erb")
          execute :sudo, :tee, "/etc/systemd/system/solid-queue@revnous.service" do |io|
            io.puts unit_file
          end
        end
        execute :sudo, :systemctl, :daemon_reload
      end
    end
end
