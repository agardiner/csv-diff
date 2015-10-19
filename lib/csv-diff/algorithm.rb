class CSVDiff

    # Implements the CSV diff algorithm.
    module Algorithm

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
        def diff_sources(left, right, key_fields, diff_fields, options = {})
            unless left.case_sensitive? == right.case_sensitive?
                raise ArgumentError, "Left and right must have same settings for case-sensitivity"
            end
            case_sensitive = left.case_sensitive?
            left_index = left.index
            left_values = left.lines
            left_keys = left_values.keys
            right_index = right.index
            right_values = right.lines
            right_keys = right_values.keys
            parent_fields = left.parent_fields.length

            include_adds = !options[:ignore_adds]
            include_moves = !options[:ignore_moves]
            include_updates = !options[:ignore_updates]
            include_deletes = !options[:ignore_deletes]

            diffs = Hash.new{ |h, k| h[k] = {} }

            # First identify deletions
            if include_deletes
                (left_keys - right_keys).each do |key|
                    # Delete
                    key_vals = key.split('~', -1)
                    parent = key_vals[0...parent_fields].join('~')
                    left_parent = left_index[parent]
                    left_value = left_values[key]
                    left_idx = left_parent.index(key)
                    next unless left_idx
                    id = {}
                    id[:row] = left_keys.index(key) + 1
                    id[:sibling_position] = left_idx + 1
                    key_fields.each do |field_name|
                        id[field_name] = left_value[field_name]
                    end
                    diffs[key].merge!(id.merge(left_values[key].merge(:action => 'Delete')))
                    #puts "Delete: #{key}"
                end
            end

            # Now identify adds/updates
            right_keys.each_with_index do |key, right_row_id|
                key_vals = key.split('~', -1)
                parent = key_vals[0...parent_fields].join('~')
                left_parent = left_index[parent]
                right_parent = right_index[parent]
                left_value = left_values[key]
                right_value = right_values[key]
                left_idx = left_parent && left_parent.index(key)
                right_idx = right_parent && right_parent.index(key)

                id = {}
                id[:row] = right_row_id + 1
                id[:sibling_position] = right_idx + 1
                key_fields.each do |field_name|
                    id[field_name] = right_value[field_name]
                end
                if left_idx && right_idx
                    if include_moves
                        left_common = left_parent & right_parent
                        right_common = right_parent & left_parent
                        left_pos = left_common.index(key)
                        right_pos = right_common.index(key)
                        if left_pos != right_pos
                            # Move
                            diffs[key].merge!(id.merge!(:action => 'Move',
                                              :sibling_position => [left_idx + 1, right_idx + 1]))
                            #puts "Move #{left_idx} -> #{right_idx}: #{key}"
                        end
                    end
                    if include_updates && (changes = diff_row(left_value, right_value, diff_fields, case_sensitive))
                        diffs[key].merge!(id.merge(changes.merge(:action => 'Update')))
                        #puts "Change: #{key}"
                    end
                elsif include_adds && right_idx
                    # Add
                    diffs[key].merge!(id.merge(right_values[key].merge(:action => 'Add')))
                    #puts "Add: #{key}"
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
        # @param case_sensitive [Boolean] Whether field comparisons should be
        #   case sensitive or not.
        # @return [Hash<String, Array>] A Hash whose keys are the fields that
        #   contain differences, and whose values are a two-element array of
        #   [left/from, right/to] values.
        def diff_row(left_row, right_row, fields, case_sensitive)
            diffs = {}
            fields.each do |attr|
                right_val = right_row[attr]
                right_val = nil if right_val == ""
                left_val = left_row[attr]
                left_val = nil if left_val == ""
                if (case_sensitive && left_val != right_val) ||
                   (left_val.to_s.upcase != right_val.to_s.upcase)
                    diffs[attr] = [left_val, right_val]
                    #puts "#{attr}: #{left_val} -> #{right_val}"
                end
            end
            diffs if diffs.size > 0
        end

    end

end
