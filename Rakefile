require 'rake'
require 'rspec/core/rake_task'
require 'rdoc/task'

RSpec::Core::RakeTask.new(:default) do | t |
end

Rake::RDocTask.new do | rd |
  rd.rdoc_files.include('README.md', 'lib/**/*.rb', 'app/**/*.rb')

  rd.title     = 'Scimitar'
  rd.main      = 'README.md'
  rd.rdoc_dir  = 'docs/rdoc'
  rd.generator = 'rdoc'
end
