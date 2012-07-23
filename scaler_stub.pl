#!/usr/bin/perl

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use CGI;
use Getopt::Long;
use XML::SemanticDiff;
use Data::Dumper;
use File::Spec::Functions qw(catfile);
use File::Slurp;
use HelperMethods;
use Getopt::Long;
use Log::Log4perl qw(:easy);

#----------------------------------------------------------------------
# constants
#----------------------------------------------------------------------

use constant USAGE => <<HEREDOC;
Usage: $0 < tree.nexml
HEREDOC

use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};
use constant MOCK_INPUT_TREE_FILE => catfile('mock-data', 'pruner-output.nexml');
use constant MOCK_OUTPUT_TREE_FILE => catfile('mock-data', 'scaler-output.nexml');

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
unless (IS_CGI) {
    my $getopt_success = GetOptions('help' => \$help_opt);
    die USAGE unless $getopt_success;
    die USAGE if $help_opt;
}
my $query = join('',<STDIN>);
my $cgi = CGI->new();

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------

my $mock_input_tree = read_file(MOCK_INPUT_TREE_FILE);
my $mock_output_tree = read_file(MOCK_OUTPUT_TREE_FILE);

my $diff = XML::SemanticDiff->new();

if ($diff->compare($query, $mock_input_tree)) {
    HelperMethods::fatal(
        sprintf("%s\nError: This service only supports a mock input equivalent to the NeXML tree shown above.", $mock_input_tree), 
                IS_CGI, 400);
}

print $cgi->header(-status => 200, -type => 'application/xml') if IS_CGI;
print $mock_output_tree;
