# What is Phylotastic?

Phylotastic is an interoperable set of RESTful service interfaces for sharing and manipulating phylogenetic tree data.  The component services of the phylotastic are: taxonomic name resolution, tree store, tree pruner, and tree scaler. The component services connect to form an overall workflow that takes a list of species names as input and generates a minimal, scaled NeXML tree for those species as output. The reader may see the Phylotastic wiki at http://www.evoio.org/wiki/Phylotastic for more info about Phylotastic.

# This Project: Skeleton Implementation of Phylotastic in Perl

This directory provides stub implementations for each of the Phylotastic services that produce correct output for one particular example input (and fail with an error for any other input). The example inputs/outputs for the stub services link together such that one execution of the complete pruning/scaling workflow can be performed. In addition, there is also a "controller" service (controller.pl) that invokes the services in the correct sequence to perform the overall workflow. The controller script is the most logical starting point for people wishing to understand/use this project.

The overall purpose of the scripts in this project is to:

1. provide concrete documentation of the REST interfaces that were designed during the phylotastic hackathon
2. provide a framework to test for the correct behaviour of real phylotastic service implementations

To support the second goal, the controller script has command line switches to replace each of the stub service implementations with a real service.

# Component Services

Currently, the component services of Phylotastic are taxonomic name resolution, tree store, pruner, and scaler. Mock input/output data is provided for each stub service implementation, and each service may be invoked through either CGI or through the command line. Details for invoking each service are provided below. 

NOTE: It is necessary at some points in the workflow to extract specific data from a JSON file; an XPath-like utility script named jsonpath.pl has been provided for this purpose. Run $ ./jsonpath.pl --help for details.

## Controller Service

input file: mock-data/input-taxa-names.txt

output file: mock-data/pruner-output.nexml

CLI invocation:    

    # note: controller invokes component services through CGI, even when invoked from command line
    ./controller.pl < mock-data/input-taxa-names.txt
    # invoke with no args to use default input (species listed in input-taxa-names.txt)
    ./controller.pl

CGI invocation:    

    curl --data-urlencode species="$(perl -pe 'chomp if eof; s/\r?\n/,/' mock-data/input-taxa-names.txt)" http://phylotastic-wg.nescent.org/~benv/cgi-bin/controller.pl
    # invoke with no args to use default input (species listed in input-taxa-names.txt)
    curl http://phylotastic-wg.nescent.org/~benv/cgi-bin/controller.pl
                    
## Taxonomic Name Resolution (TNRS) Service

input: mock-data/input-taxa-names.txt

output: mock-data/tnrs-output.json 

CLI invocation: 

    ./tnrs_stub.pl < mock-data/input-taxa-names.txt

CGI invocation (2 steps):
     # generates JSON doc with polling URL: {"uri":"http://phylotastic-wg.nescent.org/~benv/cgi-bin/tnrs_stub.pl?poll=abc"}
     curl --data-urlencode query="$(perl -pe 'chomp if eof' mock-data/input-taxa-names.txt)" http://phylotastic-wg.nescent.org/~benv/cgi-bin/tnrs_stub.pl
     # generates final output (mock-data/tnrs-output.json)
     curl 'http://phylotastic-wg.nescent.org/~benv/cgi-bin/tnrs_stub.pl?poll=abc'

## Tree Store Service

input:

    # extracts species URIs from TNRS service output 
    ./jsonpath.pl --values $(cat mock-data/tnrs-output-uris.dpath) mock-data/tnrs-output.json 

output: mock-data/treestore-output.json

CLI invocation:

    ./jsonpath.pl --values $(cat mock-data/tnrs-output-uris.dpath) mock-data/tnrs-output.json | ./treestore_stub.pl

CGI invocation:

    curl $(./jsonpath.pl --values $(cat mock-data/tnrs-output-uris.dpath) mock-data/tnrs-output.json | perl -ne 'chomp; print "--data-urlencode taxa_uris=$_ "') http://phylotastic-wg.nescent.org/~benv/cgi-bin/treestore_stub.pl

## Pruner Service

input:

    # extracts tree URI from tree store service output and species URIs from TNRS service output
    cat <(./jsonpath.pl --keys '*' mock-data/treestore-output.json) <(./jsonpath.pl --values '/names/*/matches/*/uri' mock-data/tnrs-output.json)

output: mock-data/pruner-output.nexml

CLI invocation:

    cat <(./jsonpath.pl --keys '*' mock-data/treestore-output.json) <(./jsonpath.pl --values '/names/*/matches/*/uri' mock-data/tnrs-output.json) | ./pruner_stub.pl

CGI invocation:

    curl --data-urlencode tree_uri=$(./jsonpath.pl --keys '*' mock-data/treestore-output.json) $(./jsonpath.pl --values '/names/*/matches/*/uri' mock-data/tnrs-output.json | perl -ne 'chomp; print "--data-urlencode taxa_uris=$_ "') http://phylotastic-wg.nescent.org/~benv/cgi-bin/pruner_stub.pl

## Scaler Service

input: mock-data/pruner-output.nexml

output: mock-data/scaler-output.nexml

CLI invocation:

    ./scaler_stub.pl < mock-data/pruner-output.nexml

CGI invocation:

    curl --data-binary @mock-data/pruner-output.nexml http://phylotastic-wg.nescent.org/~benv/cgi-bin/scaler_stub.pl

