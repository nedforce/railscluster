Capistrano::Configuration.instance(:must_exist).load do
  namespace :db do
    require 'yaml'

    desc "Backup the remote production database to a local file"
    task :backup, :roles => :db, :only => { :primary => true } do
          
      # First lets get the remote database config file so that we can read in the database settings
      logger.info "Loading the database configuration for the #{rails_env} environment..."
            
      tmp_db_yml = "tmp/database.yml"
      get("#{shared_path}/config/database.yml", tmp_db_yml) rescue logger.important "Could not load database configuration. Have you specified rails_env?" and exit

      # load the production settings within the database file
      db = YAML::load_file("tmp/database.yml")[rails_env]

      run_locally("rm #{tmp_db_yml}")
      filename = "#{application}.dump.#{Time.now.to_i}.sql.bz2"
      file = "/home/#{account}/tmp/#{filename}"
      on_rollback {
        run "rm #{file}"
        run_locally("rm #{tmp_db_yml}")
      }
      begin
        run "pg_dump --clean --no-owner --no-privileges -h#{db['host']} -U#{db['username']} #{db['database']} | bzip2 > #{file}" do |ch, stream, out|
          ch.send_data "#{db['password']}\n" if out =~ /^Password:/
          puts out
        end
      rescue 
        logger.important "Could export DB. Have you configured it correctly?" and exit
      end
      run_locally "mkdir -p -v 'backups'"
      get file, "backups/#{filename}"
      run "rm #{file}"
    end

    desc "Import the latest backup to the local development database"
    task :import do
      filename = `ls -tr backups | tail -n 1`.chomp
      if filename.empty?
        logger.important "No backups found"
      else
        ddb = YAML::load_file("config/database.yml")["development"]
        logger.debug "Loading backups/#{filename} into local development database"
        ENV['PGPASSWORD'] = ddb['password']
        run_locally "bzip2 -cd backups/#{filename} | psql -U #{ddb['username']} -d #{ddb['database']}"
        logger.debug "command finished"
      end
    end

    desc "Backup the remote production database and import it to the local development database"
    task :duplicate do
      backup
      import
    end
  end
end