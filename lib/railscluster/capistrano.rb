require 'railscluster/capistrano/capistrano_extensions'
require 'railscluster/capistrano/changed'

Capistrano::Configuration.instance(:must_exist).load do
  # Set login & account details
  server "ssh.railscluster.nl", :app, :web, :db, :primary => true
  default_run_options[:pty] = false
  set :use_sudo,        false
  set :deploy_to,       defer { "/home/#{account}/web_root" }

  # Setup command env
  set :cluster_service, "cluster_service"
  set :backend,         'thin'
  set :pwd,             Dir.pwd
  set :copy_local_tar,  '/usr/bin/gnutar' if File.exists?('/usr/bin/gnutar')

  # Setup Git
  set :scm,             :git
  set :scm_auth_cache,  false
  set :git_shallow_clone, 1
  set :repository,      defer { "ssh://git@git.nedforce.nl:2222/#{application}.git" }

  # Deploy settings
  set :deploy_via,      :copy
  set :copy_strategy,   :export
  set :copy_exclude,    ['.git', 'test', 'spec', 'features', 'log', 'doc', 'design', 'backup']
  set :build_script,    "ln -nsf #{File.join(pwd, 'config', 'database.yml')} config/database.yml && bundle exec rake assets:precompile && rm config/database.yml"
  set :keep_releases,   3

  # Setup shared dirs
  set :upload_dirs,     %w(public/uploads private/uploads)
  set :shared_children, fetch(:upload_dirs) + %w(tmp/pids config/database.yml)

  before "deploy:restart" do 
    deploy.migrate if changed? ['db/schema.rb', 'db/migrate']
  end

  after "deploy:restart", "deploy:cleanup"
  after "deploy:setup",   "configure:database", "configure:ssh_config"

  require 'railscluster/capistrano/bundler'  if File.exists?('Gemfile')
  require 'railscluster/capistrano/sphinx'   if File.exists?('config/sphinx.yml')
  require 'railscluster/capistrano/whenever' if File.exists?('config/schedule.rb')
  require 'railscluster/capistrano/console'
  require 'railscluster/capistrano/backup'

  namespace :deploy do
    task :start, :roles => :app do
      run "#{cluster_service} #{backend} start"
    end

    task :stop, :roles => :app do
      run "#{cluster_service} #{backend} stop"
    end

    task :restart, :roles => :app do
     run "touch #{current_path}/tmp/restart.txt"
    end

    task :force_restart, :roles => :app do
     run "#{cluster_service} #{backend} restart"
    end

    task :setup, :except => { :no_release => true } do
      dirs = [deploy_to, releases_path, shared_path, '~/etc', '~/tmp']
      dirs += shared_children.map do |d| 
        d = d.split("/")[0..-2].join("/") if d =~ /\.yml|\.rb|\.conf/
        File.join(shared_path, d)
      end
      run "#{try_sudo} mkdir -p #{dirs.join(' ')}"
      run "#{try_sudo} chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
    end

    task :finalize_update, :except => { :no_release => true } do
      escaped_release = latest_release.to_s.shellescape
      commands = []
      commands << "chmod -R -- g+w #{escaped_release}" if fetch(:group_writable, true)

      # mkdir -p is making sure that the directories are there for some SCM's that don't
      # save empty folders
      shared_children.map do |dir|
        d = dir.shellescape
        if (dir.rindex('/')) then
          commands += ["rm -rf -- #{escaped_release}/#{d}",
                       "mkdir -p -- #{escaped_release}/#{dir.slice(0..(dir.rindex('/'))).shellescape}"]
        else
          commands << "rm -rf -- #{escaped_release}/#{d}"
        end
        commands << "ln -s -- #{shared_path}/#{dir} #{escaped_release}/#{d}"
      end

      run commands.join(' && ') if commands.any?

      if fetch(:normalize_asset_timestamps, false)
        stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
        asset_paths = fetch(:public_children, %w(images stylesheets javascripts)).map { |p| "#{escaped_release}/public/#{p}" }
        run("find #{asset_paths.join(" ")} -exec touch -t #{stamp} -- {} ';'; true",
            :env => { "TZ" => "UTC" }) if asset_paths.any?
      end
    end
  end

  namespace :configure do
    task :database do
      set(:dbpassword) { Capistrano::CLI.ui.ask("Database password: ") }
      if !dbpassword.empty?
        database_yml = <<-EOF
  #{rails_env}:
    adapter: postgresql
    host: postgresql
    username: #{account}
    password: #{dbpassword}
    database: #{account}
  EOF
        put database_yml, "#{deploy_to}/#{shared_dir}/config/database.yml"
      end
    end

    task :ssh_config do
      run "mkdir -p #{deploy_to}/../.ssh && chmod 700 #{deploy_to}/../.ssh"
      ssh_config = <<-EOF
Host *.nedforce.nl *.railscluster.nl
  Port 2222
EOF
      put ssh_config, "#{deploy_to}/../.ssh/config"
    end
  end
end