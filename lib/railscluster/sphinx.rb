Capistrano::Configuration.instance(:must_exist).load do

  after "deploy:update_code",  "sphinx:configure", "sphinx:restart"
  after "deploy:setup", "sphinx:symlink"

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
      run "rake RAILS_ENV=#{rails_env} ts:config"
    end

    desc "Symlink sphinx config" 
    task :symlink, :roles => :app do
      run "ln -nsf ~/web_root/current/config/sphinx.#{rails_env}.conf ~/etc/sphionx.conf"
    end
  end
end
