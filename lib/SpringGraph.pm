package SpringGraph;

=head1 NAME

SpringGraph - Directed Graph alternative to GraphViz

=head1 SYNOPSIS

use SpringGraph qw(calculate_graph draw_graph);


## object oriented interface ##

my $graph = new SpringGraph;

# add a node to the graph  (with optional label)

$graph->add_node('Paris', label =>'City of Love');

# add an edge to the graph (with optional label)

$graph->add_edge('London' => 'New York', label => 'Far');

# output the graph to a file

$graph->as_png($filename);

# get the graph as GD image object

$graph->as_gd;

## procedural interface ##

my %node = (
	    london => { label => 'London (Waterloo)'},
	    paris => { label => 'Paris' },
	    brussels => { label => 'Brussels'},
	   );

my %link = (
	    london => { paris => 1 }, # bidirectional
	    paris => { brussels => 2 }, # unidirection from paris to brussels
	   );

my $graph = calculate_graph(\%node,\%link);

draw_graph($filename,\%node,\%link);

=head1 DESCRIPTION

SpringGraph.pm is a rewrite of the springgraph.pl script, which provides similar functionality to Neato and can read some/most dot files.

The goal of this module is to provide a compatible interface to VCG and/or GraphViz perl modules on CPAN. This module will also provide some extra features to provide more flexibility and power.

=head1 METHODS

=cut

use strict;
use Data::Dumper;
use GD;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(&calculate_graph &draw_graph);
our $VERSION = 0.02;

use constant PI => 3.141592653589793238462643383279502884197169399375105;

=head1 Class Methods

=head2 new

Constructor for the class, returns a new SpringGraph object

my $graph = SpringGraph->new;

=cut

sub new {
    my ($class) = @_;
    my $self = bless( {scale=> 1,nodes => {}, links=>{} }, ref $class || $class);
    return $self;
}

=head2 calculate_graph

returns a hashref of the nodes in the graph, populated with coordinates

my $graph = calculate_graph(\%node,\%link);

=cut

sub calculate_graph {
    my ($nodes,$links) = @_;
#    warn "calculate_graph called with : ", @_, "\n";
    my %node = %$nodes;
    my %link = %$links;
    my $scale = 1;

    my $push = 675;
    my $pull = .1;
    my $maxiter = 95;
    my $rate = 2;
    my $done = 0.3;
    my $continue = 1;
    my $iter = 0;
    my ($xmove,$ymove);
    my $movecount;

    foreach my $nodename (keys %$nodes) {
	$node{$nodename}{x}=rand;# $maxx;
	$node{$nodename}{'y'}=rand;# $maxy;
	$node{$nodename}{'label'} = $nodename unless(defined $node{$nodename}{'label'});
    }

    while($continue && ($iter <= $maxiter) ) {
	$continue = 0;
	$iter++;
	foreach my $nodename (keys %$nodes) {
	    $node{$nodename}{oldx} = $node{$nodename}{x};
	    $node{$nodename}{oldy} = $node{$nodename}{'y'};
	    $xmove = 0;
	    $ymove = 0;
	}

	foreach my $source (keys %$nodes) {
	    my $movecount = 0;
	    my ($pullmove,$pushmove);
	    foreach my $dest (keys %$nodes) {
		next if ($source eq $dest);
		my $xdist = $node{$source}{oldx} - $node{$dest}{oldx};
		my $ydist = $node{$source}{oldy} - $node{$dest}{oldy};
		my $dist = sqrt(abs($xdist)**2 + abs($ydist)**2);
		my $wantdist = $dist;
		if ($link{$source}{$dest} || $link{$dest}{$source}) {
		    next if ($dist <= 50 or $dist > 200);
		    $wantdist = $wantdist + ($push / $dist);
		    if ($link{$source}{$dest}) {
			$wantdist = $wantdist - ($pull * $dist);
		    }
		    if ($link{$dest}{$source}) {
			$wantdist = $wantdist - ($pull * $dist);
		    }
		} else {
		    $wantdist = $push * (0.65 - $pull);
		}
		my $percent = ($wantdist/$dist);
		my $wantxdist = ($xdist * $percent);
		my $wantydist = ($ydist * $percent ) + 45;
		$xmove += ($xdist - $wantxdist)*$rate;
		$ymove += ($ydist - $wantydist)*$rate;
		$movecount++;
		if ( $link{$source}{$dest} || $link{$dest}{$source} ) {
		    $pushmove = $push / $dist ;
		    $pullmove = $pull * $dist;
		}
	    }
	    $xmove = $xmove / $movecount;
	    $ymove = $ymove / $movecount;
	    $node{$source}{x} -= $xmove;
	    $node{$source}{'y'} -= $ymove;
	    if ($xmove >= $done or $ymove >= $done) {
		if ($xmove > $continue) {
		    $continue = $xmove;
		}
		if ($ymove > $continue) {
		    $continue = $ymove;
		}
	    }
	}
    }
    foreach my $source (keys %$nodes) {
	foreach my $color ('r', 'g', 'b') {
	    $node{$source}{$color} = 255 unless (defined $node{$source}{$color});
	}
    }
    return \%node;
}


