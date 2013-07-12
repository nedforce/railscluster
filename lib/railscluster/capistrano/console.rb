Capistrano::Configuration.instance(:must_exist).load do

  def run_interactively(cmd, server=nil)
    server ||= find_servers_for_task(current_task).first
    cmd   = "cd #{current_path} && #{bundle_cmd} exec #{cmd}"
    user  = fetch(:account)
    cmd   = "sudo su - #{account} -c \"#{cmd}\" " 
    exec  "ssh #{server.host} -t '#{cmd}'"
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
      server ||= find_servers_for_task(current_task).first
      user  = fetch(:account)
      cmd   = "sudo su - #{account}" 
      exec  "ssh #{server.host} -t '#{cmd}'"
    end
  end
end