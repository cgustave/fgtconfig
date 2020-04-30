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
use Test::Simple tests => 14;

use fgtconfig ;

use constant CONFIG => 't/01_global_4.3.12.conf' ;

# load and parse test configs
my $fgtconfig = fgtconfig->new(configfile => CONFIG) ;
$fgtconfig->parse() ;

ok( $fgtconfig->test( object => 'cfg', key => 'plateform') eq 'FGVM64', 'plateform');
ok( $fgtconfig->test( object => 'cfg', key => 'version'	 ) eq '4.00', 'version');
ok( $fgtconfig->test( object => 'cfg', key => 'type')      eq 'FW', 'type');
ok( $fgtconfig->test( object => 'cfg', key => 'build')     eq '656', 'build');
ok( $fgtconfig->test( object => 'glo', key => 'hostname')  eq 'Fortigate-VM64',	'hostname');
ok( $fgtconfig->test( object => 'glo', key => 'fmg_ip')    eq '172.31.18.238',	'fortimanager');
ok( $fgtconfig->test( object => 'glo', key => 'ha_mode')   eq 'a-p', 'ha');

# Fortiguard
ok( $fgtconfig->test( object => 'glo', key => 'fgd_hostname')  eq 'MODIFIED',	'FGD hostname');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_central-mgmt-status') eq 'no','FGD central management');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_webfilter-status') eq 'no',	'FGD webfiltering status');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_antispam-status') eq 'no',	'FGD anti-spam status');
ok( $fgtconfig->test( object => 'glo', key => 'fgd_avquery-status')  eq 'no',	'FGD av query status');

# NAT route vdom global part
ok( $fgtconfig->test( object => 'vd', vdom => 'root', key => 'opmode')   eq 'nat', 'root: opmode nat');
ok( $fgtconfig->test( object => 'glo', key => 'warnings') =~ /CENTRAL_MGMT_FMG THROUGHPUT-OPT DAILY-RESTART LOG_LOCALDENY PH1_REKEY_DISABLE RST_SESSIONLESS_TCP TCP_OPT_DISABLE HA_MGMT_INTF HTTPS:444 SSH:2222 TELNET:2223/,'root: warnings');
