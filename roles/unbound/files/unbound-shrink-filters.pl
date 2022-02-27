#!/usr/bin/perl -w

use strict;
use warnings;
use 5.010;

my %names = ();

while (<>) {
  chomp;
  my @labels = split /\./;
  my $rname = join("\t", reverse @labels);
  $names{$rname}++;
}

my $prefix = "\t";
foreach my $rname (sort(keys %names)) {
  next if rindex($rname, $prefix, 0) == 0;
  my $name = join('.', reverse split("\t", $rname));
  print $name, "\n";
  $prefix = "${rname}\t";
}
