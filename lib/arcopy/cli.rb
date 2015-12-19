# Cli module for Arcopy
require 'optparse'

module Arcopy
  # Command line interface for ArCopy
  module Cli
    # Parse data from command line
    def self.run!
      # Default options
      options = {
        copy_schema: false,
        skip_tables: [],
        source:      'source'.freeze,
        target:      'target'.freeze,
        skip_data:   false,
        skip_reset:  false
      }

      opts = OptionParser.new do |opt|
        opt.banner = "Usage: #{$PROGRAM_NAME} [options] database.yml"

        opt.separator 'copy data between two databases defined in the given database_yaml'

        opt.on '-s', '--source', String, 'source configuration in yml file (default source)' do |arg|
          options[:source] = arg
        end

        opt.on '-t', '--target', String, 'target configuration in yml file (default target)' do |arg|
          options[:target] = arg
        end

        opt.on '-c', '--with-schema', 'also copy the schema to the target database' do |arg|
          options[:copy_schema] = arg
        end

        opt.on '-k', '--skip-tables x,y,z', Array, 'list of tables to skip (comma separated, use table names)' do |arg|
          options[:skip_tables] = arg
        end

        opt.on '-d', '--dont-copy', "don't copy data (load schema and reset indexes, sequences)" do |arg|
          options[:skip_data] = arg
        end

        opt.on '-r', '--dont-reset', "don't reset indexes" do |arg|
          options[:skip_reset] = arg
        end

        opt.on '-h', '--help', 'Display this screen' do
          puts opts
          exit
        end
      end

      # Parse
      opts.parse!

      # If there is not database.yml path - fail!
      unless ARGV[0]
        puts opts
        exit 1
      end

      Copy.new(ARGV[0], options).start!
    end
  end
end