=head2 draw_graph

outputs the graph as a png file either to the file specified by the filename or to STDOUT

takes filename, hashref of nodes and list of edges

draw_graph($filename,\%node,\%link);


=cut

sub draw_graph {
    my ($filename,$nodes,$links) = @_;
    &draw(1,$nodes,$links,filename=>$filename);
    return;
}

=head1 Object Methods

=head2 add_node

adds a node to a graph

takes the name of the node and any attributes such as label

# just like GraphViz.pm :)
$graph->add_node('Paris', label =>'City of Love');

=cut

sub add_node {
    my ($self,$name,%attributes) = @_;
    $self->{nodes}{$name} = { %attributes };
    return;
}

=head2 add_edge

adds an edge to a graph

takes the source and destination of the edge and any attributes such as label

# again just like GraphViz
$graph->add_edge('London' => 'New York', label => 'Far');

=cut

sub add_edge {
    my ($self,$source,$dest,%attributes) = @_;
    $self->{links}{$source}{$dest} = 2;
    $self->{nodes}{$source} ||= {};
    $self->{nodes}{$dest} ||= {};
    return;
}


=head2 as_png

prints the image of the graph in PNG format

takes an optional filename or outputs directly to STDOUT

$graph->as_png($filename);

=cut

sub as_png {
    my ($self,$filename) = @_;
    calculate_graph($self->{nodes},$self->{links});
    draw(1,$self->{nodes},$self->{links},filename=>$filename);
    return;
}

=head2 as_gd

returns the GD image object of the graph

my $gd_im = $graph->as_gd;

=cut

sub as_gd {
    my $self = shift;
    calculate_graph($self->{nodes},$self->{links});
    my $im = draw(1,$self->{nodes},$self->{links},gd=>1);
    return $im;
}

=head2 as_gd

returns the image of the graph in a string in the format specified or PNG

my $graph_png = $graph->as_image('png');

=cut

sub as_image {
    my ($self,$format) = @_;
    calculate_graph($self->{nodes},$self->{links});
    my $im = draw(1,$self->{nodes},$self->{links},image=>1,image_format=>$format);
    return $im;
}

################################################################################
# internal functions

