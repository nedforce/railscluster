Capistrano::Configuration.instance(:must_exist).load do

  def run_interactively(cmd, server=nil)
    sudo_cmd = fetch(:sudo_cmd, "sudo su - #{fetch(:account)}")
    cmd = "cd #{current_path} && #{bundle_cmd} exec #{cmd}"
    cmd = "#{sudo_cmd} -c \\\"#{cmd}\\\" "
    exec_command cmd
  end

  def exec_command(cmd, server=nil)
    server ||= find_servers_for_task(current_task).first
    gateway = fetch(:gateway, nil)

    if gateway
      exec %(ssh #{gateway} -t 'ssh #{server.host} -t "#{cmd}"')
    else
      exec %(ssh #{server.host} -t "#{cmd}")
    end
  end

  namespace :console do
    task :default do
      shell
    end

    desc "Rails console"
    task :rails, :roles => :app do
      set(:sandbox_mode) { Capistrano::CLI.ui.ask("Start production console in sandbox mode? y/n: ") } if rails_env == 'production'
      if rails_env == 'production' && sandbox_mode != 'n'
        run_interactively "rails console #{rails_env} --sandbox"
      else
        run_interactively "rails console #{rails_env}"
      end
    end

  # Is only going to work from Rails 4 onwards.
    desc "Database console (Rails 4 Only)"
    task :db, :roles => :app do
      run_interactively "rails dbconsole #{rails_env} --include-password"
    end

    desc "Command line shell"
    task :shell, :roles => :app do
      sudo_cmd = fetch(:sudo_cmd, "sudo su - #{fetch(:account)}")
      exec_command sudo_cmd
    end
  end
end