#!/usr/bin/perl

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use CGI;
use LWP::UserAgent;
use JSON;
use Log::Log4perl qw(:easy);
use HelperMethods;
use File::Spec::Functions qw(catfile);
use Data::DPath qw(dpath);
use File::Slurp;
use Getopt::Long;

#----------------------------------------------------------------------
# constants
#----------------------------------------------------------------------

use constant USAGE => <<HEREDOC;
Usage 1: $0 # run script with default input (shown below)
Usage 2: $0 <species_name_1> [<species_name_2>] ...
Example: $0 'Rattus rattus' 'Mus musculus' 'Homo sapiens' 'Pan paniscus'

Run the phylotastic chain of services for a given set of input species.  The services
will be invoked in the following order to produce a minimal tree for the input 
species with scaled branches:

(1) Taxonomic Name Resolution (dirty taxa names => taxa URIs)
(2) Tree Store (taxa URIs => URIs of trees with matching tips)
(3) Pruning (tree URI and taxa URIs => species-specific tree)
(4) Branch Length Estimation (species-specific tree => scaled species-specific tree)

Currently, in order to generate any output, the input set of species must be:

    'Rattus rattus'
    'Mus musculus'
    'Homo sapiens'
    'Pan paniscus'

This script uses stub implementations for the 4 services mentioned above.  When
these services are replaced with real implementations, the script should be able
to operate on any set of input species.

OPTIONS:

    --tnrs <URL>           replace the stub TNRS service with a real one
    --treestore <URL>      replace the stub tree store service with a real one
    --pruner <URL>         replace the stub pruner service with a real one
    --scaler <URL>         replace the stub scaler service with a real one
    --help                 show this help message

INVOKING THROUGH CGI:

When invoking this script through CGI, provide the species as a comma-separated 
list to the "species" parameter.  Other parameters have the same name as their 
corresponding command line options.  For example the "tnrs" parameter corresponds 
to the --tnrs option. Either HTTP GET or HTTP POST may be used for the invocation. 
HEREDOC

use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};
use constant URL_PREFIX => 'http://phylotastic-wg.nescent.org/~benv/cgi-bin/';
use constant TNRS_STUB_URL => URL_PREFIX . 'tnrs_stub.pl';
use constant TREESTORE_STUB_URL => URL_PREFIX . 'treestore_stub.pl';
use constant PRUNER_STUB_URL => URL_PREFIX . 'pruner_stub.pl';
use constant SCALER_STUB_URL => URL_PREFIX . 'scaler_stub.pl';
use constant MOCK_INPUT_SPECIES => ('Rattus rattus', 'Mus musculus', 'Homo sapiens', 'Pan paniscus');
use constant TNRS_OUTPUT_URIS_DPATH_FILE => catfile('mock-data', 'tnrs-output-uris.dpath');

#----------------------------------------------------------------------
# global vars
#----------------------------------------------------------------------

my $json_parser = JSON->new();
my $http = LWP::UserAgent->new();

#----------------------------------------------------------------------
# logging
#----------------------------------------------------------------------

Log::Log4perl->easy_init($INFO);

#----------------------------------------------------------------------
# argument processing
#----------------------------------------------------------------------

my $tnrs_url = TNRS_STUB_URL;
my $treestore_url = TREESTORE_STUB_URL;
my $pruner_url = PRUNER_STUB_URL;
my $scaler_url = SCALER_STUB_URL;
my $help_opt = 0;

my $cgi = CGI->new();

if (IS_CGI) {
    $tnrs_url = $cgi->param('tnrs') if $cgi->param('tnrs');
    $treestore_url = $cgi->param('treestore') if $cgi->param('treestore');
    $pruner_url = $cgi->param('pruner') if $cgi->param('pruner');
    $scaler_url = $cgi->param('scaler') if $cgi->param('scaler');
    @ARGV = split(',', $cgi->param('species'));
} else {
    my $getopt_success = GetOptions(
        'tnrs=s' => \$tnrs_url,
        'treestore=s' => \$treestore_url,
        'pruner=s' => \$pruner_url,
        'scaler=s' => \$scaler_url,
        'help' => \$help_opt,
    );
    die USAGE unless $getopt_success;
    if ($help_opt) {
        warn USAGE; 
        exit 0;
    }
}

if (@ARGV == 0) {
    INFO(sprintf('running script with mock input: (\'%s\')', join("', '", MOCK_INPUT_SPECIES)));
    @ARGV = MOCK_INPUT_SPECIES;
}

