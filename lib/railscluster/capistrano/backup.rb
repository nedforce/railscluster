module Railscluster
  class Database
    def self.build config
      case config['adapter']
      when 'postgresql'
        PostgresqlDatabase
      when 'mysql2'
        MysqlDatabase
      else
        raise "unsupported adapter: #{config['adapter']}"
      end.new(config)
    end

    attr_reader :config
    def initialize config
      @config = config
    end

    # Backup through gateway (connects to localhost on specified forwarded local port)
    def backup_command(local_port, application); raise('not implemented'); end
    def find_local_backup;                       raise('not implemented'); end
    def restore_command(filename);               raise('not implemented'); end
  end

  class PostgresqlDatabase < Database
    def server_port
      config['port'] || 5432
    end

    def backup_command local_port, application
      filename = "#{application}.pgdump.#{Time.now.to_i}.pgz"
      
      "PGPASSWORD='#{config['password']}' pg_dump -Fc --no-owner --no-privileges -hlocalhost --port=#{local_port} -U#{config['username']} #{config['database']} -f backups/#{filename}"
    end

    def find_local_backup
      `ls -tr backups/*pgdump* | tail -n 1`.chomp
    end

    def restore_command file
      user = "-U #{config['username']}" if config['username']
      password = "PGPASSWORD='#{config['password']}' " if config['password']
      
      "#{password}pg_restore #{user} -d #{config['database']} -c -O -hlocalhost #{file}; true" 
    end
  end

  class MysqlDatabase < Database
    def server_port
      config['port'] || 3306
    end

    def backup_command local_port, application
      filename = "#{application}.mysqldump.#{Time.now.to_i}.sql"

      "mysqldump --user=#{config['username']} --password=#{config['password']} --host=localhost --port=#{local_port} --protocol=TCP #{config['database']} > backups/#{filename}"
    end

    def find_local_backup
      `ls -tr backups/*mysqldump* | tail -n 1`.chomp
    end

    def restore_command file
      "mysql --user=#{config['username']} --password=#{config['password']} #{config['database']} < #{file}"
    end
  end

end

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
      desc "Backup the remote uploads (public/private) to a local tar file."
      task :export, :roles => :app, :only => { :primary => true } do
        filename = "#{application}.uploads.#{Time.now.to_i}.tar.gz"
        file = "backups/#{filename}"
        
        run "cd #{shared_path} && tar -czf uploads.tar.gz private/uploads public/uploads"
        get "#{shared_path}/uploads.tar.gz", file
        run "rm #{shared_path}/uploads.tar.gz"
      end

      desc "Import the latest uploads backup."
      task :restore_locally, :roles => :app, :only => { :primary => true } do
        filename = `ls -tr backups/*uploads* | tail -n 1`.chomp
        run_locally "tar -xf #{filename}"
      end
      
      desc "Backup the remote uploads (public/private) to and expand it locally"
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
        database = Railscluster::Database.build(YAML::load_file("tmp/database.yml")[rails_env])
        run_locally("rm #{tmp_db_yml}")

        server = find_servers_for_task(current_task).first
        gateway = Net::SSH::Gateway.new(server.host, nil)
        local_port = gateway.open(database.config['host'], database.server_port)

        on_rollback {
          run_locally("rm #{tmp_db_yml}")
          gateway.shutdown!
        }
        
        run_locally "mkdir -p -v 'backups'"
        run_locally database.backup_command(local_port, application)

        gateway.shutdown!
      end

      desc "Import the latest backup to the local development database"
      task :restore_locally do
        database = Railscluster::Database.build(YAML::load_file("config/database.yml")["development"])
        file = database.find_local_backup
        if file.empty?
          logger.important "No backups found"
        else
          logger.debug "Loading #{file} into local development database"
          run_locally database.restore_command(file)
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