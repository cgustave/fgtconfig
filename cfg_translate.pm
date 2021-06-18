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

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

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

   # Specific vdoms processing
   $self->vdoms_processing() ;

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

   my $hdr = $self->cfg->get_line(index => 1) ;

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
      $self->cfg->replace(index => 1, content => $hdr . "\n") ;
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
   my $primary      = $self->XMLTrsf->findvalue('/transform/global/system_dns/@primary') ;
   my $secondary    = $self->XMLTrsf->findvalue('/transform/global/system_dns/@secondary') ;
   my $source_ip    = $self->XMLTrsf->findvalue('/transform/global/system_dns/@source-ip') ;
   my $dns_over_tls = $self->XMLTrsf->findvalue('/transform/global/system_dns/@dns-over-tls');
   $self->global_system_dns($primary, $secondary, $source_ip, $dns_over_tls)
     if (($primary ne "") or ($secondary ne "") or ($source_ip ne "") or ($dns_over_tls ne "")) ;

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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'password') ;
         }
      elsif ($password ne "") {
         print "   o set admin password $password\n" ;

         # if insertion is request, password will be inserted just after edit "admin"
         $self->cfg->set_key(
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
		     $self->cfg->unset_key(aref_scope => \@scope, key => 'trustedhost'.$i) ;
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

   my $self         = shift ;
   my $primary      = shift ;
   my $secondary    = shift ;
   my $source_ip    = shift ;
   my $dns_over_tls = shift ;

   warn "\n* Entering $obj:$subn with primary=$primary secondary=$secondary source_ip=$source_ip dns_over_tls=$dns_over_tls" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system dns') ;

   if ($self->cfg->feedback('found')) {

      if ($primary ne "") {
         print "   o set primary dns $primary\n" ;
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
            $self->cfg->unset_key(aref_scope => \@scope, key => 'source-ip') ;
            }

         else {
			print "   o set dns source-ip $source_ip\n" ;
            $self->cfg->set_key(
               aref_scope      => \@scope,
               key             => 'source-ip',
               value           => $source_ip,
               nb_spaces       => 4,
               netsted         => 'NOTNESTED',
               increment_index => 3
            ) ;
            }
         }

	  if ($dns_over_tls ne "") {
		  if ($dns_over_tls eq "unset") {
			  print "   o unset dns-over-tls\n" ;
			  $self->cfg->unset_key(aref_scope => \@scope, key => 'dns-over-tls') ;
		      }
		  else {
			  print "   o set dns-over-tls $dns_over_tls\n" ;
              $self->cfg->set_key(
               aref_scope      => \@scope,
               key             => 'dns-over-tls',
               value           => $dns_over_tls,
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'password') ;
         }

      else {
         print "   o set ha password $password\n" ;
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'monitor') ;
         }

      else {
         print "   o set ha monitor $monitor\n" ;
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'type') ;
         }

      elsif ($type ne "") {

         die "type can only be none|fortiguard|fortimanager"
           if ($type !~ /none|fortiguard|fortimanager|unset/) ;

         print "   o set central-management type $type\n" ;
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'fmg-source-ip') ;
         }

      elsif ($fmg_source_ip ne "") {
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'status') ;
         }
      elsif ($status ne "") {
         die "status can only be enable|disable|unset" if ($status !~ /enable|disable|unset/) ;
         print "   o set fortianalyzer setting status\n" ;
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'server') ;
         }
      elsif ($server ne "") {
         print "   o set fortianalyzer setting server\n" ;
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'source-ip') ;
	     }
	  elsif ($source_ip ne "") {
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'ntpsync') ;
         }

      elsif ($ntpsync ne "") {
         die "ntpsync can only be unset|enable|disable" if ($ntpsync !~ /unset|enable|disable"/) ;
         print "   o set system ntp ntpsync $ntpsync\n" ;
         $self->cfg->set_key(
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
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'source-ip') ;
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
         $self->cfg->set_key(
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
         $self->cfg->unset_key(aref_scope => \@scope, key => 'source-ip') ;
         }

      elsif ($source_ip ne "") {
         print "   o set netflow source-ip $source_ip\n" ;
         $self->cfg->set_key(
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

sub interfaces_processing {
   my $subn = "interfaces_processing" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   die "undefined XMLTrsf" if (not(defined($self->XMLTrsf))) ;

   # Get node pointer on system_interfaces
   my $nodes = $self->XMLTrsf->findnodes('/transform/global/system_interfaces')->get_node(1) ;

   # Proceed first with all translation
   $self->_interfaces_translations(\$nodes) ;

   # all tunnel interfaces brough down by default if asked
   my $tunnel_status = $self->XMLTrsf->findvalue('/transform/global/system_interfaces/@tunnel_status') ;
   $self->_interfaces_tunnel_default_disable() if ($tunnel_status eq "disable") ;

   # When done, proceed with configuration
   $self->_interfaces_configurations(\$nodes) ;
   }

# ---

sub interfaces_post_processing {
   my $subn = "interfaces_post_processing" ;

   # To be used after interface processing for some adjustments like :
   # - ha hbdev can only have physical ports and does not allow loopacks

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   print "   o interface post processing : " ;

   # ha hbdev can only have physical ports and does not allow loopacks
   my @scope = () ;

   # Create table of physical ports
   my %hash_physical = () ;
   foreach my $int (@{$self->intfs->{_INTERFACE_LIST}}) {
      next if ($self->intfs->get(name => $int, key => 'type') ne 'physical') ;
      $hash_physical{$int} = 1 ;
      }

   print "remove non-physical HA hbdev" ;
   if ($self->cfg->scope_config(\@scope, 'config system ha', 0) and $self->cfg->feedback('found')) {
      $self->cfg->get_key(\@scope, 'hbdev', NOTNESTED, "") ;
      if ($self->cfg->feedback('found')) {
         my $index = $self->cfg->feedback('index') ;
         my $line = $self->cfg->get_line(index => $index) ;
         warn "$obj:$subn nbdev found at index=$index line=$line" if $self->debug ;

         $line =~ s/(\s+)set hbdev// ;
         my $new_line = "    set hbdev" ;
         my $hbdev ;
         my $priority ;
         while ($line =~ /(?:\s*")(\S+)(?:"\s*)(\d+)(?:\s)/g) {
            warn "$obj:$subn hbdev=$1 priority=$2" if $self->debug ;
            if (defined($hash_physical{$1})) {
               warn "$obj:$subn hbdev $1 is accepted because it is a physical device" if $self->debug ;
               $new_line .= " \"$1\" $2" ;
               }
            else {
               warn "$obj:$subn hbdev $1 is refused because it is not a physical device" if $self->debug ;
               }
            }
         warn "$obj:$subn result line : $new_line" if $self->debug ;
         $self->cfg->set_line(index => $index, content => $new_line . "\n") ;
         }
      }
   print "\n" ;
   }

# ---

sub all_vdoms_processing {
   my $subn = "all_vdoms_processing" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   die "undefined XMLTrsf" if (not(defined($self->XMLTrsf))) ;

   # Get node pointer on system_interfaces
   my $nodes = $self->XMLTrsf->findnodes('/transform/all_vdoms')->get_node(1) ;

   if (defined($nodes)) {

      # Proceed first with all translation
      $self->_all_vdoms_firewall_policies(\$nodes) ;

	  # IPsec vpn phase1-interface
	  $self->_all_vdoms_vpn_ipsec_phase1_interface(\$nodes) ;

      # Limit address groups length
      $self->_address_groups(\$nodes) ;
      }
   }

# ---

sub vdoms_processing {
   my $subn = "vdoms_processing" ;
   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;
   die "undefined XMLTrsf" if (not(defined($self->XMLTrsf))) ;

   # Get pointer on vdoms
   my $nodes = $self->XMLTrsf->findnodes('/transform/vdoms')->get_node(1) ;

   if (defined($nodes)) {

      foreach my $node ($nodes->findnodes('./vdom')) {
		 my $vdom = $node->findvalue('./@name') ;
         print "   o processing vdom $vdom\n" ;
		 warn "$obj:$subn : vdom=$vdom" if $self->debug;

		 # Config may have been touched, need to register vdoms again
         my @scope_vdom = () ;
		 $self->cfg->register_vdoms() ;
		 @scope_vdom = $self->cfg->scope_vdom($vdom) ;

		 # Process virtual-wan-link
		 $self->virtual_wan_link_processing($vdom, \@scope_vdom, \$node) ;
	     }

      }
   }


# ---

sub virtual_wan_link_processing {
my $subn = "virtual_wan_link_processing" ;

   my $self = shift ;
   my $vdom = shift ;
   my $ref_scope = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   my $vwl_node = $$ref_nodes->findnodes('./system_virtual-wan-link')->get_node(1) ;
   if (defined($vwl_node)) {
	   print "   o processing system virtual-wan-link\n" ;
	   if ($self->cfg->scope_config($ref_scope, 'config system virtual-wan-link') and $self->cfg->feedback('found')) {
	      $self->virtual_wan_link_health_check($vdom, $ref_scope, \$vwl_node) ;
	      }
	   else {
	      print "Warning : skip - could not find 'config system virtual-wan-link\n" ;
	      }
	   }
   }

# ---

sub virtual_wan_link_health_check {
my $subn = "virtual_wan_link_health_check" ;
   my $self      = shift ;
   my $vdom = shift ;
   my $ref_scope = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;
   foreach my $hc_node ($$ref_nodes->findnodes('./health-check')) {
      my $hc_name    = $hc_node->findvalue('@name') ;
	  my $hc_server  = $hc_node->findvalue('@server') ;
	  my $hc_members = $hc_node->findvalue('@members') ; 

      print "     o healthcheck name=$hc_name\n" ;

	  if ($self->cfg->scope_config($ref_scope, 'config health-check') and ($self->cfg->feedback('found'))) {
	     if ($self->cfg->scope_edit($ref_scope, "edit \"$hc_name\"") and $self->cfg->feedback('found')) {

			# Change server
            if ($hc_server ne "") {
               print "     o set server $hc_server\n" ;
               $self->cfg->set_key(aref_scope =>  $ref_scope, key =>'server', value => $hc_server, nb_spaces => 12, increment_index => 1) ;
			   }

			# Members
			if ($hc_members ne "") {
			   print "     o set members $hc_members\n" ;
               $self->cfg->set_key(aref_scope =>  $ref_scope, key =>'members', value => $hc_members, nb_spaces => 12, increment_index => 1) ;
               }

			# Change SLA config 
  	        $self->virtual_wan_link_hc_sla($vdom, $ref_scope, \$hc_node);
		    }
		 else {
			print "Warning : skip - could not find 'edit $hc_name' in config system virtual-link config health-check\n";
		    }
	     }
	  else {
		 print "Warning : skip - could not find sdwan healtcheck config\n";
	     }
	  }
   }

# ---

sub virtual_wan_link_hc_sla {
my $subn = "virtual_wan_link_hc_sla" ;

   my $self      = shift ;
   my $vdom = shift ;
   my $ref_scope = shift ;
   my $ref_node = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   foreach my $sla_node ($$ref_node->findnodes('./sla')) {

      my $id = $sla_node->findvalue('@id');
      my $latency_treshold = $sla_node->findvalue('@latency-treshold') ;
      my $jitter_threshold = $sla_node->findvalue('@jitter-threshold') ;
      my $packetloss_threshold = $sla_node->findvalue('@packetloss-threshold') ;
      warn "id=$id latency_treshold=$latency_treshold jitter_threshold=$jitter_threshold packetloss_threshold=$packetloss_threshold" if $self->debug ;

      if ($id ne "") {

	     print "       o sla id $id\n" ;
	     if ($self->cfg->scope_edit($ref_scope, $id) and $self->cfg->feedback('found')) {
	        warn "$obj:$subn id=$id scope=[".$$ref_scope[0].",".$$ref_scope[1]."]" if $self->debug();
		    if (($latency_treshold ne "") or ($jitter_threshold ne "") or ($packetloss_threshold ne "")) {

		       # latency
			   if ($latency_treshold eq "unset") {
			      print "       o unset latency-threshold\n";
			      $self->cfg->unset_key(aref_scope => $ref_scope, key => 'latency-threshold') ;
			      }
			   else {
			      print "       o set latency-threshold $latency_treshold\n";
			      $self->cfg->set_key(aref_scope =>  $ref_scope, key =>'latency-threshold', value=>$latency_treshold, nb_spaces => 20, increment_index => 1) ;
			      }

			   # jitter
			   if ($jitter_threshold eq "unset") {
			      print "       o unset jitter-threshold\n";
			      $self->cfg->unset_key(aref_scope => $ref_scope, key => 'jitter-threshold') ;
			      }
			   else {
			      print "       o set jitter-threshold $jitter_threshold\n";
			      $self->cfg->set_key(aref_scope =>  $ref_scope, key =>'jitter-threshold', value=>$jitter_threshold, nb_spaces => 20, increment_index => 1) 
			      }

			   # packet loss 
			   if ($packetloss_threshold eq "unset") {
			      print "       o unset packetloss-threshold\n";
			      $self->cfg->unset_key(aref_scope => $ref_scope, key => 'packetloss-threshold') ;
			      }
			   else {
			      print "       o set packetloss-threshold $packetloss_threshold\n";
			      $self->cfg->set_key(aref_scope =>  $ref_scope, key =>'packetloss-threshold', value=>$packetloss_threshold, nb_spaces => 20, increment_index => 1) 
			      }

			   }
		    }
	     }
	  else {
		 print "Warning : skip - could not find virtual-wan-link health-check sla with 'edit $id'\n";  
         }
      }
   }


# ---

sub _interfaces_translations {
   my $subn = "_interfaces_translations" ;

   # Interface translation takes place in 2 phases to avoid cross fingers pointing
   # Phase1 : change ports name <NAME> to __**<NAME>**__
   # Phase2 : when all done, changed __**<NAME>**__  back

   my $self      = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $node ($$ref_nodes->findnodes('./port[ @action="translate" ]|./port[ @action="keep" ]')) {

      my $action      = $node->findvalue('./@action') ;
      my $name        = $node->findvalue('./@name') ;
      my $dst_name    = $node->findvalue('./@dst_name') ;
      my $type        = $node->findvalue('./@type') ;
      my $dst_type    = $node->findvalue('./@dst_type') ;
	  my $alias       = $node->findvalue('./@alias');
      my $description = $node->findvalue('./@description') ;

      warn "$obj:$subn action=$action name=$name type=$type dst_name=$dst_name dst_type=$dst_type alias=$alias description=$description" if $self->debug ;

      # Translation of interface name to temp name

      # Sanity and defaults
      die "name needed" if ($name eq "") ;
      $type     = "physical" if ($type eq "") ;
      $dst_type = "physical" if ($dst_type eq "") ;

      # Common processing
      $self->_interface_unset_key(interface => $name, key => 'speed') ;

      # Translation
      if ($action eq "translate") {
         warn "$obj:$subn name translation is required" if $self->debug ;
         my $dst_interface = "__TS_" . $dst_name . "_TE__" ;

         # Interfaces with type 'ignore' will not be translated and remained as __IGNORE_<NAME>__
         $dst_interface = "__IGNORE_" . $name . "__" if ($dst_type eq "ignore") ;
         $self->_interface_translate(src => $name, dst => $dst_interface) ;

         # Change description of the translated interface if needed
         if ($description ne "") {
            warn "$obj:$subn name=$name => set description $description" if $self->debug ;
            $self->_interface_description_change(interface => $dst_interface, description => $description) ;
            }

         # Change alias of the translated interface if needed
         if ($alias ne "") {
            warn "$obj:$subn name=$name => set alias $alias" if $self->debug ;
            $self->_interface_alias_change(interface => $dst_interface, alias => $alias) ;
            }

         # Convertion of port type if needed (still using __TRANSLATED_TO name)
         if ($type ne $dst_type) {
            warn "$obj:$subn port type conversion $type => $dst_type required" if $self->debug ;

            $self->_interface_type_change(interface => $dst_interface, type => $type, dst_type => $dst_type) ;
            }
         }

      elsif ($action eq 'keep') {
         warn "$obj:$subn no name translation required for $name" if $self->debug ;

         # Flag interface as been processed so  it is not considered as untouched
         $self->intfs->set(name => $name, key => 'processed', value => 1) ;

         # Change description without name translation is allowed
         if ($description ne "") {
            warn "$obj:$subn name=$name => set description $description" if $self->debug ;
            $self->_interface_description_change(interface => $name, description => $description) ;
            }
	     # Change alias without name translation is allowed
         if ($alias ne "") {
            warn "$obj:$subn name=$name => set alias $alias" if $self->debug ;
            $self->_interface_alias_change(interface => $name, alias => $alias) ;
            }
         }
      }

   # Processed with default behavior for all untouched interface
   $self->_interfaces_translations_default() ;

   # Create all required vdom-links in {_IVLINKS} using temp name
   foreach my $vdl (keys(%{$self->{_IVLINK}})) {

      # Do not create again if already done
      next if $self->{_IVLINK}->{$vdl} eq "done" ;

      print "   o create vdom-link $vdl type " . $self->{_IVLINK}->{$vdl} . "\n" ;
      $self->_create_vdom_link($vdl, $self->{_IVLINK}->{$vdl}) ;

      # Flag as job done
      $self->{_IVLINK}->{$vdl} = "done" ;
      }

   # Perform phase2 : remove __TRANSLATE_TO_ everywhere
   my $count = 0 ;
   print "   o remove translation markers __TS_ and _TE__ from interface names\n" ;
   for (my $i = 1 ; $i <= $self->cfg->max_lines ; $i++) {
      my $line = $self->cfg->line($i) ;
      if ($line =~ /__TS_/) {
         $line =~ s/__TS_(\S+)_TE__/$1/g ;
         $self->cfg->set_line(index => $i, content => $line) ;
         chomp($line) ;
         $count++ ;
         warn "$obj:$subn (count=$count) phase2 - line=$i content=>$line<==" if $self->debug ;
         }
      }
   }

# ---

sub _interfaces_translations_default {
   my $subn = "_interfaces_translations_default" ;

   # Processing for all interfaces that have not been touched
   # All processed interface are flaged in $self->intfs with key 'processed = 1'

   my $self = shift ;

   # What is our default behavior asked ?
   my $action = $self->XMLTrsf->findvalue('/transform/global/system_interfaces/@ignored_physical_action') ;

   # do nothing by default
   $action = "none" if ($action eq "") ;
   warn "$obj:$subn ignored_physical_action=$action" if $self->debug ;

   return if ($action eq "none") ;

   print "   o processing all untouched interfaces (ignored_physical_action=\"$action\")\n" ;

   foreach my $interface ($self->intfs->get_interface_list()) {

      # Ignore all interfaces that are not physical ports, ignore modems and npu
      next if ($self->intfs->get(name => $interface, key => 'type') ne 'physical') ;
      next if ($interface =~ /^(modem|npu)/) ;

      # Ignore already processed interfaces
      my $processed = $self->intfs->get(name => $interface, key => 'processed') ;
      next if ((defined($processed)) and ($processed eq '1')) ;

      warn "$obj:$subn processing untouched interface $interface" if $self->debug ;

      # Common processing
      $self->_interface_unset_key(interface => $interface, key => 'speed') ;

      if ($action eq "translate_to_loopback") {
         warn "$obj:$subn non processed interface=$interface changed to loopback" if $self->debug ;
         $self->_interface_type_change(interface => $interface, type => "physical", dst_type => "loopback") ;
         $self->_interface_translate(src => $interface, dst => "__TS_" . "ign_" . $interface . "_TE__") ;
         }

      elsif ($action eq "translate_to_vdlink") {
         warn "$obj:$subn non processed interface=$interface changed to ignored vdom-link" if $self->debug ;
         $self->_interface_type_change(interface => $interface, type => "physical", dst_type => "vdom-link") ;
         $self->_interface_translate(src => $interface, dst => "__TS_" . "ign_" . $interface . "_0_TE__") ;
         }

      elsif ($action eq "ignore") {
         warn "$obj:$subn non processed interface=$interface renamed to ign_<name>" if $self->debug ;
         $self->_interface_translate(src => $interface, dst => "__IGNORE_" . $interface) ;
         }
      }

   }

# ---

sub _interfaces_tunnel_default_disable {
   my $subn = "_interfaces_tunnel_default_disable" ;

   # Brings all ipsec interface down by default
   # they may then be individually brought up with action=configure status

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   print "   o processing all tunnel interfaces with status down (tunnel_status=\"disable\")\n" ;

   foreach my $interface ($self->intfs->get_interface_list()) {

      # ignore SSL tunnel interfaces
      next if ($interface =~ /^ssl\./) ;

      # Ignore all interfaces that are not physical ports, ignore modems and npu
      next if ($self->intfs->get(name => $interface, key => 'type') ne 'tunnel') ;
      $self->_interface_status_change(interface => $interface, type => "tunnel", status => 'down') ;
      }
   }

# ---

sub _interfaces_configurations {
   my $subn = "_interfaces_configurations" ;

   my $self      = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   foreach my $node ($$ref_nodes->findnodes('./port[ @action="configure" ]')) {

      my $name        = $node->findvalue('./@name') ;
      my $status      = $node->findvalue('./@status') ;
      my $alias       = $node->findvalue('./@alias') ;
      my $vdom        = $node->findvalue('./@vdom') ;
      my $ip          = $node->findvalue('./@ip') ;
	  my $vlanid      = $node->findvalue('./@vlanid') ;
      my $allowaccess = $node->findvalue('./@allowaccess') ;
      my $description = $node->findvalue('./@description') ;
	  # lacp specific
	  my $member      = $node->findvalue('./@member');
	  my $lacpmode    = $node->findvalue('./@lacp-mode');
	  my $minlinks    = $node->findvalue('./@min-links');

      warn "$obj:$subn name=$name status=$status alias=$alias vdom=$vdom vlanid=$vlanid ip=$ip allowaccess=$allowaccess description=$description member=$member lacpmode=$lacpmode minlinks=$minlinks" if $self->debug ;

      # Sanity
      die "name needed" if ($name eq "") ;

      # set scope index
      my @scope = () ;
      my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $name) ;

      if (not($found)) {
         warn "$obj:$subn could not find interface $name in configuration, create it at index=$scope[0]" if $self->debug ;
         $self->_interface_creation(interface => $name, index => $scope[0]) ;
         $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $name) ;
         }

      # Also force a status UP (or this could be useless unless said differently
      if ($status eq "down") {
         print "   o set interface $name status down\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'status', value => 'down', nb_spaces => 8) ;
         }

      else {
         print "   o set interface $name status up\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'status', value => 'up', nb_spaces => 8) ;
         }

      # Change description if needed
      if ($description ne "") {
         warn "$obj:$subn name=$name => set description $description" if $self->debug ;
         $self->_interface_description_change(interface => $name, description => $description) ;
         }

      # ip address
      if ($ip ne "") {
         warn "$obj:$subn name=name => set ip=$ip" if $self->debug ;

         print "   o set interface $name ip $ip\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'ip', value => $ip, nb_spaces => 8) ;
         }

	  # vlanid
	  if ($vlanid ne "") {
		  warn "$obj:$subn name=name => set vlanid=$vlanid" if $self->debug ;
		  die "vlanid should be an integer, not ($vlanid)" if ($vlanid !~ /\d+/) ;
		  print "   o set interface $name vlanid $vlanid\n" ;
		  $self->cfg->set_key(aref_scope => \@scope, key => 'vlanid', value => $vlanid, nb_spaces => 8) ;
          }

      # Allowaccess
      if ($allowaccess ne "") {
         warn "$obj:$subn name=name => set allowaccess $allowaccess" if $self->debug ;
         print "   o set interface $name allowaccess\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'allowaccess', value => $allowaccess, nb_spaces => 8) ;
         }

      # Alias
      if ($alias ne "") {
         warn "$obj:$subn name=name => set alias $alias" if $self->debug ;
         print "   o set interface $name alias\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'alias', value => "\"" . $alias . "\"", nb_spaces => 8) ;
         }

      # Vdom
      if ($vdom ne "") {
         warn "$obj:$subn name=name => set vdom $vdom" if $self->debug ;
         print "   o set interface $name vdom\n" ;
         $self->cfg->set_key(aref_scope => \@scope, key => 'vdom', value => "\"" . $vdom . "\"", nb_spaces => 8) ;
         }

	  # LACP related
	  if ($member ne "") {
		  warn "$obj:$subn name=name => set member $member" if $self->debug ;
	      print "   o set lag interface $name member $member\n" ;
		  $self->cfg->set_key(aref_scope => \@scope, key => 'member', value => $member, nb_spaces => 8, index_increment => 5 ) ;
	      }

	  if ($lacpmode ne "") {
		  warn "$obj:$subn name=name => set lacp-mode $lacpmode" if $self->debug ;
	      print "   o set lag interface $name lacp-mode $lacpmode\n" ;
		  die "lacp-mode can only be static, passive or active"
		    if $lacpmode !~ /static|passive|active/ ;
		  $self->cfg->set_key(aref_scope => \@scope, key => 'lacp-mode', value => $lacpmode, nb_spaces => 8, index_increment => 5) ;
	      }
	  if ($minlinks ne "") {
		  warn "$obj:$subn name=name => set min-links $minlinks" if $self->debug ;
	      print "   o set lag interface $name min-links $minlinks\n" ;
		  $self->cfg->set_key(aref_scope => \@scope, key => 'min-links', value => $minlinks, nb_spaces => 8, index_increment => 5) ;
	      }
      }
   }

# ---

sub _interface_creation {
   my $subn = "_interface_creation" ;

   my $self      = shift ;
   my %options   = @_ ;
   my $interface = $options{'interface'} ;
   my $index     = $options{'index'} ;

   warn "\n* Entering $obj:$subn with interface=$interface index=$index" if $self->debug ;

   print "   o create non existing interface $interface\n" ;
   $index++ ;
   $self->cfg->insert(index => $index, content => "    next") ;
   $self->cfg->insert(index => $index, content => "        set type physical") ;
   $self->cfg->insert(index => $index, content => "        set status up") ;
   $self->cfg->insert(index => $index, content => "    edit \"$interface\"") ;

   # Config has been touched, need to register vdoms again
   $self->cfg->register_vdoms() ;
   }

# ---

sub _create_vdom_link {
   my $subn = "_create_vdom_link" ;

   # Create new inter vdom links
   # If none exists, should be located just above config system interface

   my $self   = shift ;
   my $vdlink = shift ;
   my $type   = shift ;

   warn "\n* Entering $obj:$subn with vdlink=$vdlink type=$type" if $self->debug ;

   my @scope = () ;
   $self->cfg->scope_config(\@scope, 'config system vdom-link') ;

   if ($self->cfg->feedback('found')) {
      my $index = ($self->cfg->feedback('endindex')) ;
      warn "$obj:$subn config system vdom-link exists, only add a new entry at $index" if $self->debug ;
      $self->cfg->insert(index => $index, content => "    edit \"$vdlink\"") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "        set type $type") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "    next") ;
      $index++ ;
      }

   else {
      warn "$obj:$subn config system vdom-link does not exists" if $self->debug ;

      # Create a new config statement before config system interface
      $self->cfg->scope_config(\@scope, 'config system interface') ;
      my $index = ($self->cfg->feedback('startindex')) ;
      $self->cfg->insert(index => $index, content => "config system vdom-link") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "    edit \"$vdlink\"") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "        set type \"$type\"") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "    next") ;
      $index++ ;
      $self->cfg->insert(index => $index, content => "end") ;
      $index++ ;
      }
   }

