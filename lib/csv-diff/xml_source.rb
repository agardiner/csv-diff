require 'nokogiri'
require 'cgi'


class CSVDiff

    # Convert XML content to CSV format using XPath selectors to identify the
    # rows and field values in an XML document
    class XMLSource < Source

        attr_accessor :context

        # Create a new XMLSource, identified by +path+. Normally this is a path
        # to the XML document, but any value is fine, as it is just a label to
        # identify this data set.
        #
        # @param path [String] A label for this data set (often a path to the
        #   XML document used as the source).
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
        # @option options [String] :context A context value from which fields
        #   can be populated using a Regexp.
        def initialize(path, options = {})
            super(options)
            @path = path
            @context = options[:context]
            @data = []
        end

        
        # Process a +source+, converting the XML into a table of data, using
        # +rec_xpath+ to identify the nodes that correspond each record that
        # should appear in the output, and +field_maps+ to populate each field
        # in each row.
        #
        # @param source [String|Array] may be a String containing XML content,
        #   an Array of paths to files containing XML content, or a path to
        #   a single file.
        # @param rec_xpath [String] An XPath expression that selects all the
        #   items in the XML document that are to be converted into new rows.
        #   The returned items are not directly used to populate the fields,
        #   but provide a context for the field XPath expreessions that populate
        #   each field's content.
        # @param field_maps [Hash<String, String>] A map of field names to
        #   expressions that are evaluated in the context of each row node
        #   selected by +rec_xpath+. The field expressions are typically XPath
        #   expressions evaluated in the context of the nodes returned by the
        #   +rec_xpath+. Alternatively, a String that is not an XPath expression
        #   is used as a literal value for a field, while a Regexp can also
        #   be used to pull a value from any context specified in the +options+
        #   hash. The Regexp should include a single grouping, as the value used
        #   will be the result in $1 after the match is performed.
        # @param context [String] An optional context for the XML to be processed.
        #   The value passed here can be referenced in field map expressions
        #   using a Regexp, with the value of the first grouping in the regex
        #   being the value returned for the field.
        def process(source, rec_xpath, field_maps, context = nil)
            @field_names = field_maps.keys.map(&:to_s) unless @field_names
            case source
            when Nokogiri::XML::Document
                add_data(source, rec_xpath, field_maps, context || @context)
            when /<\?xml/
                doc = Nokogiri::XML(source)
                add_data(doc, rec_xpath, field_maps, context || @context)
            when Array
                source.each{ |f| process_file(f, rec_xpath, field_maps) }
            when String
                process_file(source, rec_xpath, field_maps)
            else
                raise ArgumentError, "Unhandled source type #{source.class.name}"
            end
            @data
        end


        private


        # Load the XML document at +file_path+ and process it into rows of data.
        def process_file(file_path, rec_xpath, field_maps)
            begin
                File.open(file_path) do |f|
                    doc = Nokogiri::XML(f)
                    add_data(doc, rec_xpath, field_maps, @context || file_path)
                end
            rescue
                STDERR.puts "An error occurred while attempting to open #{file_path}"
                raise
            end
        end


        # Locate records in +doc+ using +rec_xpath+ to identify the nodes that
        # correspond to a new record in the data, and +field_maps+ to populate
        # the fields in each row.
        def add_data(doc, rec_xpath, field_maps, context)
            doc.xpath(rec_xpath).each do |rec_node|
                rec = []
                field_maps.each do |field_name, expr|
                    case expr
                    when Regexp         # Match context against Regexp and extract first grouping
                        if context
                            context =~ expr
                            rec << $1
                        else
                            rec << nil
                        end
                    when %r{[/(.@]}     # XPath expression
                        res = rec_node.xpath(expr)
                        rec << CGI.unescape_html(res.to_s)
                    else                # Use expr as the value for this field
                        rec << expr
                    end
                end
                @data << rec
            end
        end
            
    end

end

