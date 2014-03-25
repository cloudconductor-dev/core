worker_processes 4
pid File.expand_path('tmp/unicorn.pid')
stderr_path File.expand_path('log/unicorn.stderr.log')
stdout_path File.expand_path('log/unicorn.stdout.log')
listen 8080, :tcp_nopush => true

timeout 1200

preload_app true
