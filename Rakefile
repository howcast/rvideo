require "rubygems"
require "fileutils"
require "echoe"

__HERE__ = File.dirname(__FILE__)
require File.join(__HERE__, 'lib', 'rvideo', 'version')
require File.join(__HERE__, 'lib', 'rvideo')

###

AUTHOR = [
  "Peter Boling",
  "Jonathan Dahl (Slantwise Design)",
  "Seth Thomas Rasmussen"
]
EMAIL       = "sethrasmussen@gmail.com"
DESCRIPTION = "Inspect and transcode video and audio files."

NAME = "rvideo"

REV    = `git log -n1 --pretty=oneline | cut -d' ' -f1`.strip
BRANCH = `git branch | grep '*' | cut -d' ' -f2`.strip

# This is not the version used for the gem. 
# That is parsed from the CHANGELOG by Echoe.
VERS = "#{RVideo::VERSION::STRING} (#{BRANCH} @ #{REV})"

Echoe.new NAME do |p|
  p.author      = AUTHOR 
  p.description = DESCRIPTION
  p.email       = EMAIL
  p.summary     = DESCRIPTION
  p.url         = "http://github.com/greatseth/rvideo"
  
  p.runtime_dependencies     = ["activesupport"]
  p.development_dependencies = ["rspec"]
  
  p.ignore_pattern = [
    "spec/files/boat.mpg",
    "spec/files/dinner.3g2",
    "spec/files/foo $ bar & baz",
    "spec/files/hats.3gp",
    "spec/files/quads.wmv",
    "spec/files/sword.3gp",
    "website/**/*",
    "tmp/**/*",
    "scripts/test_progress.rb"
  ]
  
  p.rdoc_options = [
    "--quiet",
    "--title", "rvideo documentation",
    "--opname", "index.html",
    "--line-numbers", 
    "--main", "README",
    "--inline-source"
  ]
end

# Load supporting Rake files
Dir[File.join(__HERE__, "tasks", "*.rake")].each { |t| load t }

puts "#{NAME} #{VERS}"
