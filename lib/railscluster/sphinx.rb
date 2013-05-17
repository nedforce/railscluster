Capistrano::Configuration.instance(:must_exist).load do

  set :shared_children, fetch(:shared_children) + %w(config/#{rails_env}.sphinx.conf)

  after "deploy:update_code" do
    if changed? ['db/schema.rb', 'db/migrate', 'config/sphinx.yml']
      sphinx.configure
      sphinx.restart
    end
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
      run "cd #{latest_release} #{rake} RAILS_ENV=#{rails_env} ts:config && mv #{latest_release}/config/#{rails_env}.sphinx.conf #{shared_path}/config"
    end
  end
end
