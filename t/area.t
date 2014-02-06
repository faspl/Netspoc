#!perl

use strict;
use Test::More;
use Test::Differences;
use lib 't';
use Test_Netspoc;

my ($title, $in, $out);

my $topo = <<END;
# a3 < a2 < all, a1 < all
area:all = { anchor = network:n1; }
area:a1 = { border = interface:asa1.n1; }
area:a2 = { border = interface:asa1.n2; }
area:a3 = { border = interface:asa2.n3; }

network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }

router:asa1 = {
 managed;
 model = ASA;
 interface:n1 = { ip = 10.1.1.1; hardware = vlan1; }
 interface:n2 = { ip = 10.1.2.1; hardware = vlan2; }
}

router:asa2 = {
 managed;
 model = ASA;
 interface:n2 = { ip = 10.1.2.2; hardware = vlan2; }
 interface:n3 = { ip = 10.1.3.2; hardware = vlan3; }
}
END

############################################################
$title = 'Overlapping areas';
############################################################

$in = <<END;
$topo
area:a2x = { border = interface:asa2.n2; }
END

$out = <<END;
Error: Overlapping area:a2 and area:a2x
END

test_err($title, $in, $out);

############################################################
$title = 'Duplicate areas';
############################################################

$in = <<END;
$topo
area:a2x = { border = interface:asa1.n2; }
END

$out = <<END;
Error: Duplicate area:a2 and area:a2x
END

test_err($title, $in, $out);

############################################################
done_testing;
