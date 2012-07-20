#!/usr/bin/perl

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use CGI;
use JSON;
use File::Slurp;
use Array::Utils qw(:all);
use File::Spec::Functions qw(catfile);
use HelperMethods; 
use Data::DPath 'dpath'; 
use Data::Dumper;
use Getopt::Long;

#----------------------------------------------------------------------
# constants
#----------------------------------------------------------------------

use constant USAGE => <<HEREDOC;
Usage 1:   $0 <taxa_uri_1> [<taxa_uri_2>] ...
Usage 2:   $0 < input-taxa-uris.txt
Example (Usage 1): $0 ' 'http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=9606' 

INPUT TAXA URIS FILE

An input taxa URIs file contains taxa URIs separated by newlines. 
Example:

--- BEGIN FILE ---
http://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=573081
http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=9597
http://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=180092
http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=9606
http://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=180362
http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=10117
http://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=180366
http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=10090
--- END FILE ---
HEREDOC

use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};
use constant TNRS_OUTPUT_FILE => catfile('mock-data', 'tnrs-output.json');
use constant TNRS_OUTPUT_URIS_DPATH_FILE => catfile('mock-data', 'tnrs-output-uris.dpath');
use constant TREESTORE_OUTPUT_FILE => catfile('mock-data', 'treestore-output.json');

#----------------------------------------------------------------------
# CGI/CLI parameter processing
#----------------------------------------------------------------------

my $help_opt = 0;

my $cgi = CGI->new();
if (IS_CGI) {
    @ARGV = $cgi->param('taxa_uris');
} else {
    my $getopt_success = GetOptions('help' => \$help_opt);
    die USAGE unless $getopt_success;
    die USAGE if $help_opt;
    @ARGV = split("\n", join('', <STDIN>)) unless @ARGV;
    die USAGE unless @ARGV;
}

my @taxa_uris = @ARGV;

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------

# extract taxa URIs from TNRS output
my $tnrs_output = read_file(TNRS_OUTPUT_FILE);
my $tnrs_data = JSON->new()->decode($tnrs_output);
my $uri_path = read_file(TNRS_OUTPUT_URIS_DPATH_FILE);
my @mock_input = dpath($uri_path)->match($tnrs_data);

my $mock_output = read_file(TREESTORE_OUTPUT_FILE);

if (array_diff(@taxa_uris, @mock_input)) {
    HelperMethods::fatal(
        sprintf("this service only supports a mock query for: (\n\t%s\n)", join(",\n\t", @mock_input)),
        IS_CGI,
        400
    );
}

print $cgi->header(-status => 200, -type => 'application/json') if IS_CGI;
print $mock_output;