# ---

sub _interface_unset_key {
   my $subn = "_interface_unset_key" ;

   # Common changes required when translating interface to a VM

   my $self      = shift ;
   my %options   = @_ ;
   my $interface = $options{'interface'} ;
   my $key       = $options{'key'} ;

   warn "\n* Entering $obj:$subn with interface=$interface key=$key" if $self->debug ;

   my @scope = () ;
   my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      print "   o remove interface $interface speed\n" ;
      $self->cfg->unset_key(aref_scope => \@scope, key => $key) ;
      }

   else {
      warn "could not find interface $interface" ;
      }
   }

#---

sub _interface_description_change {
   my $subn = "_interface_description_change" ;

   my $self        = shift ;
   my %options     = @_ ;
   my $interface   = $options{'interface'} ;
   my $description = $options{'description'} ;

   warn "\n* Entering $obj:$subn with interface=$interface description=$description" if $self->debug ;

   my @scope = () ;
   my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->cfg->set_key(aref_scope => \@scope, key => 'description', value => "\"" . $description . "\"", nb_spaces => 8) ;
      print "   o change interface $interface description ($description)\n" ;
      }
   else {
      warn "Failed to set description for interface $interface" ;
      }
   }

# ---

sub _interface_alias_change {
   my $subn = "_interface_alias_change" ;

   my $self        = shift ;
   my %options     = @_ ;
   my $interface   = $options{'interface'} ;
   my $alias       = $options{'alias'} ;

   warn "\n* Entering $obj:$subn with interface=$interface alias=$alias" if $self->debug ;

   my @scope = () ;
   my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->cfg->set_key(aref_scope => \@scope, key => 'alias', value => "\"" . $alias . "\"", nb_spaces => 8) ;
      print "   o change interface $interface alias ($alias)\n" ;
      }
   else {
      warn "Failed to set alias for interface $interface" ;
      }
   }