sub draw {
    my ($scale,$nodes,$links,%options) = @_;
    my %node = %$nodes;
    my %link = %$links;

    my ($maxx,$maxy);
    my ($minx,$miny);
    my ($maxxlength,$minxlength);
    my ($maxylength,$minylength);
    my $margin = 20;
    my $nodesize = 40;
    my @point = ();

    foreach my $nodename (keys %node) {
#	warn "getting maxx/minx for $nodename\n";
#	warn Dumper($nodename=>$node{$nodename});
	if (!(defined $maxx) or (($node{$nodename}{x} + (length($node{$nodename}{'label'}) * 8 + 16)/2) > $maxx + (length($node{$nodename}{'label'}) * 8 + 16)/2)) {
	    $maxx = $node{$nodename}{x};
	    $maxxlength = (length($node{$nodename}{'label'}) * 8 + 16)/2;
	}
	if (!(defined $minx) or (($node{$nodename}{x} - (length($node{$nodename}{'label'}) * 8 + 16)/2) < $minx - (length($node{$nodename}{'label'}) * 8 + 16)/2)) {
	    $minx = $node{$nodename}{x};
	    $minxlength = (length($node{$nodename}{'label'}) * 8 + 16)/2;
	}

	$maxy = $node{$nodename}{'y'} if (!(defined $maxy) or $node{$nodename}{'y'} > $maxy);
	$miny = $node{$nodename}{'y'} if (!(defined $miny) or $node{$nodename}{'y'} < $miny);
    }

    foreach my $nodename (keys %node) {
	$node{$nodename}{x} = ($node{$nodename}{x} - $minx) * $scale + $minxlength -1 ;
	$node{$nodename}{'y'} = ($node{$nodename}{'y'} - $miny) * $scale + $nodesize/2 - 1;
    }

    $maxx = (($maxx - $minx) * $scale + $minxlength + $maxxlength) * 1.25;
    $maxy = (($maxy - $miny) * $scale + $nodesize/2*2 + 40) * 1.2;
    my $im = new GD::Image($maxx,$maxy);
    my $white = $im->colorAllocate(255,255,255);
    my $blue = $im->colorAllocate(0,0,255);
    my $powderblue = $im->colorAllocate(176,224,230);
    my $black = $im->colorAllocate(0,0,0);
    my $darkgrey = $im->colorAllocate(169,169,169);
    $im->transparent($white);	# make white transparent

    foreach my $node (keys %node) {
	my $color = $white;
	if (defined $node{$node}{r} and defined $node{$node}{g} and defined $node{$node}{b}) {
	    $color = $im->colorResolve($node{$node}{r}, $node{$node}{g}, $node{$node}{b});
	}
	if (defined $node{$node}{shape} and $node{$node}{shape} eq 'record') {
	    $node{$node}{boundary} = addRecordNode ($im,$node{$node}{x},$node{$node}{'y'},$node{$node}{'label'},$maxx,$maxy);
	} else {
	    addPlainNode($im,$node{$node}{x},$node{$node}{'y'},$node{$node}{'label'});
	}
    }

    # draw lines
    foreach my $source (keys %node) {
	my ($topy,$boty) = ($node{$source}{'y'} -20,$node{$source}{'y'} + 20);
	foreach my $dest (keys %{$link{$source}}) {
	    my ($destx,$desty) = ($node{$dest}{x},$node{$dest}{'y'}) ;
	    my ($sourcex,$sourcey) = ($node{$source}{x}, ( $node{$source}{'y'} < $node{$dest}{'y'} ) ? $boty : $topy );
	    if (defined $node{$dest}{boundary}) {
		$destx = ( $node{$source}{x} < $node{$dest}{x} )
		    ? $node{$dest}{boundary}[0] : $node{$dest}{boundary}[2] ;
		$desty = ( $node{$source}{'y'} < $node{$dest}{'y'} )
		    ? $node{$dest}{boundary}[1] : $node{$dest}{boundary}[3] ;
		$im->line($sourcex, $sourcey, $destx, $desty, $darkgrey);
	    } else {
		$desty = $node{$dest}{'y'};
		$im->line($sourcex,$sourcey, $destx, $desty, $darkgrey);
		addPlainNode($im,$node{$dest}{x},$node{$dest}{'y'},$node{$dest}{'label'});
	    }
	    if ($link{$source}{$dest} == 2) {
		addArrowHead ($im,$sourcex,$destx,$sourcey,$desty,$node{$dest}{shape},$node{$dest}{'label'});
	    }
	}
    }

    # output the image
    if ($options{gd}) {
	return $im;
    }
    if ($options{image}) {
	if ($im->can($options{image_format})) {
	    my $format = $options{image_format};
	    return $im->$format();
	} else {
	    return $im->png;
	}
    }
    if ($options{filename}) {
	open (OUTFILE,">$options{filename}") or die "couldn't open $options{filename} : $!\n";
	binmode OUTFILE;
	print OUTFILE $im->png;
	close OUTFILE;
    } else {
	binmode STDOUT;
	print $im->png;
    }
    return; # maybe we should return something.. nah
}


