require 'test/unit'
require 'csv-diff'


class TestDiff < Test::Unit::TestCase

    DATA1 = [
        ['Parent', 'Child', 'Description'],
        ['A', 'A1', 'Account1'],
        ['A', 'A2', 'Account 2'],
        ['A', 'A3', 'Account 3'],
        ['A', 'A4', 'Account 4'],
        ['A', 'A6', 'Account 6']
    ]

    DATA2 = [
        ['Parent', 'Child', 'Description'],
        ['A', 'A1', 'Account1'],
        ['A', 'A2', 'Account2'],
        ['A', 'a3', 'ACCOUNT 3'],
        ['A', 'A5', 'Account 5'],
        ['B', 'A6', 'Account 6'],
        ['C', 'A6', 'Account 6c']
    ]

    def test_array_diff
        diff = CSVDiff.new(DATA1, DATA2, key_fields: [0, 1])
        #assert_equal(['Parent'], diff.left.parent_fields)
        #assert_equal(['Parent'], diff.right.parent_fields)
        #assert_equal(['Child'], diff.left.child_fields)
        #assert_equal(['Child'], diff.right.child_fields)
        assert_equal(2, diff.adds.size)
        assert_equal(1, diff.deletes.size)
        assert_equal(3, diff.updates.size)
    end


    def test_case_insensitive_diff
        diff = CSVDiff.new(DATA1, DATA2, key_fields: [0, 1], case_sensitive: false)
        assert_equal(2, diff.adds.size)
        assert_equal(1, diff.deletes.size)
        assert_equal(2, diff.updates.size)
    end


end