# ---

sub _interface_type_change {
   my $subn = "_interface_type_change" ;

   my $self      = shift ;
   my %options   = @_ ;
   my $interface = $options{'interface'} ;
   my $type      = $options{'type'} ;
   my $dst_type  = $options{'dst_type'} ;

   # Position

   warn "\n* Entering $obj:$subn with interface=$interface type=$type dst_type=$dst_type" if $self->debug ;

   # Position our index
   my @scope = () ;
   my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->cfg->set_key(aref_scope => \@scope, key => 'type', value => $dst_type, nb_spaces => 8) ;
      print "   o change interface $interface type to $dst_type\n" ;

      # Things to do for any type of interfaces. as we have changed config, it is safer to re-scope again
      $self->_interface_unset_key(interface => $interface, key => 'speed') ;

      # Inter-vdom link specifics
      if ($dst_type eq "vdom-link") {
         warn "$obj:$subn convertion to vdom-link" if $self->debug ;

         # Things to fo for vdom links
         $self->_interface_unset_key(interface => $interface, key => 'vlan-formard') ;

         my ($vlink, $vl) ;

         # Get inter-vdom link interface name : case of translation from a physical port
         if (($vl) = $interface =~ /^((?:port|mgmt)\d+)/) {
            $vlink = "ign_" . $vl . "_" ;
            warn "$obj:$subn physical port convertion - ask for vdom-link $vlink creation from interface=$interface" if $self->debug ;
            }

         # Get inter-vdom link interface name : case of translation from npu-vlink
         elsif (($vl) = $interface =~ /(?:__TS_)(\S+)(?:0|1)(?:_TE__)$/) {

            # remove the 0 or 1 at the end
            $vlink = $vl ;
            warn "$obj:$subn ask for vdom-link $vlink creation from interface=$interface" if $self->debug ;
            }

         else {
            die "could not guess what interface destination name should be ($interface)" ;
            }

         # Change type to 'ethernet' if translating a npu-vlink
         if (defined($vlink)) {
            my $t = "ppp" ;
            if ($type eq "npu") {
               warn "$obj:$subn migrating from npu-link, need type ethernet" if $self->debug ;
               $t = "ethernet" ;
               $self->_delete_npu_vlinks() ;
               }
            elsif ($type eq "physical") {
               warn "$obj:$subn migrating from physical, need type ethernet" if $self->debug ;
               $t = "ethernet" ;
               }

            # Fill the inter vdom link list for later creation
            $self->{_IVLINK}->{$vlink} = $t ;
            }
         }

      elsif ($type eq "loopback") {
         warn "$obj:$subn convertion to loopback" if $self->debug ;

         # Things to fo for vdom links
         $self->_interface_unset_key(interface => $interface, key => 'vlan-forward') ;
         }
      }

   else {
      die "Failed to set $interface type to $dst_type" ;
      }
   }