sub addRecordNode {
    my ($im,$x,$y,$string,$maxx,$maxy) = @_;
    my $white = $im->colorAllocate(255,255,255);
    my $blue = $im->colorAllocate(0,0,255);
    my $powderblue = $im->colorAllocate(176,224,230);
    my $black = $im->colorAllocate(0,0,0);
    my $darkgrey = $im->colorAllocate(169,169,169);
    my $red = $im->colorAllocate(255,0,0);

    # split text on newline, or |
    my @record_lines = split(/\s*([\n\|])\s*/,$string);

    my $margin = 3;
    my ($height,$width) = (0,0);
    foreach my $line (@record_lines) {
    LINE: {
	    if ($line eq '|') {
		$height += 4;
		last LINE;
	    }
	    if ($line eq "\n") {
		last LINE;
	    }
	    $height += 18;
	    my $this_width = get_width($line);
	    $width = $this_width if ($width < $this_width );
	} # end of LINE
    }

    $height += $margin * 2;
    $width += $margin * 2;

    my $topx = $x - ($width / 2);
    my $topy = $y - ($height / 3);
    $topy = 5 if ($topy <= 0);
    $topx = 5 if ($topx <= 0);

    if (($topy + $height ) > $maxy) {
	$topy = $maxy - $height;
    }

#    warn "height : $height, width : $width, start x : $topx, start y : $topy\n";

    # notes (gdSmallFont):
    # - 5px wide, 1px gap between words
    # - 2px up, 2px down, 6px middle

    $im->rectangle($topx,$topy,$topx+$width,$topy+$height,$black);
    $im->fillToBorder($x, $y, $black, $white);

    my ($curx,$cury) = ($topx + $margin, $topy + $margin);
    foreach my $line (@record_lines) {
	next if ($line =~ /\n/);
#	warn "line : $line \n";
	if ($line eq '|') {
	    $im->line($topx,$cury,$topx+$width,$cury,$black);
	    $cury += 4;
	} else {
	    $im->string(gdLargeFont,$curx,$cury,$line,$black);
	    $cury += 18;
	}
#	warn "current x : $curx, current y : $cury\n";
    }

    # Put a black frame around the picture
    my $boundary = [$topx,$topy,$topx+$width,$topy+$height];
    return $boundary;
}

sub get_width {
#    warn "get_width called with ", @_, "\n";
    my $string = shift;
    my $width = ( length ($string) * 9) - 2;
#    warn "width : $width\n";
    return $width;
}

sub addPlainNode {
    my ($im,$x,$y,$string,$color) = @_;
    my $white = $im->colorAllocate(255,255,255);
    my $blue = $im->colorAllocate(0,0,255);
    my $powderblue = $im->colorAllocate(176,224,230);
    my $black = $im->colorAllocate(0,0,0);
    my $darkgrey = $im->colorAllocate(169,169,169);

    $color ||= $white;
    $im->arc($x,$y,(length($string) * 8 + 16),40,0,360,$black);
    $im->fillToBorder($x, $y, $black, $color);
    $im->string( gdLargeFont, ($x - (length($string)) * 8 / 2), $y-8, $string, $black);
    return;
}


