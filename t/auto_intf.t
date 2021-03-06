#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Differences;
use lib 't';
use Test_Netspoc;

my ($topo, $title, $in, $out);

############################################################
$title = 'Auto interface of network';
############################################################

$topo = <<'END';
network:a = { ip = 10.0.0.0/24; }
router:r1 =  {
 managed;
 model = IOS,FW;
 routing = manual;
 interface:a = { ip = 10.0.0.1; hardware = e1; }
 interface:b1 = { ip = 10.1.1.1; hardware = e0; }
}
router:r2 =  {
 managed;
 model = IOS,FW;
 routing = manual;
 interface:a = { ip = 10.0.0.2; hardware = f1; }
 interface:b2 = { ip = 10.2.2.1; hardware = f0; }
}
network:b1 = { ip = 10.1.1.0/24; }
network:b2 = { ip = 10.2.2.0/24; }
router:u = { 
 interface:b1 = { ip = 10.1.1.2; }
 interface:b2 = { ip = 10.2.2.2; } 
 interface:b3 = { ip = 10.3.3.1; } 
}
network:b3 = { ip = 10.3.3.0/24; }
END

$in = $topo . <<'END';
service:test1 = {
 user = interface:[network:b1].[auto],
        interface:[network:b3].[auto];
 permit src = network:a; dst = user; prt = tcp 22;
}
END

$out = <<'END';
--r1
! [ ACL ]
ip access-list extended e1_in
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.1 eq 22
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.2 eq 22
 permit tcp 10.0.0.0 0.0.0.255 host 10.3.3.1 eq 22
 deny ip any any
--r2
! [ ACL ]
ip access-list extended f1_in
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.1 eq 22
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.2 eq 22
 permit tcp 10.0.0.0 0.0.0.255 host 10.3.3.1 eq 22
 deny ip any any
END

test_run($title, $in, $out);

############################################################
$title = 'Auto interface of router';
############################################################

$in = $topo . <<'END';
service:test2 = {
 user = interface:u.[auto];
 permit src = network:a; dst = user; prt = tcp 23;
}
END

$out = <<'END';
--r1
! [ ACL ]
ip access-list extended e1_in
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.2 eq 23
 permit tcp 10.0.0.0 0.0.0.255 host 10.2.2.2 eq 23
 deny ip any any
--r2
! [ ACL ]
ip access-list extended f1_in
 permit tcp 10.0.0.0 0.0.0.255 host 10.1.1.2 eq 23
 permit tcp 10.0.0.0 0.0.0.255 host 10.2.2.2 eq 23
 deny ip any any
END

test_run($title, $in, $out);

############################################################
$title = 'Auto interfaces in nested loop';
############################################################

$in = <<'END';
network:Serv = {ip = 10.10.0.0/20;}

router:ZT45 = {
 interface:Serv = {ip = 10.10.0.3; virtual = {ip = 10.10.1.2;}}
 interface:ZT45 = {ip = 10.21.7.14;}
}
network:ZT45 = {ip = 10.21.7.12/30;}

router:LV41 = {
 interface:Serv = {ip = 10.10.0.2; virtual = {ip = 10.10.1.2;}}
 interface:LV41 = {ip = 10.22.8.1;}
}
network:LV41 = {ip = 10.22.8.0/30;}

network:Trns = {ip = 10.24.1.20/30;}
network:Crss = {ip = 10.24.2.20/30;}

router:LV96 = {
 interface:Trns = {ip = 10.24.1.22;}
 interface:Crss = {ip = 10.24.2.22;}
 interface:LV96 = {ip = 10.22.8.22;}
}

router:ZT21 = {
 interface:Trns = {ip = 10.24.1.21;}
 interface:Crss = {ip = 10.24.2.21;}
 interface:ZT21 = {ip = 10.21.7.21;}
}
network:LV96 = {ip = 10.22.8.20/30;}
network:ZT21 = {ip = 10.21.7.20/30;}

router:Plus = {
 interface:LV41 = {ip = 10.22.8.2;}
 interface:LV96 = {ip = 10.22.8.21;}
 interface:Plus = {ip = 10.23.8.6;}
}
router:Base = {
 interface:ZT45	= {ip = 10.21.7.13;}
 interface:ZT21 = {ip = 10.21.7.22;}
 interface:Base = {ip = 10.23.7.6;}
}
network:Plus = {ip = 10.23.8.4/30;}
network:Base = {ip = 10.23.7.4/30;}
router:R5 = {
 interface:Plus = {ip = 10.23.8.5;}
 interface:Base = {ip = 10.23.7.5;}
 interface:G112 = {ip = 10.23.6.5;}
}

network:G112 = {ip = 10.23.6.4/30;}
router:FW = {
 managed;
 model = ASA;
 interface:G112 = {ip = 10.23.6.6; hardware = outside; }
 interface:Mgmt = {ip = 10.11.11.13; hardware = inside;}
}
network:Mgmt = {ip = 10.11.11.0/24;}

service:IPSEC = {
 user = interface:R5.[auto],
        interface:Base.[auto],
        interface:Plus.[auto],
        interface:ZT21.[auto], 
        interface:LV96.[auto],
        interface:ZT45.[auto],
        interface:LV41.[auto],
        ;
 permit	src = network:Mgmt;
	dst = user;
	prt = tcp 22;
}
END

