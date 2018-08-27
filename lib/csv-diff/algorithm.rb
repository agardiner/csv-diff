class CSVDiff

    # Implements the CSV diff algorithm.
    module Algorithm

        # Holds the details of a single difference
        class Diff

            attr_accessor :diff_type
            attr_reader :fields
            attr_reader :row
            attr_reader :sibling_position

            def initialize(diff_type, fields, row_idx, pos_idx)
                @diff_type = diff_type
                @fields = fields
                @row = row_idx + 1
                self.sibling_position = pos_idx
            end


            def sibling_position=(pos_idx)
                if pos_idx.is_a?(Array)
                    pos_idx.compact!
                    if pos_idx.first != pos_idx.last
                        @sibling_position = pos_idx.map{ |pos| pos + 1 }
                    else
                        @sibling_position = pos_idx.first + 1
                    end
                else
                    @sibling_position = pos_idx + 1
                end
            end


            # For backwards compatibility and access to fields with differences
            def [](key)
                case key
                when String
                    @fields[key]
                when :action
                    a = diff_type.to_s
                    a[0] = a[0].upcase
                    a
                when :row
                    @row
                when :sibling_position
                    @sibling_position
                end
            end

        end


        # Diffs two CSVSource structures.
        #
        # @param left [CSVSource] A CSVSource object containing the contents of
        #   the left/from input.
        # @param right [CSVSource] A CSVSource object containing the contents of
        #   the right/to input.
        # @param key_fields [Array] An array containing the names of the field(s)
        #   that uniquely identify each row.
        # @param diff_fields [Array] An array containing the names of the fields
        #   to be diff-ed.
        # @param options [Hash] An options hash.
        # @option options [Boolean] :ignore_adds If set to true, we ignore any
        #  new items that appear only in +right+.
        # @option options [Boolean] :ignore_moves If set to true, we ignore any
        #  changes in sibling order.
        # @option options [Boolean] :ignore_updates If set to true, we ignore any
        #  items that exist in both +left+ and +right+.
        # @option options [Boolean] :ignore_deletes If set to true, we ignore any
        #  new items that appear only in +left+.
        # @option options [Hash<Object,Proc>] :equality_procs A Hash mapping fields
        #  to a 2-arg Proc that should be used to compare values in that field for
        #  equality.
        def diff_sources(left, right, key_fields, diff_fields, options = {})
            unless left.case_sensitive? == right.case_sensitive?
                raise ArgumentError, "Left and right must have same settings for case-sensitivity"
            end

            # Ensure key fields are not also in the diff_fields
            diff_fields = diff_fields - key_fields

            left_index = left.index
            left_values = left.lines
            left_keys = left_values.keys
            right_index = right.index
            right_values = right.lines
            right_keys = right_values.keys
            parent_field_count = left.parent_fields.length

            include_adds = !options[:ignore_adds]
            include_moves = !options[:ignore_moves]
            include_updates = !options[:ignore_updates]
            include_deletes = !options[:ignore_deletes]

            @case_sensitive = left.case_sensitive?
            @equality_procs = options.fetch(:equality_procs, {})

            diffs = {}
            potential_moves = Hash.new{ |h, k| h[k] = [] }

            # First identify deletions
            if include_deletes
                (left_keys - right_keys).each do |key|
                    # Delete
                    key_vals = key.split('~', -1)
                    parent = key_vals[0...parent_field_count].join('~')
                    child = key_vals[parent_field_count..-1].join('~')
                    left_parent = left_index[parent]
                    left_value = left_values[key]
                    row_idx = left_keys.index(key)
                    sib_idx = left_parent.index(key)
                    raise "Can't locate key #{key} in parent #{parent}" unless sib_idx
                    diffs[key] = Diff.new(:delete, left_value, row_idx, sib_idx)
                    potential_moves[child] << key
                    #puts "Delete: #{key}"
                end
            end

            # Now identify adds/updates
            right_keys.each_with_index do |key, right_row_id|
                key_vals = key.split('~', -1)
                parent = key_vals[0...parent_field_count].join('~')
                left_parent = left_index[parent]
                right_parent = right_index[parent]
                left_value = left_values[key]
                right_value = right_values[key]
                left_idx = left_parent && left_parent.index(key)
                right_idx = right_parent && right_parent.index(key)

                if left_idx && right_idx
                    if include_updates && (changes = diff_row(left_value, right_value, diff_fields))
                        id = id_fields(key_fields, right_value)
                        diffs[key] = Diff.new(:update, id.merge!(changes), right_row_id, right_idx)
                        #puts "Change: #{key}"
                    end
                    if include_moves
                        left_common = left_parent & right_parent
                        right_common = right_parent & left_parent
                        left_pos = left_common.index(key)
                        right_pos = right_common.index(key)
                        if left_pos != right_pos
                            # Move
                            if d = diffs[key]
                                d.sibling_position = [left_idx, right_idx]
                            else
                                id = id_fields(key_fields, right_value)
                                diffs[key] = Diff.new(:move, id, right_row_id, [left_idx, right_idx])
                            end
                            #puts "Move #{left_idx} -> #{right_idx}: #{key}"
                        end
                    end
                elsif right_idx
                    # Add
                    child = key_vals[parent_field_count..-1].join('~')
                    if include_moves && potential_moves.has_key?(child) && old_key = potential_moves[child].pop
                        diffs.delete(old_key)
                        if include_updates
                            left_value = left_values[old_key]
                            id = id_fields(right.child_fields, right_value)
                            changes = diff_row(left_value, right_value, left.parent_fields + diff_fields)
                            diffs[key] = Diff.new(:update, id.merge!(changes), right_row_id, right_idx)
                            #puts "Update Parent: #{key}"
                        end
                    elsif include_adds
                        diffs[key] = Diff.new(:add, right_value, right_row_id, right_idx)
                        #puts "Add: #{key}"
                    end
                end
            end

            diffs
        end


        # Identifies the fields that are different between two versions of the
        # same row.
        #
        # @param left_row [Hash] The version of the CSV row from the left/from
        #   file.
        # @param right_row [Hash] The version of the CSV row from the right/to
        #   file.
        # @param fields [Array<String>] An array of field names to compare.
        # @return [Hash<String, Array>] A Hash whose keys are the fields that
        #   contain differences, and whose values are a two-element array of
        #   [left/from, right/to] values.
        def diff_row(left_row, right_row, fields)
            diffs = {}
            fields.each do |attr|
                eq_proc = @equality_procs[attr]
                right_val = right_row[attr]
                right_val = nil if right_val == ""
                left_val = left_row[attr]
                left_val = nil if left_val == ""
                if eq_proc
                    diffs[attr] = [left_val, right_val] unless eq_proc.call(left_val, right_val)
                elsif @case_sensitive
                    diffs[attr] = [left_val, right_val] unless left_val == right_val
                elsif (left_val.to_s.upcase != right_val.to_s.upcase)
                    diffs[attr] = [left_val, right_val]
                end
            end
            diffs if diffs.size > 0
        end


        private


        # Return a hash containing just the key field values
        def id_fields(key_fields, fields)
            id = {}
            key_fields.each do |field_name|
                id[field_name] = fields[field_name]
            end
            id
        end

    end

end
