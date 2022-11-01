class CSVDiff

    # Represents a CSV input (i.e. the left/from or right/to input) to the diff
    # process.
    class CSVSource < Source

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
        # @param source [String|Array<Array>] Either a path to a CSV file, or an
        #   Array of Arrays containing CSV data. If the :field_names option is
        #   not specified, the first line must contain the names of the fields.
        # @param options [Hash] An options hash.
        # @option options [String] :encoding The encoding to use when opening the
        #   CSV file.
        # @option options [Hash] :csv_options Any options you wish to pass to
        #   CSV.open, e.g. :col_sep.
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
        def initialize(source, options = {})
            super(options)
            if source.is_a?(String)
                require 'csv'
                mode_string = options[:encoding] ? "r:#{options[:encoding]}" : 'r'
                csv_options = options.fetch(:csv_options, {})
                @path = source
                # When you call CSV.open, it's best to pass in a block so that after it's yielded,
                # the underlying file handle is closed. Otherwise, you risk leaking the handle.
                @data = CSV.open(@path, mode_string, **csv_options) do |csv|
                     csv.readlines
                end
            elsif source.is_a?(Enumerable) && source.size == 0 || (source.size > 0 && source.first.is_a?(Enumerable))
                @data = source
            else
                raise ArgumentError, "source must be a path to a file or an Enumerable<Enumerable>"
            end
            index_source
        end

    end

end

