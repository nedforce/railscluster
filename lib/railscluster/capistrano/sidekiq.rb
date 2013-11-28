Capistrano::Configuration.instance(:must_exist).load do

  after 'deploy:restart', 'sidekiq:restart'

  namespace :sidekiq do
    desc "Start the sidekiq daemon" 
    task :start, :roles => :app do
      run "cluster_service sidekiq start" 
    end

    desc "Restart the sidekiq daemon" 
    task :restart, :roles => :app do
      run "cluster_service sidekiq restart" 
    end

    desc "Stop the sidekiq daemon" 
    task :stop, :roles => :app do
      run "cluster_service sidekiq stop" 
    end
  end
end
