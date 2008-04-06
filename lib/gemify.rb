# DEPRECATED: Just here so we can easily merge it to the new source

require 'rubygems'
require 'rubygems/builder'
require 'yaml'

require 'gemify/vcs'

class Gemify
  attr_accessor :from_vcs
  
  class Exit < StandardError;end
  SETTINGS = ".gemified"
  MANIFEST = ["MANIFEST", "Manifest.txt", ".manifest"]
  REQUIRED = [:name, :summary, :version]
  OPTIONAL = [:author, :email, :homepage, :rubyforge_project, :has_rdoc, :dependencies]
  ALL = REQUIRED+OPTIONAL
  REPLACE = {
    :rubyforge_project => "RubyForge project",
    :has_rdoc => "documentation",
  }
  TYPE = {
    :has_rdoc => :boolean,
    :dependencies => :array,
  }
  
  def initialize
    @settings = {}
    @from_vcs = false

    if File.exists? SETTINGS
      load!
    end
  end
  
  def files
    @files ||= if @from_vcs
      VCS.files
    elsif m=MANIFEST.detect{|x|File.exist?(x)}                 
      File.read(m).split(/\r?\n/)
    else
      VCS.files(:unknown)
    end
  end
  
  def bin
    files.select { |file| file =~ /^bin\// }
  end
  
  def extensions
    files.select { |file| file =~ /extconf\.rb$/ }
  end
  
  def main
    loop do
      menu
      puts @result if @result
      @result = nil
      l=(o=gets).downcase[0]
      i=o.to_i
      
      case l
      when ?x
        raise Exit
      when ?b
        build!
      when ?s
        save!
        next
      when ?i
        @result = "Included files:#{$/}" + files.join($/)
        next
      end      
      
      if (1..ALL.length).include? i
        set(ALL[i-1])
        next
      end
      
      @result = "Can't find the task named '#{o}'"
    end
  end
  
  def menu
    require_files!
    clear
    puts "Welcome to Gemify!"
    puts
    puts "Which task would you like to invoke?"
    ALL.each do |m|
      puts build_task(m)
    end
    puts
    puts "s) Save"
    puts "i) Show included files"
    puts
    puts "b) Build gem"
    puts "x) Exit"
    puts
  end
  
  ## Special tasks
  
  def build!
    require_files!
    Gem::Builder.new(Gem::Specification.new do |s|
      (@settings.delete(:dependencies)||[]).each do |dep|
        s.add_dependency dep
      end
      
      @settings.each { |key, value| s.send("#{key}=",value) }
      s.platform = Gem::Platform::RUBY
      s.files = files
      s.bindir = "bin"
      s.require_path = "lib"

      unless bin.empty?
        s.executables = bin.map{|x|x[4..-1]}
      end
      
      unless extensions.empty?
        s.extensions = extensions
      end
      
    end).build
    raise Exit
  end
  
  def load!
    @settings = YAML.load(File.read(SETTINGS))
    @settings.keys.each do |key|
      @settings[key] = value(key)
    end
  rescue Errno::EACCES
    @result = "Can't read #{SETTINGS}"
  end
  
  def save!
    File.open(SETTINGS,"w"){|f|f << YAML.dump(@settings)}
    @result = "Saved!"
  rescue Errno::EACCES
    @result = "Can't write to #{SETTINGS}"
  end  
  
  def build_task(m)
    index = (ALL.index(m)||0)+1
    unless type(m) == :boolean
      verb,now = if @settings.keys.include?(m)
        ["Change"," = " + inspect_setting(m)]
      else
        ["Set",""]
      end
    else
      verb, now = ["Toogle"," = " + inspect_setting(m)]
    end
    req = REQUIRED.include?(m) ? " (required)" : ""
    "#{index}) #{verb} #{show(m)}#{req}#{now}"
  end
  
  def clear
    system("cls") || print("\e[H\e[2J")
  end
  
  def set(m)
    menu
    case type(m)
    when :array
      puts "Split by ENTER and press ENTER twice when you're done"
      puts "> #{show(m).capitalize}: "
      @settings[m] = $stdin.gets($/*2).strip.split($/)
      @settings.delete(m) if @settings[m].empty?
    when :boolean
      @settings[m] = !@settings[m]
    when :string
      print "> #{show(m).capitalize}: "
      @settings[m] = $stdin.gets.strip
      @settings.delete(m) if @settings[m].empty?
    end
    @result = "Updated '#{m}'"
  end
  
  def gets
    print("> ")
    $stdin.gets.strip
  end
  
  def show(m)
    REPLACE[m]||m.to_s
  end
  
  def type(m)
    TYPE[m]||:string
  end
  
  def value(m)
    i=@settings[m]
    case type(m)
    when :array
      i.to_a
    when :boolean
      !!i
    when :string
      i.to_s
    end
  end
  
  def inspect_setting(m)
    i=@settings[m]     
    case type(m)
    when :array
      i.join(", ")
    when :boolean
      (i||false).to_s
    when :string
      i.to_s
    end
  end
  
  protected
  def require_files!
    if files.empty?
      puts "Can't find anything to make a gem out of..."
      raise Exit
    end
  end
end