# ---

sub _interface_status_change {
   my $subn = "_interface_status_change" ;

   my $self      = shift ;
   my %options   = @_ ;
   my $interface = $options{'interface'} ;
   my $type      = $options{'type'} ;
   my $status    = $options{'status'} ;

   warn "\n* Entering $obj:$subn with interface=$interface type=$type status=$status" if $self->debug ;

   # sanity
   die "interface required"         if ($interface eq "") ;
   die "type required "             if ($type eq "") ;
   die "status can only be up|down" if ($status !~ /up|down/) ;

   # Position our index
   my @scope = () ;
   my $found = $self->cfg->get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;

   if ($found) {
      print "   o change interface $interface to status $status\n" ;
      $self->cfg->set_key(aref_scope => \@scope, key => 'status', value => $status, nb_spaces => 8) ;
      }

   }

# ---

sub _delete_npu_vlinks {
   my $subn = "_delete_npu_vlinks" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   my @scope = () ;

   $self->cfg->scope_config(\@scope, 'config system np6') ;
   if ($self->cfg->feedback('found')) {
      warn "$obj:$subn delete lines from " . $self->cfg->feedback('startindex') . " - " . $self->cfg->feedback('endindex') if $self->debug ;
      $self->cfg->delete_block(startindex => $self->cfg->feedback('startindex'), endindex => $self->cfg->feedback('endindex')) ;
      }
   else {
      warn "$obj:$subn not found, may have been removed already" if $self->debug ;
      }
   }

