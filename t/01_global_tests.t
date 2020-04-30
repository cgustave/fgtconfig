##################################
###                            ###
###  T E S T  S C E N A R I I  ###
###                            ###
###        G L O B A L         ###
###                            ###
##################################

# Test for the top global section

use strict;
use warnings;
use Test::Simple tests => 13;

use fgtconfig ;

use constant CONFIG => 't/01_global_tests.conf' ;

# load and parse test configs
my $fgtconfig = fgtconfig->new(configfile => CONFIG) ;
$fgtconfig->configfile(CONFIG) ;
$fgtconfig->parse() ;

ok( $fgtconfig->test( object => 'cfg', key => 'plateform') eq 'FWF60B', 'plateform');
ok( $fgtconfig->test( object => 'cfg', key => 'version')   eq '4.00', 'version');
ok( $fgtconfig->test( object => 'cfg', key => 'type')      eq 'FW', 'type');
ok( $fgtconfig->test( object => 'cfg', key => 'build')     eq '334', 'build');
ok( $fgtconfig->test( object => 'glo', key => 'hostname')  eq 'FWF60B-CGUS', 'hostname');
ok( $fgtconfig->test( object => 'glo', key => 'ha_mode')   eq 'standalone', 'ha');

# Fortiguard
ok( $fgtconfig->test( object => 'glo', key => 'fgd_hostname') eq 'default', 'FGD hostname');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_central-mgmt-status')  eq 'no', 'FGD central management');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_webfilter-status')  eq 'no',	'FGD webfiltering status');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_antispam-status') eq 'no', 'FGD anti-spam status');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_avquery-status') eq 'no', 'FGD av query status');


# NAT route vdom global part
ok( $fgtconfig->test( object => 'vd', vdom => 'root', key => 'opmode')  eq 'nat', 'root: opmode nat');
ok( $fgtconfig->test( object => 'glo', key => 'warnings') eq 'FORTIWIFI ', 'root: warnings');

