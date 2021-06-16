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
use Test::Simple tests => 7;

use cfg_fgtconfig ;

use constant CONFIG => 't/01_global_4.3.12.conf' ;

# load and parse test configs
my $fgtconfig = cfg_fgtconfig->new(configfile => CONFIG, debug_level => 0) ;
$fgtconfig->parse() ;
$fgtconfig->analyse() ;

ok( $fgtconfig->cfg->plateform() eq 'FGVM64');
ok( $fgtconfig->cfg->version() eq '4.00', 'version');
ok( $fgtconfig->cfg->type() eq 'FW', 'type');
ok( $fgtconfig->cfg->build() eq '656', 'build');
ok( $fgtconfig->glo->dataGet(ruleId => 'system.global', key => 'hostname') eq 'Fortigate-VM64', 'hostname');
ok( $fgtconfig->glo->dataGet(ruleId => 'warn-central-mgmt-fmg', key => 'ip')  eq '172.31.18.238', 'fortimanager');
ok( $fgtconfig->glo->dataGet(ruleId => 'system.ha', key => 'mode') eq 'a-p', 'ha');
