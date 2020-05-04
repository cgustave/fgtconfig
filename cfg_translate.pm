# ****************************************************
# *                                                  *
# *             T R A N S L A T E                    *
# *                                                  *
# *  Fortigate KVM converter for lab tests           *
# *                                                  *
# *  Framework : fgtconfig                           *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************

package cfg_translate ;
my $obj = "cfg_translate" ;

use Moose ;
extends('cfg_fgtconfig') ;

use strict ;
use warnings ;
use XML::LibXML ;
use lib "." ;

# the XML transform file with all transforms actions to process

has 'transform' => (
   isa      => 'Str',
   is       => 'rw',
   required => '1',
) ;

# ---

sub BUILD {
   my $subn = "BUILD" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn debug_level=" . $self->debug_level() if $self->debug_level() ;

   # object debug masks
   # 1  : translate
   # 2  : fgtconfig
   # 4  : cfg_dissector
   # 8  : cfg_interfaces
   # 16 : cfg_global
   # 32 : cfg_vdom
   # 64 : cfg_display
   # 128 : cfg_statistics

   # Set debug for ourself if & 2
   $self->debug(1) if ($self->debug_level & 1) ;

   }

# ---

sub start {
   my $subn = "start" ;

   my $self = shift ;

   print "\nStarting translation of " . $self->configfile . " based on transform " . $self->transform . "\n" ;

   print "   o load configuration\n" ;

   # Read-only
   $self->parse() ;

   print "   o summary :\n\n" ;
   $self->summary() ;

   $self->load_transform() ;

   # Header transform
   $self->header_transform() ;

   # Configuration modification
   $self->global_transforms() ;

   # Interfaces translations
   $self->interfaces_processing() ;
   $self->interfaces_post_processing() ;

   # All vdoms
   $self->all_vdoms_processing() ;

   # Save configuration
   $self->save() ;
   }

# ---

sub load_transform {
   my $subn = "load_transform" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   print "   o load transform file : " . $self->transform . "\n" ;
   $self->XMLTrsf(new XML::LibXML->load_xml(location => $self->transform)) or die "Cannot open transform XML file " . $self->transform ;

   # TODO : Optional validation of the file could be done here

   # Provide transform to fgtconfig
   $self->XMLTrsf($self->XMLTrsf) ;
   }

# ---

