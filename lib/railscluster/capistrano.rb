Capistrano::Configuration::Actions::FileTransfer.class_eval do
  require 'digest/md5'

  def transfer(direction, from, to, options={}, &block)
    if dry_run
      return logger.debug "transfering: #{[direction, from, to] * ', '}"
    end
    if direction == :up
      original_to = to
      to = "/tmp/#{Digest::MD5.hexdigest(to)}"
    elsif direction == :down
      original_from = from
      from = "/tmp/#{Digest::MD5.hexdigest(from)}"
    end
    execute_on_servers(options) do |servers|
      targets = servers.map { |s| sessions[s] }
        Capistrano::Transfer.process(direction, from, to, targets, options.merge(:logger => logger), &block)
    end
    if direction == :up
      run "sudo chown #{fetch(:account)}: #{to}"
      run "sudo mv #{to} #{original_to}"
    elsif direction == :down
      run "sudo chown #{fetch(:account)}: #{from}"
      run "sudo mv #{from} #{original_from}"
    end
  end
end

Capistrano::Configuration::Actions::Invocation.class_eval do
  def run(cmd, options={}, &block)
    unless cmd.include? "sudo"
      user = fetch(:account)
      # Use Sudo command like: sudo -i -u user -- 'cmd'
      sudo_command = [fetch(:sudo, "sudo"), '-u', user ].compact.join(" ")
      cmd = "#{sudo_command} bash -lc '#{cmd}' " 
      # Wrap command to access ssh agent
      cmd = "setfacl -m #{user}:x $(dirname \"$SSH_AUTH_SOCK\") && setfacl -m #{user}:rwx \"$SSH_AUTH_SOCK\" && #{cmd} && setfacl -b $(dirname \"$SSH_AUTH_SOCK\") && setfacl -b \"$SSH_AUTH_SOCK\""
    end

    if options[:eof].nil? && !cmd.include?(sudo)
      options = options.merge(:eof => !block_given?)
    end
    block ||= self.class.default_io_proc
    tree = Capistrano::Command::Tree.new(self) { |t| t.else(cmd, &block) }
    run_tree(tree, options)
  end
end

Capistrano::Configuration.instance(:must_exist).load do
  # Load dependencies
  require 'bundler/capistrano'
  load 'deploy/assets'

  # Set login & account details
  server "ssh.railscluster.nl", :app, :web, :db, :primary => true
  default_run_options[:pty] = false
  set :use_sudo,        false
  set :deploy_to,       defer { "/home/#{account}/web_root" }

  # Setup command env
  set :bundle_cmd,       "bundle"
  set :whenever_command,      "#{bundle_cmd} exec whenever"
  set :whenever_environment,  defer { rails_env }
  set :rake,            "#{bundle_cmd} exec rake"
  set :cluster_service, "cluster_service"
  set :backend,         'thin'

  # Setup Git
  set :scm,             :git
  set :scm_auth_cache,  false
  set :repository,      defer { "ssh://git@git.nedforce.nl:2222/#{application}.git" }

  # Deploy settings
  set :deploy_via,      :copy
  set :copy_strategy,   :export
  set :copy_exclude,    [".git", "test", "spec", "log", "design", "doc"]
  set :keep_releases,   3

  # Setup shared dirs
  set :upload_dirs,     %w(public/uploads private/uploads)
  set :shared_children, fetch(:upload_dirs) + %w(tmp/pids config/database.yml)
  # set :shared_config,   %w(config/database.yml)

  after "deploy:update_code", "deploy:migrate"
  after "deploy:restart", "deploy:cleanup"
  after "deploy:setup", "configure:database", "configure:ssh_config"

  task :test_ssh do
    run "whoami && whoami && echo $PATH && echo $SSH_AUTH_SOCK"
  end

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

    namespace :assets do
      desc 'Run the precompile task locally and sync with shared'
      task :precompile, :roles => :web, :except => { :no_release => true } do
        run_locally "bundle exec rake assets:precompile"
        run_locally "cd public; tar -zcvf assets.tar.gz assets"
        top.upload "public/assets.tar.gz", "#{shared_path}/assets.tar.gz", :via => :scp
        run "cd #{shared_path} && tar --no-same-permissions -zxvf assets.tar.gz"
        run_locally "rm public/assets.tar.gz"
        run_locally "rm -rf public/assets"    
      end
    end 

     task :setup, :except => { :no_release => true } do
      dirs = [deploy_to, releases_path, shared_path]
      dirs += shared_children.map do |d| 
        d = d.split("/")[0..-2].join("/") if d =~ /\.yml|\.rb/
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

      if fetch(:normalize_asset_timestamps, true)
        stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
        asset_paths = fetch(:public_children, %w(images stylesheets javascripts)).map { |p| "#{escaped_release}/public/#{p}" }
        run("find #{asset_paths.join(" ")} -exec touch -t #{stamp} -- {} ';'; true",
            :env => { "TZ" => "UTC" }) if asset_paths.any?
      end
    end
  end

  namespace :bundle do
    # Only execute clean if you know that a rollback will not be necessary.
    desc "Clean the current Bundler environment"
    task :clean do
      run "cd #{latest_release}; RAILS_ENV=#{rails_env} #{bundle_cmd} clean"
    end
  end

  namespace :configure do
    task :database do
      set(:dbpassword) { Capistrano::CLI.ui.ask("Database password: ") }
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