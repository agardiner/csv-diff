class CSVDiff

    # Reppresents an input (i.e the left/from or tight/to input) to the diff
    # process.
    class Source

        # @return [String] the path to the source file
        attr_accessor :path

        # @return [Array<String>] The names of the fields in the source file
        attr_reader :field_names
        # @return [Array<String>] The names of the field(s) that uniquely
        #   identify each row.
        attr_reader :key_fields
        # @return [Array<String>] The names of the field(s) that identify a
        #   common parent of child records.
        attr_reader :parent_fields
        # @return [Array<String>] The names of the field(s) that distinguish a
        #   child of a parent record.
        attr_reader :child_fields

        # @return [Array<Fixnum>] The indexes of the key fields in the source
        #   file.
        attr_reader :key_field_indexes
        # @return [Array<Fixnum>] The indexes of the parent fields in the source
        #   file.
        attr_reader :parent_field_indexes
        # @return [Array<Fixnum>] The indexes of the child fields in the source
        #   file.
        attr_reader :child_field_indexes

        # @return [Boolean] True if the source has been indexed with case-
        #   sensitive keys, or false if it has been indexed using upper-case key
        #   values.
        attr_reader :case_sensitive
        alias_method :case_sensitive?, :case_sensitive
        # @return [Boolean] True if leading/trailing whitespace should be stripped
        #   from fields
        attr_reader :trim_whitespace
        # @return [Hash<String,Hash>] A hash containing each line of the source,
        #   keyed on the values of the +key_fields+.
        attr_reader :lines
        # @return [Hash<String,Array<String>>] A hash containing each parent key,
        #   and an Array of the child keys it is a parent of.
        attr_reader :index
        # @return [Array<String>] An array of any warnings encountered while
        #   processing the source.
        attr_reader :warnings
        # @return [Fixnum] A count of the lines processed from this source.
        #   Excludes any header and duplicate records identified during indexing.
        attr_reader :line_count
        # @return [Fixnum] A count of the lines from this source that were skipped
        #   due to filter conditions.
        attr_reader :skip_count
        # @return [Fixnum] A count of the lines from this source that had the same
        #   key value as another line.
        attr_reader :dup_count


        # Creates a new diff source.
        #
        # A diff source must contain at least one field that will be used as the
        # key to identify the same record in a different version of this file.
        # If not specified via one of the options, the first field is assumed to
        # be the unique key.
        #
        # If multiple fields combine to form a unique key, the parent is assumed
        # to be identified by all but the last field of the unique key. If finer
        # control is required, use a combination of the :parent_fields and
        # :child_fields options.
        #
        # All key options can be specified either by field name, or by field
        # index (0 based).
        #
        # @param options [Hash] An options hash.
        # @option options [Array<String>] :field_names The names of each of the
        #   fields in +source+.
        # @option options [Boolean] :ignore_header If true, and :field_names has
        #   been specified, then the first row of the file is ignored.
        # @option options [String] :key_field The name of the field that uniquely
        #   identifies each row.
        # @option options [Array<String>] :key_fields The names of the fields
        #   that uniquely identifies each row.
        # @option options [String] :parent_field The name of the field(s) that
        #   identify a parent within which sibling order should be checked.
        # @option options [String] :child_field The name of the field(s) that
        #   uniquely identify a child of a parent.
        # @option options [Boolean] :case_sensitive If true (the default), keys
        #   are indexed as-is; if false, the index is built in upper-case for
        #   case-insensitive comparisons.
        # @option options [Hash] :include A hash of field name(s) or index(es) to
        #   regular expression(s). Only source rows whose field values satisfy the
        #   regular expressions will be indexed and included in the diff process.
        # @option options [Hash] :exclude A hash of field name(s) or index(es) to
        #   regular expression(s). Source rows with a field value that satisfies
        #   the regular expressions will be excluded from the diff process.
        def initialize(options = {})
            if (options.keys & [:parent_field, :parent_fields, :child_field, :child_fields]).empty? &&
               (kf = options.fetch(:key_field, options[:key_fields]))
                @key_fields = [kf].flatten
                @parent_fields = @key_fields[0...-1]
                @child_fields = @key_fields[-1..-1]
            else
                @parent_fields = [options.fetch(:parent_field, options[:parent_fields]) || []].flatten
                @child_fields = [options.fetch(:child_field, options[:child_fields]) || [0]].flatten
                @key_fields = @parent_fields + @child_fields
            end
            @field_names = options[:field_names]
            @case_sensitive = options.fetch(:case_sensitive, true)
            @trim_whitespace = options.fetch(:trim_whitespace, false)
            @ignore_header = options[:ignore_header]
            @include = options[:include]
            @exclued = options[:exclude]
            @path = options.fetch(:path, 'NA') unless @path
            @warnings = []
        end


        def path?
            @path != 'NA'
        end


        # Returns the row in the CSV source corresponding to the supplied key.
        #
        # @param key [String] The unique key to use to lookup the row.
        # @return [Hash] The fields for the line corresponding to +key+, or nil
        #   if the key is not recognised.
        def [](key)
            @lines[key]
        end


        # Given an array of lines, where each line is an array of fields, indexes
        # the array contents so that it can be looked up by key.
        def index_source
            @lines = {}
            @index = Hash.new{ |h, k| h[k] = [] }
            if @field_names
                index_fields
                include_filter = convert_filter(@include, @field_names)
                exclude_filter = convert_filter(@exclude, @field_names)
            end
            @line_count = 0
            @skip_count = 0
            @dup_count = 0
            line_num = 0
            @data.each do |row|
                line_num += 1
                next if line_num == 1 && @field_names && @ignore_header
                unless @field_names
                    if row.class.name == 'CSV::Row'
                        @field_names = row.headers.each_with_index.map{ |f, i| f || i.to_s }
                    else
                        @field_names = row.each_with_index.map{ |f, i| f || i.to_s }
                    end
                    index_fields
                    include_filter = convert_filter(@include, @field_names)
                    exclude_filter = convert_filter(@exclude, @field_names)
                    next
                end
                field_vals = row
                line = {}
                filter = false
                @field_names.each_with_index do |field, i|
                    val = field_vals[i]
                    val = val.to_s.strip if val && @trim_whitespace
                    line[field] = val
                    if include_filter && f = include_filter[i]
                        filter = !check_filter(f, line[field])
                    end
                    if exclude_filter && f = exclude_filter[i]
                        filter = check_filter(f, line[field])
                    end
                    break if filter
                end
                if filter
                    @skip_count += 1
                    next
                end
                key_values = @key_field_indexes.map{ |kf| @case_sensitive ?
                                                          field_vals[kf].to_s :
                                                          field_vals[kf].to_s.upcase }
                key = key_values.join('~')
                parent_key = key_values[0...(@parent_fields.length)].join('~')
                if @lines[key]
                    @warnings << "Duplicate key '#{key}' encountered at line #{line_num}"
                    @dup_count += 1
                    @key += "[#{@dup_count}]"
                end
                @index[parent_key] << key
                @lines[key] = line
                @line_count += 1
            end
        end

 
        # Save the data in this Source as a CSV at +file_path+.
        #
        # @parma file_path [String] The target path to save the data to.
        # @param options [Hash] A set of options to pass to CSV.open to control
        #   how the CSV is generated.
        def save_csv(file_path, options = {})
            require 'csv'
            default_opts = {
                headers: @field_name, write_headers: true
            }
            CSV.open(file_path, 'wb', default_opts.merge(options)) do |csv|
                @data.each{ |rec| csv << rec }
            end
        end


        private


        def index_fields
            @key_field_indexes = find_field_indexes(@key_fields, @field_names)
            @parent_field_indexes = find_field_indexes(@parent_fields, @field_names)
            @child_field_indexes = find_field_indexes(@child_fields, @field_names)
            @key_fields = @key_field_indexes.map{ |i| @field_names[i] }
            @parent_fields = @parent_field_indexes.map{ |i| @field_names[i] }
            @child_fields = @child_field_indexes.map{ |i| @field_names[i] }
        end


        # Converts an array of field names to an array of indexes of the fields
        # matching those names.
        def find_field_indexes(key_fields, field_names)
            key_fields.map do |field|
                if field.is_a?(Integer)
                    field
                else
                    field_names.index{ |field_name| field.to_s.downcase == field_name.to_s.downcase } or
                        raise ArgumentError, "Could not locate field '#{field}' in source field names: #{
                            field_names.join(', ')}"
                end
            end
        end


        def convert_filter(hsh, field_names)
            return unless hsh
            if !hsh.is_a?(Hash)
                raise ArgumentError, ":include/:exclude option must be a Hash of field name(s)/index(es) to RegExp(s)"
            end
            keys = hsh.keys
            idxs = find_field_indexes(keys, @field_names)
            Hash[keys.each_with_index.map{ |k, i| [idxs[i], hsh[k]] }]
        end


        def check_filter(filter, field_val)
            case filter
            when String
                if @case_sensitive
                    filter == field_val
                else
                    filter.downcase == field_val.to_s.downcase
                end
            when Regexp
                filter.match(field_val)
            when Proc
                filter.call(field_val)
            else
                raise ArgumentError, "Unsupported filter expression: #{filter.inspect}"
            end
        end

    end

end

