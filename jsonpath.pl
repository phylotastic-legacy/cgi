#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use Data::DPath 'dpath';
use Data::Dumper;
use Getopt::Long;

use constant USAGE => <<'HEREDOC';
Usage 1: $0 [options] <path-expression> <input-json-file>
Usage 2: $0 [options] <path-expression>  # read JSON from STDIN

Note, the path syntax is not JSONPath, but rather the syntax 
used by the Perl module Data::DPath.  The input JSON file
must encode a single JSON object.

Example of a path: '/names/*/matches/*/uri'

OPTIONS:

    --values       output the value of each match on a separate line, without
                   any extra formatting. By default, the matches are printed 
                   as a single JSON array.  Note that this option is intended 
                   for paths that match simple scalar values (i.e. strings and numbers).  
                   Matches that are arrays or hashes will be omitted and a warning 
                   will be shown.

    --keys         output the key of each match. By default, the matches are printed 
                   as a single JSON array.  Note that this option is intended 
                   for paths that match hashes.  Matches that aren't hashes will be omitted 
                   and a warning will be shown.
                   
HEREDOC

my $values_opt = 0;
my $keys_opt = 0;
die USAGE unless GetOptions('values' => \$values_opt, 'keys' => \$keys_opt);
die USAGE unless @ARGV >= 1;
my $path = shift @ARGV;

my $json_parser = JSON->new();
$json_parser->pretty(1);
$json_parser->allow_nonref(1);

my $json = join('', <>);
my $data = $json_parser->decode($json);
my @results = dpath($path)->match($data);

if ($values_opt) {
    foreach my $result (@results) {
        if (ref($result)) {
            warn sprintf("Omitting match to hash/array, because of --values option. Match was: %s\n",
                $json_parser->encode($result));
            next;
        } 
        print "$result\n";
    }
} elsif ($keys_opt) {
    foreach my $result (@results) {
        if (ref($result) ne 'HASH') {
            warn sprintf("Omitting non-hash match, because of --keys option. Match was: %s\n",
                $json_parser->encode($result));
            next;
        } 
        print join("\n", keys %$result) . "\n";
    }
} else {
    print $json_parser->encode(\@results);
}