sub addArrowHead {
    my ($im,$sourcex,$destx,$sourcey,$desty,$nodetype,$nodetext) = @_;
    my @point = ();
    my $darkgrey = $im->colorAllocate(169,169,169);
    my $white = $im->colorAllocate(255,255,255);
    my $blue = $im->colorAllocate(0,0,255);
    my $powderblue = $im->colorAllocate(176,224,230);
    my $black = $im->colorAllocate(0,0,0);
    my $red = $im->colorAllocate(255,0,0);

    my $arrowlength = 10; # pixels
    my $arrowwidth = 10;
    my $height = (defined $nodetype and $nodetype eq 'record') ? 5 : 20 ;
    my $width = (defined $nodetype and $nodetype eq 'record') ? 5 : (length($nodetext) * 8 + 16)/2;;

    # I'm pythagorus^Wspartacus!
    my $xdist = $sourcex - $destx;
    my $ydist = $sourcey - $desty;
    my $dist = sqrt( abs($xdist)**2 + abs($ydist)**2 );
    my $angle = &acos($xdist/$dist);

    $dist = sqrt( ($height**2 * $width**2) / ( ($height**2 * (cos($angle)**2) ) + ($width**2 * (sin($angle)**2) ) ));

    my ($x,$y);
    my $xmove = cos($angle)*($dist+$arrowlength-3);
    my $ymove = sin($angle)*($dist+$arrowlength-3);

    if (defined $nodetype and $nodetype eq 'record') {
	$point[2]{x} = $xmove;
	$point[2]{'y'} = $ymove;

	$dist = 4;
	$xmove = $xmove + cos($angle)*$dist;
	$ymove = $ymove + sin($angle)*$dist;

	$angle = $angle + PI/2;
	$dist = $arrowwidth/2;
	$xmove = $xmove + cos($angle)*$dist;
	$ymove = $ymove + sin($angle)*$dist;

	$point[0]{x} = $xmove;
	$point[0]{'y'} = $ymove;

	$angle = $angle + PI;
	$dist = $arrowwidth;
	$xmove = $xmove + cos($angle)*$dist;
	$ymove = $ymove + sin($angle)*$dist;
	$point[1]{x} = $xmove;
	$point[1]{'y'} = $ymove;

	foreach my $num (0 .. 2) {
	    $point[$num]{'y'} = - $point[$num]{'y'} if $ydist < 0;
	}

	$im->line( $destx, $desty, $destx+$point[0]{x}, $desty+$point[0]{'y'}, $darkgrey );
	$im->line( $destx+$point[0]{x}, $desty+$point[0]{'y'}, $destx+$point[1]{x}, $desty+$point[1]{'y'}, $darkgrey );
	$im->line( $destx+$point[1]{x}, $desty+$point[1]{'y'},$destx, $desty, $darkgrey);

	$x = int(($point[1]{x} + $point[0]{x}) / 2.5);
	$y = int(($point[1]{'y'} + $point[0]{'y'}) / 2.5);
	#    $im->setPixel($destx + $x, $desty + $y, $red);

    } else {
        $dist = sqrt( abs($sourcex - $destx)**2 +  abs($sourcey-$desty)**2 );
	$xdist = $sourcex - $destx;
	$ydist = $sourcey - $desty;
	$angle = &acos($xdist/$dist);
        $dist = sqrt( ($height**2 * $width**2) / ( ($height**2 * (cos($angle)**2) ) + ($width**2 * (sin($angle)**2) ) ));
        $xmove = cos($angle)*$dist;
        $ymove = sin($angle)*$dist;

        $point[0]{x} = $xmove;
        $point[0]{'y'} = $ymove;

        $xmove = cos($angle)*($dist+$arrowlength-3);
	$ymove = sin($angle)*($dist+$arrowlength-3);
	$point[3]{x} = $xmove;
	$point[3]{'y'} = $ymove;

	$dist = 4;
	$xmove = $xmove + cos($angle)*$dist;
	$ymove = $ymove + sin($angle)*$dist;

	$angle = $angle + PI/2;
        $dist = $arrowwidth/2;
        $xmove = $xmove + cos($angle)*$dist;
        $ymove = $ymove + sin($angle)*$dist;

        $point[1]{x} = $xmove;
        $point[1]{'y'} = $ymove;
        $angle = $angle + PI;
        $dist = $arrowwidth;
        $xmove = $xmove + cos($angle)*$dist;
        $ymove = $ymove + sin($angle)*$dist;

        $point[2]{x} = $xmove;
        $point[2]{'y'} = $ymove;
        for my $num (0 .. 3)
        {
          $point[$num]{'y'} = - $point[$num]{'y'} if $ydist < 0;
        }
        $im->line($destx+$point[0]{x},$desty+$point[0]{'y'},$destx+$point[1]{x},$desty+$point[1]{'y'},$darkgrey);
        $im->line($destx+$point[1]{x},$desty+$point[1]{'y'},$destx+$point[2]{x},$desty+$point[2]{'y'},$darkgrey);
        $im->line($destx+$point[2]{x},$desty+$point[2]{'y'},$destx+$point[0]{x},$desty+$point[0]{'y'},$darkgrey);

	$x = int(($point[0]{x} + $point[1]{x} + $point[2]{x}) / 3.1);
	$y = int(($point[0]{'y'} + $point[1]{'y'}  + $point[2]{'y'}) / 3.1);
    }
#    $im->setPixel($destx + $x, $desty + $y, $red);
    $im->fillToBorder($destx + $x, $desty + $y, $darkgrey, $darkgrey);
    return;
}

# from perlfunc(1)
sub acos { atan2( sqrt(1 - $_[0] * $_[0]), $_[0] ) }

=head1 SEE ALSO

GraphViz

springgraph.pl

http://www.chaosreigns.com/code/springgraph/

GD

=head1 AUTHOR

Aaron Trevena, based on original script by 'Darxus'

=head1 COPYRIGHT

Original Copyright 2002 Darxus AT ChaosReigns DOT com

Amendments and further development copyright 2004 Aaron Trevena

This software is free software. It is made available and licensed under the GNU GPL.

=cut

################################################################################

1;

