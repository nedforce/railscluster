Capistrano::Configuration::Actions::FileTransfer.class_eval do
  require 'digest/md5'

  def transfer(direction, from, to, options={}, &block)
    if dry_run
      return logger.debug "transfering: #{[direction, from, to] * ', '}"
    end
    if direction == :up
      original_to = to
      to = "/tmp/#{Digest::MD5.hexdigest(to)}"
    elsif direction == :down
      original_from = from
      from = "/tmp/#{Digest::MD5.hexdigest(from)}"
      run "sudo cp #{original_from} #{from}"
      run "sudo chown $USER: #{from}"
    end
    execute_on_servers(options) do |servers|
      targets = servers.map { |s| sessions[s] }
        Capistrano::Transfer.process(direction, from, to, targets, options.merge(:logger => logger), &block)
    end
    if direction == :up
      run "sudo chown #{fetch(:account)}: #{to}"
      run "sudo mv #{to} #{original_to}"
    elsif direction == :down
      run "sudo rm #{from}"
    end
  end
end

Capistrano::Configuration::Actions::Invocation.class_eval do
  def run(cmd, options={}, &block)
    cmd = sudo_wrap_command(cmd)

    if options[:eof].nil? && !cmd.include?(fetch(:sudo, "sudo"))
      options = options.merge(:eof => !block_given?)
    end
    block ||= self.class.default_io_proc
    tree = Capistrano::Command::Tree.new(self) { |t| t.else(cmd, &block) }
    run_tree(tree, options)
  end

  def sudo_wrap_command(cmd)
    unless cmd.include? "sudo"
      user = fetch(:account)
      sudo_command = [fetch(:sudo, "sudo"), '-u', user ].compact.join(" ")
      cmd = "#{sudo_command} bash -lc '#{cmd}' " 
      # Wrap command to access ssh agent
      cmd = "setfacl -m #{user}:x $(dirname \"$SSH_AUTH_SOCK\") && setfacl -m #{user}:rwx \"$SSH_AUTH_SOCK\" && #{cmd} && setfacl -b $(dirname \"$SSH_AUTH_SOCK\") && setfacl -b \"$SSH_AUTH_SOCK\""
    end
    return cmd
  end

end

Capistrano::Logger.add_formatter({
  :match    => /(.* bash -lc ')|('  && setfacl -b .*)/,
  :replace  => "",
  :level    => 2,
  :priority => 5
})

require 'capistrano/recipes/deploy/scm/git'
module Capistrano
  module Deploy
    module SCM
      class Git
        def export(revision, destination)
          if variable(:git_enable_submodules) || !variable(:repository).include?('git.nedforce.nl')
            checkout(revision, destination) << " && rm -Rf #{destination}/.git"
          else
            git    = command
            remote = origin

            args = []

            args << "--verbose" if verbose.nil?
            args << "--prefix=#{destination[1..-1]}/"
            args << "--remote #{variable(:repository)}"
            
            execute = []
            execute << "#{git} archive #{args.join(' ')} #{revision} | (tar -x -C / -f -)"

            execute.compact.join(" && ").gsub(/\s+/, ' ')
          end
        end
      end
    end
  end
end