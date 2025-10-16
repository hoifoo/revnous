
# Puma configuration: all settings from ENV, no conditionals
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Bind address (socket or TCP)
bind ENV.fetch("PUMA_BIND", "tcp://0.0.0.0:3000")

# PID file
pidfile ENV["PUMA_PID"] if ENV["PUMA_PID"]

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