# ---

sub _interface_translate {
   my $subn = "_interface_translate" ;

   # Translate interface srd to dst on all config
   # returns the number of changes done

   my $self    = shift ;
   my %options = @_ ;
   my $src     = $options{'src'} ;
   my $dst     = $options{'dst'} ;

   my $count = 0 ;

   warn "\n* Entering $obj:$subn with src=$src dst=$dst" if $self->debug ;

   # Sanity
   die "src is required" if (not(defined($src)) or ($src eq "")) ;
   die "dst is required" if (not(defined($dst)) or ($dst eq "")) ;

   print "   o translating interface $src to $dst\n" ;

   # Flag interface as processed
   $self->intfs->set(name => $src, key => 'processed', value => 1) ;

   for (my $i = 1 ; $i <= $self->cfg->max_lines ; $i++) {
      my $line      = $self->cfg->line($i) ;
      my $interface = undef ;

      if (($interface) = $line =~ /(?:"|\s|,)($src)(?:"|\s|,|$)/) {
         warn "$obj:$subn line need update" if $self->debug ;

         # Found in by in perl RE with [^] operateur used with s///
         # the only way to avoid port1 matching port10 is to split in pieces and
         # control each pieces

         my @elements = split / /, $line ;
         my @result ;

         foreach my $element (@elements) {

            # Strictly match element only between separators
            # to not match for instance port1 in port10
            if ($element =~ /(?:"|\s|,)($src)(?:"|\s|,|$)/) {
               $element =~ s/$src/$dst/ ;
               }
            push @result, $element ;
            }

         $line = join(' ', @result) ;
         $self->cfg->set_line(index => $i, content => $line) ;
         chomp($line) ;
         $count++ ;
         warn "$obj:$subn (count=$count) line=$i interface=$interface translated content=>$line<==" if $self->debug ;
         }
      }
   }

