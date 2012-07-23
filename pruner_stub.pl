#!/usr/bin/perl

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use CGI;
use Array::Utils qw(:all);
use Getopt::Long;
use Data::Dumper;
use Data::DPath qw(dpath);
use File::Spec::Functions qw(catfile);
use File::Slurp;
use JSON;
use Getopt::Long;
use Log::Log4perl qw(:easy);

#----------------------------------------------------------------------
# constants
#----------------------------------------------------------------------

use constant USAGE => <<HEREDOC;
Usage 1:   $0 <tree_uri> <species_uri_1> [<species_uri_2>] ...
Usage 2:   $0 < input-uris.txt
Example: $0 \ 
    'http://www.evoio.org/wg/evoio/images/2/26/Bininda-emonds_2007_mammals.nex' \
    'http://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=180092' 

INPUT URIS FILE

An input URIs file contains URIs separated by newlines. The first
URI is the tree URI, and the remaining URIs are taxa URIs.

--- BEGIN FILE ---
http://www.evoio.org/wg/evoio/images/2/26/Bininda-emonds_2007_mammals.nex' 
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
use constant PRUNER_OUTPUT_FILE => catfile('mock-data', 'pruner-output.nexml');

#----------------------------------------------------------------------
# logging
#----------------------------------------------------------------------

# For debugging when owner of this script does not have read access to apache log.
#close STDERR or HelperMethods::fatal($!, IS_CGI, 500);         
#open STDERR, '>>/home/ben/temp/cgi.log' or HelperMethods::fatal($!, IS_CGI, 500);

Log::Log4perl::easy_init(IS_CGI ? $WARN : $INFO);

#----------------------------------------------------------------------
# argument processing
#----------------------------------------------------------------------

my $help_opt = 0;

my $cgi = CGI->new();

if (IS_CGI) {
    @ARGV = ($cgi->param('tree_uri'), $cgi->param('taxa_uris'));
} else {
    my $getopt_success = GetOptions('help' => \$help_opt);
    die USAGE unless $getopt_success;
    die USAGE if $help_opt;
    @ARGV = split("\n", join('', <STDIN>)) unless @ARGV;
    die USAGE unless (@ARGV >= 2);
}

my @query = @ARGV;

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------

my @mock_input = ();
my $json_parser = JSON->new();
my $data;

# extract first tree URI from treestore output
my $tree_store_output = read_file(TREESTORE_OUTPUT_FILE);
$data = $json_parser->decode($tree_store_output);
my $tree_uri = (keys %$data)[0];
push(@mock_input, $tree_uri);

# extract taxa URIs from TNRS output
my $tnrs_output = read_file(TNRS_OUTPUT_FILE);
$data = JSON->new()->decode($tnrs_output);
my $path = read_file(TNRS_OUTPUT_URIS_DPATH_FILE);
my @taxa_uris = dpath($path)->match($data);
push(@mock_input, @taxa_uris);

if (array_diff(@query, @mock_input)) {
    HelperMethods::fatal(
        sprintf("this service only supports a mock query for: tree_uri = %s, taxa_uris = (\n\t%s\n)", 
                $mock_input[0], join(",\n\t", @mock_input[1..$#mock_input]),
        IS_CGI,
        400
    ));
}

print $cgi->header(-status => 200, -type => 'application/xml') if IS_CGI;
print read_file(PRUNER_OUTPUT_FILE);