sub header_transform {
   my $subn = "header_transform" ;
   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   my $hdr = $self->get(index => 1) ;

   if (
      (my $platform) =
      $hdr =~ /
      (?:\#config-version=)
      (\S{6})
      (?:-)
      /x
     )
   {

      warn "$obj:$subn platform=$platform" if $self->debug ;

      # Replace platform with FGVMK6
      $hdr =~ s/$platform/FGVMK6/ ;

      # Replacing whichever admin user with admin
      $hdr =~ s/:user=(\S+)/:user=admin/g ;
      warn "$obj:$subn transformed header=$hdr" if $self->debug ;

      # save header
      chomp($hdr) ;
      $self->replace(index => 1, content => $hdr . "\n") ;
      }

   else {
      die "unrecognised header format" ;
      }
   }

# ---

sub global_transforms {
   my $subn = "global_transforms" ;

   # All config transform appluying globally
   # defined in XML <global> section

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # <system_global admintimeout="475" alias="HUB2" gui-theme="neutrino" admin-port="80" admin-sport="443" admin-ssh-port="22" timezone="28"/>
   my $admintimeout = $self->XMLTrsf->findvalue('/transform/global/system_global/@admintimeout') ;
   my $alias        = $self->XMLTrsf->findvalue('/transform/global/system_global/@alias') ;
   my $guitheme     = $self->XMLTrsf->findvalue('/transform/global/system_global/@gui-theme') ;
   my $adminport    = $self->XMLTrsf->findvalue('/transform/global/system_global/@admin-port') ;
   my $adminsport   = $self->XMLTrsf->findvalue('/transform/global/system_global/@admin-sport') ;
   my $adminsshport = $self->XMLTrsf->findvalue('/transform/global/system_global/@admin-ssh-port') ;
   my $timezone     = $self->XMLTrsf->findvalue('/transform/global/system_global/@timezone') ;
   if (($admintimeout ne "") or ($alias ne "") or ($guitheme ne "")) {
      $self->global_system_global(admintimeout=>$admintimeout, alias=>$alias, guitheme=>$guitheme, timezone=>$timezone,
	                              adminport=>$adminport, adminsport=>$adminsport, adminsshport=>$adminsshport) ;
      }

   #  <system_admin password="unset" />
   my $password     = $self->XMLTrsf->findvalue('/transform/global/system_admin/@password') ;
   my $trustedhost  = $self->XMLTrsf->findvalue('/transform/global/system_admin/@trustedhost'); 
   $self->global_system_admin($password, $trustedhost) if (($password ne "") or ($trustedhost ne "")) ;

   # <system_dns primary="8.8.8.8" source-ip="unset" />
   my $primary   = $self->XMLTrsf->findvalue('/transform/global/system_dns/@primary') ;
   my $secondary = $self->XMLTrsf->findvalue('/transform/global/system_dns/@secondary') ;
   my $source_ip = $self->XMLTrsf->findvalue('/transform/global/system_dns/@source-ip') ;
   $self->global_system_dns($primary, $secondary, $source_ip)
     if (($primary ne "") or ($secondary ne "") or ($source_ip ne "")) ;

   # remove hardware-switch
   my $hswitch_action = $self->XMLTrsf->findvalue('/transform/global/system_physical-switch/@action') ;
   $self->global_system_physical_switch_remove() if ($hswitch_action eq "remove") ;

   # remove virtual-switch
   my $vswitch_action = $self->XMLTrsf->findvalue('/transform/global/system_virtual-switch/@action') ;
   $self->global_system_virtual_switch_remove() if ($vswitch_action eq "remove") ;

   # <system_ha password="unset" group-id="7" />
   my $ha_password = $self->XMLTrsf->findvalue('/transform/global/system_ha/@password') ;
   my $ha_group_id = $self->XMLTrsf->findvalue('/transform/global/system_ha/@group-id') ;
   my $ha_monitor  = $self->XMLTrsf->findvalue('/transform/global/system_ha/@monitor') ;
   $self->global_system_ha($ha_password, $ha_group_id, $ha_monitor)
     if (($ha_group_id ne "") or ($ha_password ne "") or ($ha_monitor ne "")) ;

   # central management fmg-source-ip
   my $cm_fmg_source_ip = $self->XMLTrsf->findvalue('/transform/global/system_central-management/@fmg-source-ip') ;
   my $cm_type          = $self->XMLTrsf->findvalue('/transform/global/system_central-management/@type') ;
   $self->global_system_central_management($cm_type, $cm_fmg_source_ip)
     if (($cm_fmg_source_ip ne "") or ($cm_type ne "")) ;

   # fortianalyzer setting
   my $faz_status    = $self->XMLTrsf->findvalue('/transform/global/log_fortianalyzer_setting/@status') ;
   my $faz_server    = $self->XMLTrsf->findvalue('/transform/global/log_fortianalyzer_setting/@server') ;
   my $faz_source_ip = $self->XMLTrsf->findvalue('/transform/global/log_fortianalyzer_setting/@source-ip') ;
   $self->global_log_fortianalyzer_setting($faz_status, $faz_server, $faz_source_ip)
     if (($faz_status ne "") or ($faz_server ne "") or ($faz_source_ip ne "")) ;

   # system ntp
   my $ntp_ntpsync   = $self->XMLTrsf->findvalue('/transform/global/system_ntp/@ntpsync') ;
   my $ntp_server    = $self->XMLTrsf->findvalue('/transform/global/system_ntp/@server') ;
   my $ntp_source_ip = $self->XMLTrsf->findvalue('/transform/global/system_ntp/@source-ip') ;
   $self->global_system_ntp($ntp_ntpsync, $ntp_server, $ntp_source_ip)
     if (($ntp_ntpsync ne "") or ($ntp_server ne "") or ($ntp_source_ip ne "")) ;

   # Netflow
   my $netflow_collector_ip = $self->XMLTrsf->findvalue('/transform/global/system_netflow/@collector-ip') ;
   my $netflow_source_ip    = $self->XMLTrsf->findvalue('/transform/global/system_netflow/@source-ip') ;
   $self->global_system_netflow($netflow_collector_ip, $netflow_source_ip)
     if (($netflow_collector_ip ne "") or ($netflow_source_ip ne "")) ;
   }

# ---

sub global_system_global {
   my $subn = "global_system_global" ;

   my $self         = shift ;
   my %options      = @_ ;
   my $admintimeout = $options{'admintimeout'} ;
   my $alias        = $options{'alias'} ;
   my $guitheme     = $options{'guitheme'} ;
   my $adminsshport = $options{'adminsshport'} ;
   my $adminsport   = $options{'adminsport'} ; 
   my $adminport    = $options{'adminport'} ;
   my $timezone     = $options{'timezone'} ;
   
   warn "\n*Enter $obj:$subn with admintimeout=$admintimeout and alias=$alias guitheme=$guitheme adminsshport=$adminsshport adminsport=$adminsport adminport=$adminport timezone=$timezone" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system global') ;

   if ($self->cfg->feedback('found')) {

      if ($admintimeout ne "") {
         print "   o set admintimeout $admintimeout\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'admintimeout',
            value           => $admintimeout,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

      if ($alias ne "") {
         print "   o set alias $alias\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'alias',
            value           => $alias,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

      if ($guitheme ne "") {

         die "gui-theme can only be 'green*|neutrino|blue|melongene|mariner' but not $guitheme"
		   if $guitheme !~ /green|neutrino|blue|melongene|mariner/;

         print "   o set gui-them $guitheme\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'gui-theme',
            value           => $guitheme,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

	  if ($adminport ne "") {
	     die "$adminport must be an integer" if ($adminport !~ /\d+/);
	     print "   o set admin-port $adminport\n";
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'admin-port',
            value           => $adminport,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

	  if ($adminsport ne "") {
	     die "$adminsport must be an integer" if ($adminsport !~ /\d+/);
	     print "   o set admin-sport $adminsport\n";
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'admin-sport',
            value           => $adminsport,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

	  if ($adminsshport ne "") {
	     die "$adminsshport must be an integer" if ($adminsshport !~ /\d+/);
	     print "   o set admin-sshport $adminsshport\n";
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'admin-ssh-port',
            value           => $adminsshport,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

	  if ($timezone ne "") {
	     die "$timezone must be an integer" if ($timezone !~ /\d+/);
	     print "   o set timezone $timezone\n";
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'timezone',
            value           => $timezone,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }


      }
   }

# ---

sub global_system_physical_switch_remove {
   my $subn = "global_system_physical_switch_remove" ;

   my $self     = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;
   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system physical-switch') ;
   if ($self->cfg->feedback('found')) {
	   $self->cfg->delete_block(startindex => $scope[0], endindex=>$scope[1]) ;
	   print "   o Deleting physical-switch\n";
      }
   else {
	  print "   ! Could not found physical-switch configuration\n";
      }
   }

# ---

sub global_system_virtual_switch_remove {
   my $subn = "global_system_virtual_switch_remove" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;
   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system virtual-switch') ;
   if ($self->cfg->feedback('found')) {
	   $self->cfg->delete_block(startindex => $scope[0], endindex=>$scope[1]) ;
	   print "   o Deleting virtual-switch\n";
      }
   else {
	  print "   ! Could not found virtual-switch configuration\n";
      }
   }

# ---

sub global_system_admin {
   my $subn = "global_system_admin" ;

   my $self        = shift ;
   my $password    = shift ;
   my $trustedhost = shift ;

   warn "\n* Entering $obj:$subn with password=$password trustedhost=$trustedhost" if $self->debug ;
   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system admin') ;
   $self->cfg->scope_edit(\@scope, 'edit "admin"') ;

   if ($self->cfg->feedback('found')) {

      if ($password eq 'unset') {
         print "   o unset admin password\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'password') ;
         }
      elsif ($password ne "") {
         print "   o set admin password $password\n" ;

         # if insertion is request, password will be inserted just after edit "admin"
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'password',
            value           => $password,
            nb_spaces       => 8,
            netsted         => 'NOTNESTED',
            increment_index => 3
         ) ;
         }

	  # remove all trustedhosts (unset only)	 
      if ($trustedhost eq 'unset') {
         print "   o unset all trustedhosts (1 to 10)\n" ;
		 my $i ;
		 for ($i=1, $i<11, $i++) {
		     $self->unset_key(aref_scope => \@scope, key => 'trustedhost'.$i) ;
		     }
         }
 
      }
   else {
      print "   WARNING : no admin user found on the config\n" ;
      }
   }

# ---

sub global_system_dns {
   my $subn = "global_system_dns" ;

   my $self      = shift ;
   my $primary   = shift ;
   my $secondary = shift ;
   my $source_ip = shift ;

   warn "\n* Entering $obj:$subn with primary=$primary secondary=$secondary source_ip=$source_ip" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system dns') ;

   if ($self->cfg->feedback('found')) {

      if ($primary ne "") {
         print "   o set primary dns $primary\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'primary',
            value           => $primary,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 1
         ) ;
         }

      if ($secondary ne "") {
         print "   o set secondary dns $secondary\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'secondary',
            value           => $secondary,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      if ($source_ip ne "") {
         if ($source_ip eq "unset") {
            print "   o unset dns source-ip\n" ;
            $self->unset_key(aref_scope => \@scope, key => 'source-ip') ;
            }

         else {
            $self->set_key(
               aref_scope      => \@scope,
               key             => 'source-ip',
               value           => $source_ip,
               nb_spaces       => 4,
               netsted         => 'NOTNESTED',
               increment_index => 3
            ) ;
            }
         }

      }
   else {
      print "   WARNING : can't find config system dns\n" ;
      }
   }

# ---

sub global_system_ha {
   my $subn = "global_system_ha" ;

   my $self     = shift ;
   my $password = shift ;
   my $group_id = shift ;
   my $monitor  = shift ;

   warn "\n* Entering $obj:$subn with password=$password group_id=$group_id monitor=$monitor" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system ha') ;

   if ($self->cfg->feedback('found')) {

      if ($password eq "unset") {
         print "   o unser ha password\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'password') ;
         }

      else {
         print "   o set ha password $password\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'password',
            value           => $password,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 3
         ) ;
         }

      if ($group_id ne "") {
         print "   o set ha group-id $group_id\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'group-id',
            value           => $group_id,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 4
         ) ;
         }

      if ($monitor eq "unset") {
         print "   o unset ha monitor\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'monitor') ;
         }

      else {
         print "   o set ha monitor $monitor\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'monitor',
            value           => $monitor,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 5
         ) ;
         }
      }

   else {
      print "   WARNING : can't find config system ha\n" ;
      }
   }

# ---

sub global_system_central_management {
   my $subn = "global_system_central_management" ;

   my $self          = shift ;
   my $type          = shift ;
   my $fmg_source_ip = shift ;

   warn "\n* Entering $obj:$subn with type=$type and fmg_source_ip=$fmg_source_ip" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system central-management') ;

   if ($self->cfg->feedback('found')) {

      # type
      if ($type eq "unset") {
         print "   o unset central-management type\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'type') ;
         }

      elsif ($type ne "") {

         die "type can only be none|fortiguard|fortimanager"
           if ($type !~ /none|fortiguard|fortimanager|unset/) ;

         print "   o set central-management type $type\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'type',
            value           => $type,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      # source-ip
      if ($fmg_source_ip eq "unset") {
         print "   o unset central-management fmg-source-ip\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'fmg-source-ip') ;
         }

      elsif ($fmg_source_ip ne "") {
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'fmg-source-ip',
            value           => $fmg_source_ip,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 3
         ) ;
         }
      }
   else {
      print "   WARNING : can't find config system central-management\n" ;
      }
   }

# ---

sub global_log_fortianalyzer_setting {
   my $subn = "global_log_fortianalyzer_setting" ;

   my $self      = shift ;
   my $status    = shift ;
   my $server    = shift ;
   my $source_ip = shift ;

   warn "\n* Entering $obj:$subn with status=$status server=$server source_ip=$source_ip" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config log fortianalyzer setting') ;

   if ($self->cfg->feedback('found')) {

      # status
      if ($status eq "unset") {
         print "   o unset fortianalyzer setting status\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'status') ;
         }
      elsif ($status ne "") {
         die "status can only be enable|disable|unset" if ($status !~ /enable|disable|unset/) ;
         print "   o set fortianalyzer setting status\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'status',
            value           => $status,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      # server
      if ($server eq "unset") {
         print "   o unset fortianalyzer setting server\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'server') ;
         }
      elsif ($server ne "") {
         print "   o set fortianalyzer setting server\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'server',
            value           => $server,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      # source-ip
	  if ($source_ip eq "unset") {
         print "   o unset fortianalyzer source-ip\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'source-ip') ;
	     }
	  elsif ($source_ip ne "") {
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'source-ip',
            value           => $source_ip,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }
      }
   }

# ---

sub global_system_ntp {
   my $subn = "global_system_ntp" ;

   my $self      = shift ;
   my $ntpsync   = shift ;
   my $server    = shift ;
   my $source_ip = shift ;

   warn "\n* Entering $obj:$subn with ntpsync=$ntpsync server=$server source_ip=$source_ip" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system ntp') ;

   if ($self->cfg->feedback('found')) {

      # ntpsync
		if ($ntpsync eq "unset") {
         print "   o unset system ntp ntpsync\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'ntpsync') ;
         }

      elsif ($ntpsync ne "") {
         die "ntpsync can only be unset|enable|disable" if ($ntpsync !~ /unset|enable|disable"/) ;
         print "   o set system ntp ntpsync $ntpsync\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'ntpsync',
            value           => $ntpsync,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      # server
      if ($server ne "") {
         print "   o set system ntp server $server\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'server',
            value           => $server,
            nb_spaces       => 12,
            netsted         => 'NESTED',
            increment_index => 2
         ) ;
         }

      # source-ip
      if ($source_ip eq "unset") {
         print "   o unset system ntp source-ip\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'source-ip') ;
         }
      }

   else {
      print "    WARNING : could not find system ntp ntpsync\n" ;
      }

   }

# ---

sub global_system_netflow {
   my $subn = "global_system_netflow" ;

   my $self         = shift ;
   my $collector_ip = shift ;
   my $source_ip    = shift ;

   warn "\n* Entering $obj:$subn with collector_ip=$collector_ip source_ip=$source_ip" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system netflow') ;

   if ($self->cfg->feedback('found')) {

      # collector-ip
      if ($collector_ip ne "") {
         print "   o set netflow collector-ip $collector_ip\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'collector-ip',
            value           => $collector_ip,
            nb_spaces       => 4,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;
         }

      # source-ip
      if ($source_ip eq "unset") {
         print "   o unset netflow source-ip\n" ;
         $self->unset_key(aref_scope => \@scope, key => 'source-ip') ;
         }

      elsif ($source_ip ne "") {
         print "   o set netflow source-ip $source_ip\n" ;
         $self->set_key(
            aref_scope      => \@scope,
            key             => 'source-ip',
            value           => $source_ip,
            nb_spaces       => 8,
            netsted         => 'NOTNESTED',
            increment_index => 2
         ) ;

         }
      }
   else {
      print "    WARNING : cannot find config system netflow\n" ;
      }
   }

# ---

sub save {
   my $subn = "save" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   my $filename = $self->configfile ;
   $filename =~ s/\.conf/_translated.conf/ ;
   print "   o save translated config : $filename\n" ;

   die "configuration file name should end with .conf" if ($filename eq $self->configfile) ;
   $self->cfg->save_config(filename => $filename) ;
   }

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;

