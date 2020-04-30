#!/usr/bin/perl -w

use fgtconfig;

my $fgtconfig = fgtconfig->new(configfile => 'configsamples/FGT-5.4_labfw.conf') ;
$fgtconfig->parse() ;

#$fgtconfig->summary;

# Remove admin 'admin' password if found
my @scope = (undef, undef) ;

##print "\n* config system admin\n";
##$fgtconfig->scope_config(\@scope, 'config system admin') ;
##$fgtconfig->print_feedback;
##$fgtconfig->print_scope(\@scope);

##print "\n* edit \"admin\"\n";
##$fgtconfig->scope_edit(\@scope, 'edit "admin"');
##$fgtconfig->print_feedback;
##$fgtconfig->print_scope(\@scope);

##print "\n* set key comments\n";
##$fgtconfig->set_key(aref_scope => \@scope, key => 'comments', value => '"MyFirstComment"', nb_spaces => 8);
##$fgtconfig->print_feedback;
##$fgtconfig->print_scope(\@scope);
##$fgtconfig->print_config($scope[0],$scope[1]);

##print "\n* interface translate\n";
##$fgtconfig->interface_translate(src => 'port1', dst => '__port1__');
##$fgtconfig->print_config(60,70);
@scope = (undef, undef) ;
#$fgtconfig->print_config(1,undef);
$fgtconfig->scope_config(\@scope, 'config system snmp sysinfo') ;
#$fgtconfig->print_feedback();
$fgtconfig->delete_block(startindex => $scope[0], endindex => $scope[1]) ;
#$fgtconfig->print_config(1,undef);
$fgtconfig->save_config(filename => 'export.conf');


#print "\n* set key comments\n";
#$fgtconfig->set_key(\@scope,'comments','"MySecondComment"',2,8,NOTNESTED);
#$fgtconfig->print_feedback;
#$fgtconfig->print_scope(\@scope);
#$fgtconfig->print_config($scope[0],$scope[1]);



#print "\n* set key comments_2\n";
#$fgtconfig->set_key(\@scope,'comments_2','"This is me again"',3,8,NOTNESTED);
#$fgtconfig->print_feedback;
#$fgtconfig->print_scope(\@scope);
#$fgtconfig->print_config($scope[0],$scope[1]);
#$fgtconfig->get_key(\@scope, 'password','NOTNESTED');
#if ($fgtconfig->feedback('found')) {
#   print "found key=".$fgtconfig->feedback('key')." value=".$fgtconfig->feedback('value')." at index=".$fgtconfig->feedback('index')."\n" ;
   #$fgtconfig->delete(index => $fgtconfig->feedback('index'));
   #   }


$fgtconfig->summary;
#
