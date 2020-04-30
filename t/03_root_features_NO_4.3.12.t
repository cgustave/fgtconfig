##################################
###                            ###
###  T E S T  S C E N A R I I  ###
###                            ###
###         ROOT VDOM          ###
###     ALL NO FEATURES        ###
###                            ###
##################################

# Test vdom features (yes/no) based on root vdom
# configuration used is cooked so all features report yes

use strict;
use warnings;
use Test::Simple tests => 49;

use fgtconfig ;

# Test file is based on 4.3.12 default configuration with :
# logdisk disabled
# config log disk setting
# set status disable  (default value is enable)

use constant CONFIG => 't/03_root_features_NO_4.3.12.conf' ;


# load and parse test configs
my $fgtconfig = fgtconfig->new(configfile => CONFIG) ;
#$fgtconfig->configfile(CONFIG) ;
$fgtconfig->parse() ;


################################################# ROOT ###########################################################

# Feature line 1
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'gre')		eq 'no',	'root: gre') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'pptp')		eq 'no',	'root: pptp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'l2tp')		eq 'no',	'root: l2tp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ssl')		eq 'no',	'root: ssl') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'dnstrans')	eq 'no',	'root: dnstrans') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'wccp')		eq 'no',	'root: wccp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'icap')		eq 'no',	'root: icap') ;

# Feature line 2
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip')		eq 'no',	'root: vip') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip_lb')		eq 'no',	'root: vip lb') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'vip_slb')	eq 'no',	'root: vip slb') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'centnat')	eq 'no',	'root: central nat') ;

# Feature line 3 (nat and tp common)
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'snat')			eq 'no',	'root: source nat') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ipsec')			eq 'no',	'root: ipsec') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'webproxy')		eq 'no',	'root: webproxy') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'wanopt')			eq 'no',	'root: wanopt') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'gtp')			eq 'no',	'root: gtp') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ssync')			eq 'no',	'root: session sync') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'client-reputation') 	eq 'no',	'root: client reputation') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'device-identification')	eq 'no',	'root: device identification') ;


# Feature line 4 (nat and tp common)
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'local_in_policy')	eq 'no',	'root: local in policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'anypolicy')		eq 'no',	'root: any policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'mcastpol')		eq 'no',	'root: multicast policies') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'geoaddr')		eq 'no',	'root: geo addresses') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fqdnaddr')		eq 'no',	'root: FQDN addresses') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'logdisc')		eq 'no',	'root: log disc') ;

# Auth line
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'local')		eq 'no',	'root: auth local') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fsso')		eq 'no',	'root: auth fsso') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ldap')		eq 'no',	'root: auth ldap') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'radius')		eq 'no',	'root: auth radius') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'tacacs')		eq 'no',	'root: auth tacacs') ;
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'fortitok')	eq 'no',	'root: auth fortitoken') ;

# Policy features
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'nb_policy')	eq '0',		'root : policies - number of policies');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'applist')	eq 'no',	'root : policies - application list');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ipssensor')	eq 'no',	'root : policies - ipssensor');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'av')		eq 'no',	'root : policies - av');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'webfilter')	eq 'no',	'root : policies - webfilter');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'shaping')	eq 'no',	'root : policies - shaping');

# Interface policy features
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'nb_interface_policy')			eq '0',		'root : interface policies - number of interface policies');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey => 'application-list-status')		eq 'no',	'root : interface policies - application list');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey => 'ips-DoS-status')			eq 'no',	'root : interface policies - ips DOS status');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'interface_policy', subkey => 'ips-sensor-status')		eq 'no',	'root : interface policies - ips sensor status');

# Routing features
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'prouting')	eq 'no',	'root : routing - policy routing');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'rip')		eq 'no',	'root : routing - rip');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'ospf')		eq 'no',	'root : routing - ospf');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'bgp')		eq 'no',	'root : routing - bgp');
ok ($fgtconfig->test ( object => 'vd', vdom => 'root', key => 'pim')		eq 'no',	'root : routing - pim');

# Ping server and MTU override
ok ($fgtconfig->test ( object => 'intfs', name => 'port2', key => 'gwdetect')         eq '', 'interface: ping server');
ok ($fgtconfig->test ( object => 'intfs', name => 'port2', key => 'mtu-override')     eq '', 'interface: MTU override');

# Interface allowaccess
ok ($fgtconfig->test ( object => 'intfs', name => 'port2', key => 'allowaccess')      eq '', 'interface: Allow access');

