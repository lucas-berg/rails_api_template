begin
  require 'dotenv/load'
rescue LoadError
  # The initial bundle installation can run before dotenv is available.
end

def running_with_docker?
  ENV['DOCKER_ENABLED'] == 'true' && !File.exist?('/.dockerenv')
end
