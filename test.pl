#!/usr/bin/perl -w

use cfg_fgtconfig;

my $fgtconfig = cfg_fgtconfig->new(configfile => 'configsamples/FGT-5.4_labfw.conf') ;
$fgtconfig->parse() ;


print "\n* interface translate\n";
$fgtconfig->_interface_translate(src => 'port1', dst => '__port1__');

print "\n* remove all passwords\n";
my @scope = (1, $fgtconfig->cfg->max_lines);
$fgtconfig->delete_all_keys(aref_scope=>\@scope, key=>'password', nested=>'1');
$fgtconfig->delete_all_keys(aref_scope=>\@scope, key=>'passwd', nested=>'1');
$fgtconfig->delete_all_keys(aref_scope=>\@scope, key=>'psksecret', nested=>'1');
$fgtconfig->delete_all_keys(aref_scope=>\@scope, key=>'passphrase', nested=>'1');

print "\n* Print small extract\n";
$fgtconfig->cfg->print_config(60,70);

print "\n* Delete config system snmp sysinfo:\n" ;
@scope = (undef, undef) ;
$fgtconfig->cfg->scope_config(\@scope, 'config system snmp sysinfo') ;
$fgtconfig->delete_block(startindex => $scope[0], endindex => $scope[1]) ;
$fgtconfig->cfg->save_config(filename => '/tmp/export.conf');

print "\n* set key comments\n";
@scope = (undef, undef) ;
$fgtconfig->cfg->scope_config(\@scope, 'config firewall policy') ;
$fgtconfig->cfg->scope_edit(\@scope, '53') ;
my $comments = $fgtconfig->cfg->get_key(\@scope,'comments','0') ;
print "Found comments=\"$comments\", now set new comments \"changedcomment\"\n" ;
$fgtconfig->set_key(aref_scope=>\@scope,key=>'comments',value =>'"changedcomment"', index_increment=>2,nb_spaces=>8,nested=>NOTNESTED);
$fgtconfig->cfg->save_config(filename => '/tmp/export2.conf');

print "\n* Delete line \"set timezone\"\n";
@scope = (undef, undef) ;
$fgtconfig->cfg->scope_config(\@scope, 'config system global') ;
$fgtconfig->cfg->get_key(\@scope, 'timezone','0');
if ($fgtconfig->cfg->feedback('found')) {
   print "found key=".$fgtconfig->cfg->feedback('key')." value=".$fgtconfig->cfg->feedback('value')." at index=".$fgtconfig->cfg->feedback('index')."\n" ;
   $fgtconfig->cfg->delete(index => $fgtconfig->cfg->feedback('index'));
   }

$fgtconfig->cfg->save_config(filename => '/tmp/export3.conf');
$fgtconfig->summary;
#
