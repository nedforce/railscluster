require 'railscluster/capistrano/changed'

Capistrano::Configuration.instance(:must_exist).load do
  require 'railscluster/capistrano/capistrano_extensions'
  require 'railscluster/capistrano/bundler'   if File.exists?('Gemfile')
  require 'railscluster/capistrano/sphinx'    if File.exists?('config/sphinx.yml') || File.exists?('config/thinking_sphinx.yml')
  require 'railscluster/capistrano/sidekiq'   if File.exists?('config/sidekiq.yml') || !`cat Gemfile | grep "gem 'sidekiq'"`.empty?
  require 'railscluster/capistrano/whenever'  if File.exists?('config/schedule.rb')
  require 'railscluster/capistrano/console'
  require 'railscluster/capistrano/backup'
  require 'railscluster/capistrano/git'       if fetch(:scm, :git).to_s == 'git'
  require 'airbrake/capistrano'               if fetch(:airbrake_enabled, false)
  load 'deploy/assets'                        if File.exists?('app/assets') && !fetch(:local_precompile, false)
  
  # Set login & account details
  server "ssh.railscluster.nl:2222", :app, :web, :db, :primary => true
  set :ssh_options, { :forward_agent => true }
  default_run_options[:pty] = false
  
  set :use_sudo,        false
  set :deploy_to,       defer { "/home/#{fetch(:account)}/web_root" }
  set :account,         fetch(:account, defer { Capistrano::CLI.ui.ask("Deploy to account: ") })
  set :rails_env,       defer { get_rails_env }
  set :user,            defer { fetch(:account) }
  set :application,     defer { fetch(:account) }

  # Setup command env
  set :cluster_service, "cluster_service"
  set :backend,         defer { get_backend }
  set :pwd,             Dir.pwd
  set :copy_local_tar,  '/usr/bin/gnutar' if File.exists?('/usr/bin/gnutar')

  # Setup Git
  set :scm,             fetch(:scm, :git)
  set :scm_auth_cache,  false
  set :git_shallow_clone, 1
  set :repository,      fetch(:repository, defer { Capistrano::CLI.ui.ask("Repository: ") })

  # Deploy settings
  set :deploy_via,      :copy
  set :copy_strategy,   :export
  set :copy_exclude,    ['.git', 'test', 'spec', 'features', 'log', 'doc', 'design', 'backup']
  set :keep_releases,   3

  # Local precompile (Optional)
  set :build_script,    defer { "ln -nsf #{File.join(pwd, 'config', 'database.yml')} config/database.yml && RAILS_ENV=#{rails_env} #{rake} assets:precompile && rm config/database.yml" } if File.exists?('app/assets') && fetch(:local_precompile, false)

  # Setup shared dirs
  set :upload_dirs,     %w(public/uploads private/uploads)
  set :shared_children, defer { fetch(:upload_dirs) + %w(tmp/pids config/database.yml) + fetch(:app_shared_children, []) }

  after 'deploy:update_code' do 
    deploy.migrate if changed? ['db/schema.rb', 'db/migrate']
  end

  after "deploy:restart", "deploy:cleanup"
  after "deploy:setup",   "configure:database"

  namespace :deploy do
    task :start, :roles => :app do
      run "#{cluster_service} #{backend} start"
    end

    task :stop, :roles => :app do
      run "#{cluster_service} #{backend} stop"
    end

    task :restart, :roles => :app do
      if fetch(:hard_restart, true)
        run "#{cluster_service} #{backend} restart"
      else
        onebyone
      end
    end

    task :onebyone, :roles => :app do
     run "touch #{current_path}/tmp/restart.txt"
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
      shared_children.map do |child|
        c = child.shellescape 
        commands << "rm -rf -- #{escaped_release}/#{c}"
        if child =~ /\//
          commands << "mkdir -p -- #{escaped_release}/#{child.slice(0..(child.rindex('/'))).shellescape}"
        end
        commands << "if [ -e #{shared_path}/#{child} ]; then ln -s -- #{shared_path}/#{child} #{escaped_release}/#{c}; fi"
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
    adapter: #{fetch(:dbtype, 'postgresql')}
    host: #{fetch(:dbtype, 'postgresql')}
    username: #{fetch(:dbuser, account)}
    password: #{dbpassword}
    database: #{fetch(:dbname, account)}
  EOF
        put database_yml, "#{deploy_to}/#{shared_dir}/config/database.yml"
      end
    end
  end
end