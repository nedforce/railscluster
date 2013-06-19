Capistrano::Configuration.instance(:must_exist).load do

  after "deploy:update_code" do
    sphinx.configure
    sphinx.restart
  end

  after "deploy:setup" do
    run "mkdir -p #{shared_path}/index"
  end

  namespace :sphinx do
    desc "Start the sphinx daemon" 
    task :start, :roles => :app do
      run "cluster_service sphinx start" 
    end

    desc "Restart the sphinx daemon" 
    task :restart, :roles => :app do
      run "cluster_service sphinx restart" 
    end

    desc "Stop the sphinx daemon" 
    task :stop, :roles => :app do
      run "cluster_service sphinx stop" 
    end

    desc "Reindex sphinx" 
    task :reindex, :roles => :app do
      run "cluster_service sphinx reindex" 
    end

    desc "Rebuild sphinx config" 
    task :configure, :roles => :app do
      run "cd #{current_path} && #{rake} RAILS_ENV=#{rails_env} ts:configure && mv #{current_path}/config/#{rails_env}.sphinx.conf #{shared_path}/config"
    end
  end
end
