#!/usr/bin/perl

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use CGI;
use JSON;
use Array::Utils qw(:all);
use File::Slurp;
use File::Spec::Functions qw(catfile);
use HelperMethods;
use Getopt::Long;

#----------------------------------------------------------------------
# constants
#----------------------------------------------------------------------

use constant USAGE => <<HEREDOC;
Usage 1: $0 <taxa_name_1> [<taxa_name_2>] ...
Usage 2: $0 < taxa-names.txt
Example (Usage 1): $0 'Rattus rattus' 'Mus musculus' 'Homo sapiens' 'Pan paniscus'

INPUT TAXA NAMES FILE:

An input taxa names file contains species names separated by newlines. 
Example:

--- BEGIN FILE ---
Rattus rattus
Mus musculus
Homo sapiens
Pan paniscus
--- END FILE ---

OPTIONS:

    --help      show this help message
HEREDOC

use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};

use constant MOCK_INPUT_FILE => catfile('mock-data', 'input-taxa-names.txt');
use constant MOCK_OUTPUT_FILE => catfile('mock-data', 'tnrs-output.json');
use constant MOCK_POLL_ID => 'abc';

#----------------------------------------------------------------------
# CGI/CLI parameter processing
#----------------------------------------------------------------------

my $help_opt = 0;

my $cgi = CGI->new();
if (IS_CGI) {
    @ARGV = split("\n", $cgi->param('query'));
} else {
    my $getopt_success = GetOptions('help' => \$help_opt);
    die USAGE unless $getopt_success;
    die USAGE if $help_opt;
    @ARGV = split("\n", join('', <STDIN>)) unless @ARGV;
    die USAGE unless @ARGV;
}

my @species = @ARGV;

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------

my $poll_id = $cgi->param('poll');

my @mock_species = split(/\s*\n\s*/, read_file(MOCK_INPUT_FILE));
my $mock_response = read_file(MOCK_OUTPUT_FILE);

unless (IS_CGI && $poll_id) {
    if (array_diff(@species, @mock_species)) {
        HelperMethods::fatal(
            sprintf('this service only supports a mock query for: \'%s\'', join(' \'', @mock_species)),
            IS_CGI,
            400
        );
    }
}

if (IS_CGI) {
    if ($poll_id) {
        unless ($poll_id eq MOCK_POLL_ID) {
            HelperMethods::fatal("no pending request for polling id $poll_id", IS_CGI, 400);
        }
        print $cgi->header(-status => 200, -type => 'application/json');
        print $mock_response;
        exit 0;
    } else {
        HelperMethods::fatal('request is missing \'query\' param', IS_CGI, 400) unless @species;
        my $poll_url = $cgi->url() . '?poll=' . MOCK_POLL_ID;
        print $cgi->header(-status => 200, -type => 'application/json');
        print "{\"uri\":\"$poll_url\"}"; 
    }
} else {
    print $mock_response;
}