# ---

sub _address_groups {
   my $subn = "_address_groups" ;

   my $self      = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;
   my $node = $$ref_nodes->findnodes('./firewall_addrgrp')->get_node(1) ;
   return if (not(defined($node))) ;

   # limit address groups to max_size (a VM is 300 entries max)
   my $max_size = $node->findvalue('./@max_size') ;
   if (($max_size ne "") and ($max_size =~ /\d+/)) {
      warn "$obj:$subn considering max_size=$max_size" if $self->debug ;
      print "   o limit firewall address groups to maximum $max_size items\n" ;
      my @scope = (1, $self->cfg->max_lines) ;
      my $found = 1 ;
      while ($found) {
         $self->cfg->scope_config(\@scope, 'config firewall addrgrp') ;
         if ($self->cfg->feedback('found')) {

            # keep scope for this round
            warn "found scope startindex=" . $scope[0] . " endindex=" . $scope[1] if $self->debug ;

            # Go through all edit entries
            my @edit_scope = () ;
            $edit_scope[0] = $scope[0] ;
            $edit_scope[1] = $scope[1] ;

            my $id ;
            while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
               warn "$obj:$subn found id=$id scoped with start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug ;

               # cut the members list to max_size
               $self->_limit_member_size(aref_scope => \@edit_scope, id => $id, max_size => $max_size) ;

               # Prepare for next edit
               $edit_scope[0] = $edit_scope[1] ;
               $edit_scope[1] = $scope[1] ;
               }

            # Move to next round
            $scope[0] = $scope[1] ;
            $scope[1] = $self->cfg->max_lines ;
            }
         else { $found = 0 ; }
         }

      }
   }

