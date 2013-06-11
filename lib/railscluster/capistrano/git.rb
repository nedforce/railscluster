Capistrano::Configuration.instance(:must_exist).load do
  set :branch do
    tags  = `git ls-remote --tags | awk -F/ '$NF !~ /[\}]$/ {print $NF}'`.split("\n")
    heads = `git ls-remote --heads | awk -F/ '{print $NF}'`.split("\n")
    Capistrano::CLI.ui.choose do |menu|
      menu.header = "Remote Branches & Tags"
      menu.choices *heads
      menu.choices *tags
      menu.default = tags.last || heads.select {|h| h == 'master'}.first || heads.last
      menu.prompt = "Select a branch/tag [default: #{menu.default}]:"
    end
  end
  
  task :deployed_version do
    tag = `git describe --all #{latest_revision} 2> /dev/null`
    if tag.empty?
      rev = `git log -1 --oneline #{latest_revision}`
      puts "\n\nCurrently deployed revision:\n#{rev}" if rev
    else
      puts "\n\nCurrently deployed tag/head:\n#{tag}"
    end
  end
end