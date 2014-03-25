$LOAD_PATH.unshift File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.unshift ENV['RBENV_DIR'] if ENV['RBENV_DIR']

require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

environment = ENV['RAILS_ENV'] || 'development'

namespace :db do
  task :connect do
    require 'bundler/setup'
    Bundler.require
    ActiveRecord::Base.configurations = YAML.load_file('config/database.yml')
    ActiveRecord::Base.establish_connection(environment)
    autoload_paths = ['src/models', 'src/controllers', 'src/helpers']
    autoload_paths.each do |path|
      ActiveSupport::Dependencies.autoload_paths << File.expand_path(path, File.dirname(__FILE__))
    end
  end

  task :migrate => :connect do
  end

  namespace :migrate do
    desc "Show migrate status"
    task :status => :connect do
      class SchemaMigration < ActiveRecord::Base
      end

      ActiveRecord::Base.logger = nil
      puts " Status   Migration ID"
      puts "-------------------------"

      versions = ActiveRecord::Migrator.get_all_versions
      Dir.glob(ActiveRecord::Migrator.migrations_path + "/*.rb") do |path|
        next unless File.basename(path) =~ /^(\d{14})_/

        status = if versions.include? $1.to_i then "up" else "down" end
        puts " %4s    %s" % [status, $1]
      end
      puts
    end
  end
 
  desc "Insert seed data to database"
  task :seed => [:connect, :migrate] do
    load 'db/seeds.rb'
  end

  desc "Rebuild database"
  task :rebuild => :connect do
    Rake::Task['server:stop'].execute
    ActiveRecord::Tasks::DatabaseTasks.root = Pathname.new(Dir.pwd)
    ['db:drop', 'db:migrate', 'db:seed'].each do |task|
      Rake::Task[task].execute
    end
    Rake::Task['server:start'].execute
  end

  desc "Print private key"
  task :printkey => :connect do
    Credential.all.each do |c|
      puts "#{c.id} : #{c.name}"
    end
    print "input id >"
    num = STDIN.gets
    c = Credential.find_by_id(num)
    puts; puts c.private_key; puts
  end
end

desc "Launch console wih database connection"
task :console => ["db:connect"] do
  require 'irb'
  ARGV.clear
  IRB.start
end

desc "Initialize and install required modules"
task :init => ["db:migrate", "db:seed"]

UNICORN_PID = 'tmp/unicorn.pid'
namespace :server do
  desc "Launch web/AP server"
  task :start do
    cd File.expand_path('.', File.dirname(__FILE__)), verbose: false do

      sh "unicorn --daemonize --config config/unicorn.rb"
      pid = nil
      5.times do
        break if pid = File.read(UNICORN_PID) if File.exist?(UNICORN_PID)
        puts "wait for initialize."
        sleep 1
      end

      if pid
        puts "--------- Web/AP Server started(pid: #{pid.chomp}). ---------"
      else
        puts "--------- [Error] Web/AP Server failed to startup. ---------"
      end
    end
  end

  desc "Stop web/AP server"
  task :stop do
    cd File.expand_path('.', File.dirname(__FILE__)), verbose: false do
      unless File.exist?(UNICORN_PID)
        puts "Web/AP Server is not running."
        break
      end

      pid = File.read(UNICORN_PID)
      Process.kill(:SIGINT, pid.to_i)

      success = 5.times do
        break true unless File.exist?(UNICORN_PID)
        puts "wait for terminate."
        sleep 1
      end
      if success == true
        puts "--------- Web/AP Server stopped. ---------"
      else
        puts "--------- [Error] Web/AP Server failed to stop. ---------"
      end
    end
  end

  desc "Restart web/AP server"
  task :restart => ['server:stop', 'server:start']

  desc "Show status of Web/AP Server"
  task :status do
    cd File.expand_path('.', File.dirname(__FILE__)), verbose: false do
      begin
        pid = File.read(UNICORN_PID)
        puts "Web/AP Server is running(pid: #{pid.chomp})."
      rescue
        puts "Web/AP Server is not running."
        exit
      end
    end
  end
end