# ---

sub _limit_member_size {
   my $subn = "_limit_member_size" ;

   my $self       = shift ;
   my %options    = @_ ;
   my $aref_scope = $options{'aref_scope'} ;
   my $id         = $options{'id'} ;
   my $max_size   = $options{'max_size'} ;

   warn "\n* Entering $obj:$subn with id=$id aref_scope=[" . $$aref_scope[0] . "-" . $$aref_scope[1] . "] and max_size=$max_size" if $self->debug ;

   my $return = $self->cfg->get_key($aref_scope, 'member', 'NOTNESTED', '') ;
   my $found = $self->cfg->feedback('found') ;
   if ($found) {
      my $member = $self->cfg->feedback('value') ;
      my $index  = $self->cfg->feedback('index') ;
      warn "$obj:$subn found member=$member at index=$index" if $self->debug ;

      # Make an array from the members and count items
      my @array ;
      my $nb_item = 0 ;
      $member =~ s/\s*set member\s*// ;
      $member = "\"" . $member . "\"" ;
      if ((@array) = $member =~ /(\S*)(?:\s|\n)/g) {
         foreach my $item (@array) {
            $nb_item++ ;
            warn "$obj:$subn item=$item" if $self->debug ;
            }
         }

      # alter or not the members
      if ($nb_item <= $max_size) {
         warn "$obj:$subn index=$index, address group $id is below max_size, do nothing" if $self->debug ;
         }
      else {
         warn "$obj:$subn indedx=$index, address group $id is above max_size ($max_size)" if $self->debug ;
         print "     ! warning : address group \"$id\" is above max_size $max_size, cutting members\n" ;
         $member = "" ;
         for (my $i = 0 ; $i < $max_size ; $i++) {
            $member .= $array[$i] ;
            $member .= " " if ($i < ($max_size - 1)) ;
            }
         $member .= "\n" ;
         $self->cfg->set_line(index => $index, content => "    set member $member") ;
         }
      }
   }

