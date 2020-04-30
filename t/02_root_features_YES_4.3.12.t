#################################
###                            ###
###  T E S T  S C E N A R I I  ###
###                            ###
###         ROOT VDOM          ###
###     ALL YES FEATURES       ###
###                            ###
##################################

# Test vdom features (yes/no) based on root vdom
# configuration used is cooked so all features report yes

use strict;
use warnings;
use Test::Simple tests => 41;

use fgtconfig ;

use constant CONFIG => 't/02_root_features_YES_4.3.12.conf' ;

# load and parse test configs
my $fgtconfig = fgtconfig->new(configfile => CONFIG ) ;
$fgtconfig->parse() ;


################################################# ROOT ###########################################################

# Feature line 1
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'gre')		eq 'YES',	'root: gre') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'pptp')		eq 'YES',	'root: pptp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'l2tp')		eq 'YES',	'root: l2tp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ssl')		eq 'YES',	'root: ssl') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'dnstrans') 	eq 'YES',	'root: dnstrans') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'wccp')		eq 'YES',	'root: wccp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'icap')		eq 'YES',	'root: icap') ;

# Feature line 2
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip')		eq 'YES',	'root: vip') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip_lb')		eq 'YES',	'root: vip lb') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip_slb')	eq 'YES',	'root: vip slb') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'centnat')	eq 'YES',	'root: central nat') ;

# Feature line 3 (nat and tp common)
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'snat')		eq 'YES',	'root: source nat') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key =>'ipsec')		eq 'YES',	'root: ipsec') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'webproxy')	eq 'YES',	'root: webproxy') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key =>'wanopt')		eq 'YES',	'root: wanopt') ;
# can't configure GTP on VM, skipped
#ok ($fgtconfig->{_VDOM}->{'root'}->{'gtp'}	eq 'YES',	'root: gtp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ssync')		eq 'YES',	'root: session sync') ;

# Feature line 4 (nat and tp common)
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'local_in_policy')	eq 'YES',	'root: local in policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'anypolicy')		eq 'YES',	'root: any policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'mcastpol')		eq 'YES',	'root: multicast policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'geoaddr')		eq 'YES',	'root: geo addresses') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fqdnaddr')		eq 'YES',	'root: FQDN addresses') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'logdisc')		eq 'YES',	'root: log disc') ;
# Problematic, may conder remiving
#ok ($fgtconfig->{_VDOM}->{'root'}->{'logmem'}		eq 'YES',	'root: log memory') ;

# Auth line
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'local')		eq 'YES',	'root: auth local') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fsso')		eq 'YES',	'root: auth fsso') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ldap')		eq 'YES',	'root: auth ldap') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'radius')		eq 'YES',	'root: auth radius') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'tacacs')		eq 'YES',	'root: auth tacacs') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fortitok')	eq 'YES',	'root: auth fortitoken') ;

# Policy features
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'nb_policy')	eq '4',		'root : policies - number of policies');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'applist')	eq 'YES',	'root : policies - application list');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ipssensor')	eq 'YES',	'root : policies - ipssensor');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'av')		eq 'YES',	'root : policies - av');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'webfilter')	eq 'YES',	'root : policies - webfilter');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'shaping')	eq 'YES',	'root : policies - shaping');

# Interface policy features
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'nb_interface_policy')						eq '1',		'root : interface policies - number of interface policies');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey =>'application-list-status')		eq 'YES',	'root : interface policies - application list');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey =>'ips-DoS-status')			eq 'YES',	'root : interface policies - ips DOS status');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey =>'ips-sensor-status')			eq 'YES',	'root : interface policies - ips sensor status');

# Ping server and MTU override
ok ($fgtconfig->test ( object => 'intfs', name => 'port3', key => 'gwdetect')		eq 'X',	'interface: ping server');
ok ($fgtconfig->test ( object => 'intfs', name => 'port3', key => 'mtu-override')	eq 'X',	'interface: MTU override');

# Interface allowaccess
ok ($fgtconfig->test ( object => 'intfs', name => 'port3', key => 'allowaccess')       eq 'p hs sh sp hp t f', 'interface: Allow access');

