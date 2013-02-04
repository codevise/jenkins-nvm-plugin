Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = 'nvm'
  plugin.display_name = 'nvm Build Environment' 
  plugin.version = '0.2'
  plugin.description = 'Run Jenkins builds in nvm environment'

  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/NVM+Plugin'
  plugin.developed_by 'Tim Fischbach', 'tfischbach@codevise.de'
  plugin.uses_repository :github => 'codevise/jenkins-nvm-plugin'

  plugin.depends_on 'ruby-runtime', '0.10'
end