# ---

sub _all_vdoms_firewall_policies {
   my $subn = "_all_vdoms_firewall_policies" ;

   my $self      = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   my $nodes = $$ref_nodes->findnodes('./firewall_policy')->get_node(1) ;
   return if (not(defined($nodes))) ;

   foreach my $node ($nodes) {

      my $auto_asic_offload = $node->findvalue('./@auto-asic-offload') ;
      if ($auto_asic_offload eq "unset") {
         print "   o remove auto-asic-offload\n" ;
         my @scope = (1, $self->cfg->max_lines) ;
         my $found = 1 ;
         while ($found) {
            $self->cfg->scope_config(\@scope, 'config firewall policy') ;
            if ($self->cfg->feedback('found')) {

               warn "found scope_round startindex=" . $scope[0] . " endindex=" . $scope[1] if $self->debug ;
               $self->cfg->delete_all_keys_from_block(aref_scope => \@scope, key => 'auto-asic-offload', nested => NOTNESTED) ;

               # Move to next round
               $scope[0] = $scope[1] ;
               $scope[1] = $self->cfg->max_lines ;
               }
            else { $found = 0 ; }
            }
         }
      }
   }

# ---

sub _all_vdoms_vpn_ipsec_phase1_interface {
my $subn = "_all_vdoms_vpn_ipsec_phase1_interface";

   my $self      = shift ;
   my $ref_nodes = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   my $nodes = $$ref_nodes->findnodes('./vpn_ipsec_phase1-interface')->get_node(1) ;
   return if (not(defined($nodes))) ;
   foreach my $node ($nodes) {

      my $psksecret = $node->findvalue('./@psksecret') ;
      print "   o set all vdoms vpn IPsec phase1-interface psksecret to $psksecret\n" ;
      my @scope = (1, $self->cfg->max_lines) ;
      my $found = 1 ;
      while ($found) {
         $self->cfg->scope_config(\@scope, 'config vpn ipsec phase1-interface') ;
         if ($self->cfg->feedback('found')) {
			 
			# keep scope for this round
            warn "found scope startindex=" . $scope[0] . " endindex=" . $scope[1] if $self->debug ;

            # Go through all edit entries
            my @edit_scope = () ;
            $edit_scope[0] = $scope[0] ;
            $edit_scope[1] = $scope[1] ;

            my $id ;
            while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
               warn "$obj:$subn found id=$id scoped with start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug ;
               $self->cfg->set_key(aref_scope => \@edit_scope, key => 'psksecret', value=>$psksecret, nb_spaces=>8, nested => NOTNESTED) ;
              
               # Prepare for next edit
               $edit_scope[0] = $edit_scope[1] ;
               $edit_scope[1] = $scope[1] ;
               }

            # Move to next round
            $scope[0] = $scope[1] ;
            $scope[1] = $self->cfg->max_lines ;
            }
          else { $found = 0 ; }
        }
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

