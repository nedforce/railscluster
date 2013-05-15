Capistrano::Configuration.instance(:must_exist).load do
  def changed? files
    if previous_revision.nil? || previous_revision.empty?
      # No revision deployed yet, so everything is new!
      true
    else
      pattern = files.is_a?(String) ? files : files.join(' ')
      `#{source.log(previous_revision, latest_revision)} #{pattern} | wc -l`.to_i > 0
    end
  end
end