# Expect
# only interface:G112 of router:R5
# and all interfaces of other routers.

$out = <<'END';
--FW
object-group network g0
 network-object host 10.10.0.2
 network-object host 10.10.0.3
 network-object host 10.21.7.13
 network-object host 10.21.7.14
 network-object host 10.21.7.21
 network-object host 10.21.7.22
 network-object host 10.22.8.1
 network-object host 10.22.8.2
 network-object host 10.22.8.21
 network-object host 10.22.8.22
 network-object host 10.23.6.5
 network-object host 10.23.7.6
 network-object host 10.23.8.6
 network-object host 10.24.1.21
 network-object host 10.24.1.22
 network-object host 10.24.2.21
 network-object host 10.24.2.22
access-list inside_in extended permit tcp 10.11.11.0 255.255.255.0 object-group g0 eq 22
access-list inside_in extended deny ip any any
access-group inside_in in interface inside
END

test_run($title, $in, $out);

############################################################
$title = 'Multiple interfaces talk to policy_distribution_point';
############################################################

$in = <<'END';
network:a = { ip = 10.0.0.0/24; host:netspoc = { ip = 10.0.0.10; } }
router:r1 =  {
 managed;
 model = IOS,FW;
 policy_distribution_point = host:netspoc;
 routing = manual;
 interface:a = { ip = 10.0.0.1; hardware = e1; }
 interface:b1 = { ip = 10.1.1.1; hardware = e0; }
}
router:r2 =  {
 managed;
 model = IOS,FW;
 routing = manual;
 interface:a = { ip = 10.0.0.2; hardware = e1; }
 interface:b1 = { ip = 10.1.1.2; hardware = e0; }
}
network:b1 = { ip = 10.1.1.0/24; }

service:test = {
 user = interface:r1.[auto];
 permit src = network:a; dst = user; prt = tcp 22;
}
END

$out = <<'END';
--r1
! [ IP = 10.0.0.1,10.1.1.1 ]
END

test_run($title, $in, $out);

############################################################
# Topology for multiple tests.
############################################################

$topo = <<'END';
network:x = { ip = 10.1.1.0/24; }
router:r = {
 model = IOS, FW;
 managed;
 interface:x = { ip = 10.1.1.1; hardware = e0; }
 interface:y = { ip = 10.2.2.2; hardware = e1; }
}
network:y = { ip = 10.2.2.0/24; }
END

############################################################
$title = 'Interface and auto interface in intersection';
############################################################

$in = $topo . <<'END';
service:test = {
 user = interface:r.[auto] &! interface:r.x;
 permit src = user; dst = network:y; prt = tcp 80;
}
END

$out = <<'END';
Error: Must not use interface:r.[auto] and interface:r.x together
 in intersection of user of service:test
Warning: Useless delete of interface:r.x in user of service:test
Error: Must not use interface:r.[auto] and interface:r.x together
 in intersection of user of service:test
Warning: Useless delete of interface:r.x in user of service:test
END

test_err($title, $in, $out);

############################################################
$title = 'Interface and auto interface in union';
############################################################

$in = $topo . <<'END';
group:g = interface:r.[auto], interface:r.x, network:y;
service:test = {
 user = group:g &! network:y;
 permit src = user; dst = network:y; prt = tcp 80;
}
END

# Must not trigger error message.
$out = <<'END';
END

test_err($title, $in, $out);

############################################################
$title = 'Interface and auto network interface';
############################################################

$in = $topo . <<'END';
service:test = {
 user = interface:[network:x].[auto] &! interface:r.x;
 permit src = user; dst = network:y; prt = tcp 80;
}
END

$out = <<'END';
Error: Must not use interface:[network:x].[auto] and interface:r.x together
 in intersection of user of service:test
Warning: Useless delete of interface:r.x in user of service:test
Error: Must not use interface:[network:x].[auto] and interface:r.x together
 in intersection of user of service:test
Warning: Useless delete of interface:r.x in user of service:test
END

test_err($title, $in, $out);

############################################################
$title = 'Auto interface and auto network interface';
############################################################

$in = $topo . <<'END';
service:test = {
 user = interface:[network:x].[auto] &! interface:r.[auto];
 permit src = user; dst = network:y; prt = tcp 80;
}
END

$out = <<'END';
Error: Must not use interface:[network:x].[auto] and interface:r.[auto] together
 in intersection of user of service:test
Warning: Useless delete of interface:r.[auto] in user of service:test
Error: Must not use interface:[network:x].[auto] and interface:r.[auto] together
 in intersection of user of service:test
Warning: Useless delete of interface:r.[auto] in user of service:test
END

test_err($title, $in, $out);

############################################################
$title = 'Non conflicting auto network interfaces';
############################################################

$in = $topo . <<'END';
service:test = {
 user = interface:[network:x].[auto] &! interface:[network:y].[auto];
 permit src = user; dst = network:y; prt = tcp 80;
}
END

$out = <<'END';
Warning: Useless delete of interface:[network:y].[auto] in user of service:test
Warning: Useless delete of interface:[network:y].[auto] in user of service:test
END

test_err($title, $in, $out);

############################################################
done_testing;
