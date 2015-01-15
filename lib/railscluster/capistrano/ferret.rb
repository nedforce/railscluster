Capistrano::Configuration.instance(:must_exist).load do

  before 'deploy:restart' do
    ferret.restart
  end

  after "deploy:setup" do
    run "mkdir -p #{shared_path}/index"
  end

  namespace :ferret do
    desc "Start the ferret daemon" 
    task :start, :roles => :app do
      run "cluster_service ferret start" 
    end

    desc "Restart the ferret daemon" 
    task :restart, :roles => :app do
      run "cluster_service ferret restart" 
    end

    desc "Stop the ferret daemon" 
    task :stop, :roles => :app do
      run "cluster_service ferret stop" 
    end
  end
end
