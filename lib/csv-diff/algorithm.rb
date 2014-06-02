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
        def diff_sources(left, right, key_fields, diff_fields, options = {})
            left_index = left.index
            left_values = left.lines
            left_keys = left_values.keys
            right_index = right.index
            right_values = right.lines
            right_keys = right_values.keys
            parent_fields = left.parent_fields.length

            include_moves = options.fetch(:include_moves, true)
            include_deletes = options.fetch(:include_deletes, true)

            diffs = Hash.new{ |h, k| h[k] = {} }
            right_keys.each_with_index do |key, right_row_id|
                key_vals = key.split('~')
                parent = key_vals[0...parent_fields].join('~')
                child = key_vals[parent_fields..-1].join('~')
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
                    if changes = diff_row(left_values[key], right_values[key], diff_fields)
                        diffs[key].merge!(id.merge(changes.merge(:action => 'Update')))
                        #puts "Change: #{key}"
                    end
                elsif right_idx
                    # Add
                    diffs[key].merge!(id.merge(right_values[key].merge(:action => 'Add')))
                    #puts "Add: #{key}"
                end
            end

            # Now identify deletions
            if include_deletes
                (left_keys - right_keys).each do |key|
                    # Delete
                    key_vals = key.split('~')
                    parent = key_vals[0...parent_fields].join('~')
                    child = key_vals[parent_fields..-1].join('~')
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
                    diffs[key].merge!(id.merge(:action => 'Delete'))
                    #puts "Delete: #{key}"
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
        # @return [Hash<String, Array>] A Hash whose keys are the fields that
        #   contain differences, and whose values are a two-element array of
        #   [left/from, right/to] values.
        def diff_row(left_row, right_row, fields)
            diffs = {}
            fields.each do |attr|
                right_val = right_row[attr]
                right_val = nil if right_val == ""
                left_val = left_row[attr]
                left_val = nil if left_val == ""
                if left_val != right_val
                    diffs[attr] = [left_val, right_val]
                    #puts "#{attr}: #{left_val} -> #{right_val}"
                end
            end
            diffs if diffs.size > 0
        end

    end

end