my @species = @ARGV;

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------

INFO(sprintf('invoking taxonomic name resolution service @ %s', $tnrs_url));
my @taxa_uris = do_tnrs(@species);

unless (@taxa_uris) {
    HelperMethods::fatal('TNRS failed to map input species to one or more taxa URIs', IS_CGI, 500);         
}

INFO(sprintf('querying tree store for trees with one or more matching tips @ %s', $treestore_url));
my @tree_uris = find_trees(@taxa_uris);
INFO(sprintf("tree store returned %d matching tree URIs: %s", scalar(@tree_uris), join(", ", @tree_uris)));

unless (@tree_uris) {
    HelperMethods::fatal('treestore did not return any matches for input taxa URIs', IS_CGI, 500);         
}

INFO(sprintf('invoking pruner service %d times (once per megatree) @ %s', scalar(@tree_uris), $pruner_url));
my @pruned_trees = map(prune_tree($_, @taxa_uris), @tree_uris);
INFO(sprintf('pruner service pruned %d trees', scalar(@pruned_trees)));

INFO(sprintf('invoking scaler service %d times (once per pruned tree) @ %s', scalar(@pruned_trees), $scaler_url));
my @scaled_trees = map(scale_tree($_), @pruned_trees);
INFO(sprintf('scaler service scaled %d trees', scalar(@pruned_trees)));

if (@scaled_trees > 1) {
    WARN('script/service does not yet support returning multipart output, returning only first scaled tree');
}

print $cgi->header(-status => 200, -type => 'application/xml') if IS_CGI;
print $scaled_trees[0];

#----------------------------------------------------------------------
# helper routines
#----------------------------------------------------------------------

sub do_tnrs {

    my @species = @_;

    # build request URL
    my $request_url = URI->new($tnrs_url);
    $request_url->query_form(query => join("\n", @species));

    # submit request
    INFO("HTTP GET: $request_url");
    my $response = $http->get($request_url);
    HelperMethods::fatal($response->status_line, IS_CGI, 500) unless ($response->is_success);

    # poll until job completed
    my $json;
    my $poll_url;
    while (1) {
        $json = $json_parser->decode($response->decoded_content());
        last unless (ref($json) eq 'HASH' && $json->{uri});
        $poll_url = $json->{uri};
        INFO("polling TNRS service: $poll_url");
        $response = $http->get($poll_url);
        HelperMethods::fatal($response->status_line, IS_CGI, 500) unless ($response->is_success);
    } 
    unless (ref($json) eq 'HASH' && $json->{names} && ref($json->{names}) eq 'ARRAY') {
        HelperMethods::fatal('JSON returned by TNRS has unexpected structure', IS_CGI, 500);
    }

    # extract taxa URIs from TNRS output
    my $path = read_file(TNRS_OUTPUT_URIS_DPATH_FILE);
    return dpath($path)->match($json);
}

sub find_trees {

    my @taxa_uris = @_;

    # build request URL
    my $request_url = URI->new($treestore_url);
    my @params = map(('taxa_uris' => $_), @taxa_uris);
    $request_url->query_form(@params);

    # do request
    INFO("HTTP GET: $request_url");
    my $response = $http->get($request_url);
    HelperMethods::fatal($response->status_line, IS_CGI, 500) unless ($response->is_success);

    # extract tree URIs from returned JSON
    my $json = $json_parser->decode($response->decoded_content());
    HelperMethods::fatal('JSON returned by tree store service has unexpected structure', IS_CGI, 500) unless (ref($json) eq 'HASH');
    my @tree_uris = keys %$json;

    return (keys %$json);
}

sub prune_tree {

    my ($tree_uri, @taxa_uris) = @_;

    # build request URL
    my $request_url = URI->new($pruner_url);
    my @params = (map(('taxa_uris' => $_), @taxa_uris));
    push(@params, 'tree_uri' => $tree_uri);
    $request_url->query_form(@params);

    # do request
    INFO("HTTP GET: $request_url");
    my $response = $http->get($request_url);
    HelperMethods::fatal($response->status_line, IS_CGI, 500) unless ($response->is_success);

    return $response->decoded_content();
}

sub scale_tree {

    my $nexml_tree = shift;

    INFO(sprintf('HTTP POST to: %s', $scaler_url));
    my $response = $http->post($scaler_url, Content => $nexml_tree);
    HelperMethods::fatal($response->status_line, IS_CGI, 500) unless ($response->is_success);

    return $response->decoded_content();
}

