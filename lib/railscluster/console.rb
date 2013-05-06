Capistrano::Configuration.instance(:must_exist).load do

  def run_interactively(cmd, server=nil)

    server ||= find_servers_for_task(current_task).first
    cmd = "cd #{current_path} && #{bundle_cmd} exec #{cmd}"
    user = fetch(:account)
    cmd = "sudo su - #{account} -c \"#{cmd}\" " 
    exec "ssh #{server.host} -t '#{cmd}'"
  end

  namespace :console do
    desc "Rails console"
    task :rails, :roles => :app do
      run_interactively "rails console #{rails_env}"
    end

  # Is only going to work from Rails 4 onwards.
  #  desc "Database console"
  #  task :db, :roles => :app do
  #    run_interactively "rails dbconsole #{rails_env} --include-password"
  #  end
  end
end