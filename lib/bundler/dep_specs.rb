require 'bundler/dep_fetcher'
require 'bundler/endpoint_specification'
require 'bundler/index'

module Bundler
  class DepSpecs
    NAME_PATTERN = /\A[0-9a-zA-Z_\-][0-9a-zA-Z_\-\.]*\Z/
    VERSION_PATTERN = /\A[0-9]+(?>\.[0-9a-zA-Z]+)*(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?\Z/

    def initialize(source, names)
      @source, @names = source, names
    end

    def spec_index
      @spec_index ||= Index.build do |i|
        each_spec { |s| i << s }
      end
    end

    def each_spec
      fetch_specs

      @names.each do |name|
        raise "Sorry, #{name} is not a valid gem name" unless name =~ NAME_PATTERN
        each_spec_for(name) { |spec| yield spec }
      end
    end

    def fetch_specs
      # not yet implemented
    end

  private

    def each_spec_for(name)
      each_index_line("deps/#{name}") do |line|
        version, platform, deps, reqs = version_info(line) || next
        spec = EndpointSpecification.new(name, version, platform, deps)
        reqs.each do |req|
          spec.send("required_#{req.name}_version", req.requirement)
        end if reqs
        spec.source = @source
        yield spec
      end
    end

    def version_info(line)
      vp, dr = line.split(' ', 2)
      return unless vp =~ VERSION_PATTERN

      v, p = vp.split("-", 2)
      gv, gp = Gem::Version.new(v), Gem::Platform.new(p)

      deps, reqs = dr.split('|').map{|l| l.split(",") }
      gd = deps.map { |d| Gem::Dependency.new(*d.split(":")) } if deps
      gr = reqs.map { |r| Gem::Dependency.new(*r.split(":")) } if reqs

      [gv, gp, gd, gr]
    end

    def each_index_line(filename)
      Bundler.bundle_path.join(filename).open do |file|
        in_prologue = true
        file.each_line do |line|
          line.chomp!
          in_prologue = false if line == "---"
          yield(line) unless in_prologue
        end
      end
    end

  end
end
