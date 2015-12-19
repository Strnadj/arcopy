require 'active_record'
require 'logger'
require 'yaml'
require 'ruby-progressbar'
require 'activerecord-import'
require 'colorize'

module Arcopy
  # Main class for ArCopy
  class Copy
    # Define two databases source & target
    class SourceDB < ActiveRecord::Base
      self.abstract_class = true
    end

    class TargetDB < ActiveRecord::Base
      self.abstract_class = true
    end

    # Define batch size
    BATCH_SIZE = 500

    def initialize(config_file, opts={})
      # Set options
      @copy_schema = opts[:copy_schema]
      @skip_tables = opts[:skip_tables]
      @skip_data   = opts[:skip_data]
      @skip_reset  = opts[:skip_reset]

      # Tables for reset sequences
      @reset_tables = []

      # Load configuration file
      config = YAML.load_file(config_file)

      # Don't log ActiveRecord queries
      ActiveRecord::Base.logger ||= Logger.new(nil)

      # Set source & target database
      @source_db = config[opts[:source]]
      @target_db = config[opts[:target]]

      # Define connections for source & target db
      SourceDB.establish_connection(@source_db)
      ActiveRecord::Base.establish_connection(@target_db)

      # Get list of tables!
      @tables = SourceDB.connection.tables.reject do |table|
        @skip_tables.include?(table)
      end
    end

    def start!
      # Copy schema
      if @copy_schema
        puts '-> copy schema'
        copy_schema
      end

      # Start copying data
      puts '-> copy data'
      copy_data

      # Reset auto increments in postgresql
      if @reset_tables.any? || @skip_reset
        puts '-> resetting table sequences'
        if @target_db['adapter'].include?('postgresql')
          reset_pg_ai
        elsif @target_db['adapter'].include?('mysql')
          reset_mysql_ai
        end
      end
    end

    # Reset auto increments for postgres databases
    def reset_pg_ai
      @reset_tables.each do |table|
        TargetDB.connection.execute "SELECT setval('#{table}_id_seq', (select max(id) + 1 from #{table}))"
        puts "  -> resetting #{table} " + "\u{2713}".colorize(:green)
      end
    end

    # Reset auto increment for mysql databases
    def reset_mysql_ai
      @reset_tables.each do |table|
        max_id = TargetDB.connection "SELECT max(id) AS max_id FROM #{table}"
        max_id = max_id.first[0] + 1
        TargetDB.connection.execute "ALTER TABLE #{table} AUTO_INCREMENT = #{max_id}"
        puts "  -> resetting #{table} " + "\u{2713}".colorize(:green)
      end
    end

    # Let source db to generate schema and import it into
    # target db
    def copy_schema
      # IO
      io = StringIO.new

      # Call schema dumper on source db!
      ActiveRecord::SchemaDumper.dump(SourceDB.connection, io)

      # Rewind io
      io.rewind

      # If target database is PGSQL
      # we have to remove all :limits for binary data
      # types (pgsql does not support them!)
      if @target_db['adapter'].include?('postgresql')
        f = []
        io.read.split("\n").each do |line|
          if line.include?('binary') && line.include?('limit')
            line = line.gsub(/,\s*\:limit\s*=>\s*\d*/, '')
          end

          f << line
        end

        eval(f.join("\n"))
      else
        # Simply eval schema dump
        eval(io)
      end
    end

    # Copy data
    def copy_data
      @tables.each do |table_name|
        # Create source & target model
        source_model = Class.new(SourceDB) do
          self.inheritance_column = :_type_disabled
          self.table_name = table_name
        end
        dest_model = Class.new(TargetDB) do
          self.inheritance_column = :_type_disabled
          self.table_name = table_name
        end

        # Reset column informations
        source_model.reset_column_information
        dest_model.reset_column_information

        # Destroy all data in destination table!
        dest_model.delete_all

        # Total import records!
        count = source_model.count

        # No data
        if count == 0
          puts " -> Table #{table_name} has no data (skipping)! " + "\u{2713}".colorize(:green)
          next
        end

        # Has auto increment?
        has_ai = source_model.new.attributes.keys.include?(source_model.primary_key.to_s)

        # When yes add to reset tables
        @reset_tables << table_name if has_ai

        # Copy data
        unless @skip_data
          # Create progress bar
          bar = ProgressBar.create(total: count, title: ' records.', format: " -> Table #{table_name} |%b>>%i| %c/%C %p%% %t")

          # Copy data
          if has_ai
            # Copy table
            copy_table(source_model, dest_model, bar) unless @skip_data
          else
            # Copy without id
            copy_table_without_id(source_model, dest_model, bar) unless @skip_data
          end
        end

        # Puts result
        puts " -> Table #{table_name} finish! " + "\u{2713}".colorize(:green)
      end
    end

    private

    # Copy table without Auto Increment
    def copy_table(source_model, dest_model, bar)
      source_model.find_in_batches(batch_size: BATCH_SIZE) do |src_batch|
        dest_model.transaction do
          batch = []

          src_batch.each do |src_inst|
            dst_inst    = dest_model.new(src_inst.attributes)
            dst_inst.id = src_inst.id
            batch << dst_inst
          end

          dest_model.import(batch)

          bar.progress += batch.size
        end
      end
    end

    def copy_table_without_id(source_model, dest_model, bar)
      dest_model.primary_key = nil

      dest_model.transaction do
        batch = []

        source_model.all.each do |src_inst|
          batch << dest_model.new(src_inst.attributes)
        end

        batch.each_slice(BATCH_SIZE) do |arr|
          dest_model.import(arr)
          bar.progress += arr.size
        end
      end
    end
  end
end
