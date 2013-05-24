Capistrano::Configuration.instance(:must_exist).load do
  namespace :backup do
    task :default do
      export
    end
    task :export do
      db.export
      uploads.export
    end
    task :restore_locally do
      db.restore_locally
      uploads.restore_locally
    end
    task :copy do
      db.copy
      uploads.copy
    end


    namespace :uploads do
      task :export, :roles => :app, :only => { :primary => true } do
        filename = "#{application}.uploads.#{Time.now.to_i}.tar.gz"
        file = "backups/#{filename}"
        
        run "cd #{shared_path} && tar -czf uploads.tar.gz private/uploads public/uploads"
        get "#{shared_path}/uploads.tar.gz", file
        run "rm #{shared_path}/uploads.tar.gz"
      end

      task :restore_locally, :roles => :app, :only => { :primary => true } do
        filename = `ls -tr backups/*uploads* | tail -n 1`.chomp
        run_locally "tar -xf #{filename}"
      end
      
      task :copy,  :roles => :app, :only => { :primary => true } do
        export
        restore_locally
      end
    end

    namespace :db do
      require 'yaml'

      desc "Backup the remote production database to a local file, uses a binary format."
      task :export, :roles => :db, :only => { :primary => true } do
            
        # First lets get the remote database config file so that we can read in the database settings
        logger.info "Loading the database configuration for the #{rails_env} environment..."
              
        tmp_db_yml = "tmp/database.yml"
        get("#{shared_path}/config/database.yml", tmp_db_yml) #rescue logger.important "Could not load database configuration. Have you specified rails_env?" and exit

        # load the production settings within the database file
        db = YAML::load_file("tmp/database.yml")[rails_env]

        run_locally("rm #{tmp_db_yml}")
        filename = "#{application}.pgdump.#{Time.now.to_i}.pgz"
        file = "backups/#{filename}"

        server = find_servers_for_task(current_task).first
        gateway = Net::SSH::Gateway.new(server.host, nil)
        port = db['port'] || 5432
        local_port = gateway.open(db['host'], port)

        on_rollback {
          run_locally("rm #{tmp_db_yml}")
          gateway.shutdown!
        }
        
        run_locally "mkdir -p -v 'backups'"        
        run_locally "PGPASSWORD='#{db['password']}' pg_dump -Fc --no-owner --no-privileges -hlocalhost --port=#{local_port} -U#{db['username']} #{db['database']} -f #{file}"

        gateway.shutdown!
      end

      desc "Import the latest backup to the local development database"
      task :restore_locally do
        filename = `ls -tr backups/*pgdump* | tail -n 1`.chomp
        if filename.empty?
          logger.important "No backups found"
        else
          ddb = YAML::load_file("config/database.yml")["development"]
          logger.debug "Loading #{filename} into local development database"
          ENV['PGPASSWORD'] = ddb['password']
          run_locally "pg_restore -U #{ddb['username']} -d #{ddb['database']} -c -O -hlocalhost #{filename}; true" 
        end
      end

      desc "Backup the remote production database and restore it to the local development database"
      task :copy do
        export
        restore_locally
      end
    end
  end
end