#!/usr/bin/ruby

# get header
header = $stdin.gets
num_lines = 4000
of = nil
outfile = ""
filename = ARGV[0] || "split"

i = 0
$stdin.each { |line|
  if i % num_lines == 0 then
    of.close if of
    #outfile = "split-#{i}.csv"
    outfile = sprintf("#{filename}-%05d.csv",i)
    puts outfile
    of = File.new(outfile, "w")
    of << header
  end
  of << line
  i += 1
}

of.close