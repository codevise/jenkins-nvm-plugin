require 'stringio'

class NvmWrapper < Jenkins::Tasks::BuildWrapper
  display_name "Run the build in an nvm managed environment"

  attr_reader :version
  attr_reader :launcher

  def initialize(attrs)
    @version = fix_empty(attrs['version'])
  end

  def nvm_path
    @nvm_path ||= ["~/.nvm/nvm.sh", "/usr/local/nvm/nvm.sh"].find do |path|
      launcher.execute("bash", "-c", "test -f #{path}") == 0
    end
  end

  def nvm_installed?
    !nvm_path.nil?
  end

  def setup(build, launcher, listener)
    @launcher = launcher

    before = StringIO.new()
    if launcher.execute("bash", "-c", "export", {:out => before}) != 0
      listener << "Failed to fork bash\n"
      listener << before.string
      build.abort
    end

    if !nvm_installed?
      listener << "Installing nvm\n"
      installer = build.workspace + "nvm-installer"
      installer.native.copyFrom(java.net.URL.new("https://raw.github.com/creationix/nvm/master/install.sh"))
      installer.chmod(0755)
      launcher.execute(installer.realpath, {:out => listener})
    end

    listener << "nvm use #{version}\n"

    if launcher.execute("bash", "-c",
                        " source #{nvm_path} && nvm install #{version} && nvm use #{version} && export > nvm.env",
                        :out => listener, :chdir => build.workspace) != 0
      build.abort "Failed to setup NVM environment"
    end

    bh = to_hash(before.string)
    ah = to_hash((build.workspace + "nvm.env").read)

    ah.each do |k,v|
      bv = bh[k]

      next if %w(HUDSON_COOKIE JENKINS_COOKIE).include? k # cookie Jenkins uses to track process tree. ignore.
      next if bv == v  # no change in value

      if k == "PATH"
        # look for PATH components that include ".nvm" and pick those up
        path = v.split(File::PATH_SEPARATOR).find_all{|p| p =~ /[\\\/]\.nvm[\\\/]/ }.join(File::PATH_SEPARATOR)

        # Obviously Jenkins then magically merges this into $PATH in shell script build steps
        build.env["PATH+NVM"] = path
      else
        build.env[k] = v
      end
    end
  end

  private

  def fix_empty(s)
    s == "" ? nil : s
  end

  def to_hash(export)
    r = {}
    export.split("\n").each do |l|
      if l.start_with? "declare -x "
        l = l[11..-1]  # trim off "declare -x "
        k,v = l.split("=", 2)
        if v
          r[k] = (v[0] == ?" || v[0] == ?') ? v[1..-2] : v # trim off the quote surrounding it
        end
      end
    end
    r
  end
end
