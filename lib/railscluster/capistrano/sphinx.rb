Capistrano::Configuration.instance(:must_exist).load do

  before 'deploy:restart' do
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
      configure_cmd = File.exists?('config/thinking_sphinx.yml') ? 'ts:configure' : 'ts:config'
      run "cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{configure_cmd} && mv #{latest_release}/config/#{rails_env}.sphinx.conf #{shared_path}/config"
    end
  end
end
