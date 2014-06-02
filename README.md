# CSV-Diff

CSV-Diff is a small library for performing diffs of CSV data.

Unlike a standard diff that compares line by line, and is sensitive to the
ordering of records, CSV-Diff identifies common lines by key field(s), and
then compares the contents of the fields in each line.

Data may be supplied in the form of CSV files, or as an array of arrays. The
diff process provides a fine level of control over what to diff, and can
optionally ignore certain types of changes (e.g. changes in position).

CSV-Diff is particularly well suited to data in parent-child format. Parent-
child data does not lend itself well to standard text diffs, as small changes
in the organisation of the tree at an upper level can lead to big movements
in the position of descendant records. By instead matching records by key,
CSV-Diff avoids this issue, while still being able to detect changes in
sibling order.


## Usage

CSV-Diff is supplied as a gem, and has no dependencies. To use it, simply:
```
gem install csv-diff
```

To compare two CSV files where the field names are in the first row of the file,
and the first field contains the unique key for each record, simply use:
```ruby
require 'csv-diff'

diff = CSVDiff.new(file1, file2)
```
The returned diff object can be queried for the differences that exist between
the two files, e.g.:
```ruby
puts diff.summary.inspect   # Summary of the adds, deletes, updates, and moves
puts diff.adds.inspect      # Details of the additions to file2
puts diff.deletes.inspect   # Details of the deletions to file1
puts diff.updates.inspect   # Details of the updates from file1 to file2
puts diff.moves.inspect     # Details of the moves from file1 to file2
puts diff.diffs.inspect     # Details of all differences

