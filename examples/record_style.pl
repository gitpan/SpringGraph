#!/usr/bin/perl -w

####################################
# object oriented way (with records)

use strict;

use SpringGraph;

my $graph = new SpringGraph;
my $filename = 'testgraph_rec.png';

$graph->add_node('london', label=>'London (Waterloo)');
$graph->add_node('paris', label =>'Paris (Garde du Norde)');
#$graph->add_node('new york',label => "New York");
$graph->add_node('brussels',label => "Brussels|\nfoo\nbar", shape=>'record');
$graph->add_node('milan',label => "Milan|\nGucci\nPrada|ciao", shape=>'record');

$graph->add_edge(london=>'paris');
$graph->add_edge(paris=>'brussels');
#$graph->add_edge(london=>'new york');
#$graph->add_edge('new york'=>'london');

warn "..getting as png\n";

$graph->as_png($filename);


warn "all done\n";
