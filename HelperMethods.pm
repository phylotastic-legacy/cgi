package HelperMethods;

use strict;
use warnings;

#----------------------------------------------------------------------
# imports
#----------------------------------------------------------------------

use JSON;
use CGI;

#----------------------------------------------------------------------
# helper routines
#----------------------------------------------------------------------

# extremely ad hoc method to extract URIs from JSON generated
# by tnrs service and tree store service

sub get_values_from_json
{
   my $json = shift;
}

sub get_taxa_uris_from_tnrs_output 
{
    my $json = shift;
    my %uris = get_uri_mappings_from_tnrs_output($json);
    return map(@$_, values %uris);
}

sub get_uri_mappings_from_tnrs_output 
{
    my $json = shift;
    my $data = JSON->new()->decode($json);
    my %uris = ();
    foreach my $name (@{$data->{names}}) {
        my $submitted_name = $name->{submittedName};
        foreach my $match (@{$name->{matches}}) {
            foreach my $uri ($match->{uri}) {
                $uris{$submitted_name} = [] unless exists $uris{$submitted_name};
                push(@{$uris{$submitted_name}}, $uri);
            }
        }
    }
    return %uris;
}


# a 'die' method that works in both CGI and commandline context
sub fatal 
{
    my ($msg, $is_cgi, $http_status) = @_; 
    if ($is_cgi) {
        $http_status ||= 500;
        print CGI->header(-status => $http_status, -type => 'text/plain');
        print $msg;
        exit 0;
    } else {
        die "$msg\n";
    }
}

1;
