# ****************************************************
# *                                                  *
# *            C F G   G L O B A L                   *
# *                                                  *
# *  Object for global features                      *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#

package cfg_global ;
my $obj = "cfg_global" ;

use Moose ;
use Data::Dumper ;
extends('cfg_rules') ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

has 'cfg'   => (isa => 'cfg_dissector',  is => 'rw', required => 1) ;
has 'intfs' => (isa => 'cfg_interfaces', is => 'rw', required => 1) ;
has 'vd'    => (isa => 'cfg_vdoms',      is => 'rw') ;
has 'debug' => (isa => 'Maybe[Int]',     is => 'rw', default  => '0') ;

has 'ruledebug'      => (isa => 'Str', is => 'rw') ;
has 'splitconfigdir' => (isa => 'Str', is => 'rw', default => '.') ;

# ---

sub BUILD {
my $subn = "BUILD" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn with debug=".$self->debug if $self->debug ;

   $self->{GLOBAL}        = {} ;
   $self->{_HA}           = {} ;
   $self->{'_FORTIGUARD'} = {} ;
   }

# ---

sub get {
   my $subn = "get" ;

   # Returns value stored in global object

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-key required" if (not(defined($options{'key'}))) ;

   return ($self->{GLOBAL}->{$options{'key'}}) ;
   }

# ---

sub set {
   my $subn = "set" ;

   # Returns value stored in global object

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-key required"   if (not(defined($options{'key'}))) ;
   die "-value required" if (not(defined($options{'value'}))) ;

   $self->{GLOBAL}->{$options{'key'}} = $options{'value'} ;
   }

# ---

sub concat {
   my $subn = "concat" ;

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-key is required"   if (not(defined($options{'key'}))) ;
   die "-value is required" if (not(defined($options{'value'}))) ;

   # Create attribute if not defined

   if (not(defined($self->{GLOBAL}->{$options{'key'}}))) {
      $self->{GLOBAL}->{$options{'key'}} = $options{'value'} ;
      }

   else {
      $self->{GLOBAL}->{$options{'key'}} .= $options{'value'} ;
      }

   }

# ---

sub global_info {
   my $subn = "global_info" ;

   my $self = shift ;

   my ($key, $value) = undef ;

   warn "Entering $obj:$subn" if $self->debug() ;

   # Flag special image from config_headers
   $self->_flag_special_image() ;
   }

# ---

sub parse_resource_limits {
   my $subn = "parse_resource_limits" ;

   # Inspect configured resource limitation which may impact traffic or deny connections

   my $self = shift ;

   my @scope = (undef, undef) ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;
   my %hash_resource_limits = (
      'session'       => '0',
      'dialup-tunnel' => '0',
      'sslvpn'        => '0',
   ) ;

   $self->cfg->scope_config_and_multiget(\@scope, 'config system resource-limits', \%hash_resource_limits, \$self->{'_RESSOURCE_LIMITS'}) ;
   }

# ---

sub parse_admin_users {
   my $subn = "parse_admin_users" ;

   my $self = shift ;

   my @scope = (undef, undef) ;
   my @edit_scope = () ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Scope for 'config global' if vdoms
   if ($self->cfg->vdom_enable) {
      $self->cfg->scope_config(\@scope, 'config global') ;
      }

   my $ok = $self->cfg->scope_config(\@scope, 'config system admin') ;
   die "Could not find system admin" if (not $ok) ;

   $edit_scope[0] = $scope[0] ;
   $edit_scope[1] = $scope[1] ;

   my $user         = "" ;
   my $no_trusthost = 0 ;
   my $passwd       = 1 ;

   $self->{ADMIN_NO_PASSWD}     = 0 ;
   $self->{ADMIN_ALL_TRUSTHOST} = 1 ;

   while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$user)) {
      warn "$obj:$subn processing user=$user" if $self->debug() ;
      push @{$self->{_USER_LIST}}, $user ;
      $self->parse_user_details(\@edit_scope, $user, \$no_trusthost, \$passwd) ;

      # set scope for next round
      $edit_scope[0] = $edit_scope[1] ;
      $edit_scope[1] = $scope[1] ;

      # Verify admin account has a passwd and
      if (not($passwd)) {
         $self->{ADMIN_NO_PASSWD} = 1 ;
         }
      }

   # Verify if 1 admin user has no trushost (this is a security breach)
   if ($no_trusthost) {
      $self->{ADMIN_ALL_TRUSTHOST} = 0 ;
      }

   warn "$obj:$subn ADMIN_NO_PASSWD=" . $self->{ADMIN_NO_PASSWD} . " ADMIN_ALL_TRUSTHOST=" . $self->{ADMIN_ALL_TRUSTHOST} if $self->debug() ;
   }

# ---

sub get_admin_no_passwd {

   my $self = shift ;
   return ($self->{ADMIN_NO_PASSWD}) ;
   }

# ---

sub get_admin_all_trusthost {

   my $self = shift ;
   return ($self->{ADMIN_ALL_TRUSTHOST}) ;
   }

# ---

sub parse_user_details {
   my $subn = "parse_user_details" ;

   my $self             = shift ;
   my $aref_scope       = shift ;
   my $user             = shift ;
   my $ref_no_trusthost = shift ;
   my $ref_passwd       = shift ;

   my ($key, $default, $value) = undef ;
   my $trusted_host_local = 0 ;

   warn "\n* Entering $obj:$subn with user=$user scope=(" . $$aref_scope[0] . "," . $$aref_scope[1] . ")" if $self->debug() ;

   my %hash_user = (
      'password'   => '',
      'trusthost1' => '',
      'trusthost2' => '',
      'trusthost3' => '',
   ) ;
   foreach my $key (keys %hash_user) {
      my $value = $self->cfg->get_key($aref_scope, $key, NOTNESTED, '') ;

      $key = '' if (not(defined($key))) ;
      warn "$obj:$subn user=$user key=$key value=$value" if $self->debug() ;

      # passwd
      if (($key eq 'password') and $value eq '') {
         $$ref_passwd = 1 ;
         }

      # do we have a trustedhost ?
      if (($key =~ /trusthost/) and ($value ne '0.0.0.0 0.0.0.0') and ($value ne '')) {
         $trusted_host_local = 1 ;
         }
      }

   if (not($trusted_host_local)) {
      warn "$obj:$subn no trusted host for user=$user" if $self->debug() ;
      $$ref_no_trusthost = 1 ;
      }

   }

# ---

sub parse_ha {
   my $subn = "parse_ha" ;

   my $self = shift ;

   my @scope = (undef, undef) ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my %hash_ha = (
      'mode'              => 'standalone',
      'schedule'          => 'roundrobin',
      'hbdev'             => '',
      'ha-mgmt-interface' => 'disable',
      'vcluster2'         => 'disable',
   ) ;

   $self->cfg->scope_config_and_multiget(\@scope, 'config system ha', \%hash_ha, \$self->{'_HA'}) ;

   # Get hbdev interface and flag interface hash
   #warn "hbdev=".$hash_ha{'hbdev'};
   my ($port1, $port2) = "" ;
   my ($prio1, $prio2) = "" ;

   #warn "line=".$hash_ha{'hbdev'} ;

   # flag HA interfaces with priorities if system is running HA
   if (not($hash_ha{'mode'} eq 'standalone')) {
      if (($port1, $prio1) = $hash_ha{'hbdev'} =~ /^(\w+)(?:\")(?:\s)+(\d+)$/) {

         #warn "single hbdev port=$port1 prio=$prio1" ;
         $self->intfs->concat(name => $port1, key => 'interface', value => "[HA $prio1]") ;
         }

      if (($port1, $prio1, $port2, $prio2) = $hash_ha{'hbdev'} =~ /^(\w+)(?:\")(?:\s)+(\d+)(?:\s)+(?:\")(\w+)(?:\")(?:\s)+(\d+)$/) {

         #warn "dual hbdev port1=$port1 prio1=$prio1 port2=$port2 prio2=$prio2" ;
         $self->intfs->concat(name => $port1, key => 'interface', value => "[HA $prio1]") ;
         $self->intfs->concat(name => $port2, key => 'interface', value => "[HA $prio2]") ;
         }
      }

   $self->set(key => 'ha_mode', value => $self->{'_HA'}->{'mode'}) ;
   }

# ---

sub raise_global_warnings {
   my $subn = "raise_global_warnings" ;

   # Parses values eligible for warning and raise warning flag if needed

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   $self->{GLOBAL}->{warnings} = "" if (not(defined($self->{GLOBAL}->{warnings}))) ;
   $self->warnAdd(warn => 'SP3_PORT', severity => 'low', toolTip => 'NP4 ports are diverted to XH0') if ($self->intfs->has_sp3_port()) ;
   }

# ---

sub parse_standalone_session_sync {
   my $subn = "parse_standalone_session_synch" ;

   # Session sync is configured in global
   # we need to look for key 'syncvd' to find out what are the synched vdom and flag them

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = () ;
   my $syncvd     = undef ;
   my $id         = undef ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my $ok = $self->cfg->scope_config(\@scope, 'config system session-sync') ;

   $edit_scope[0] = $scope[0] ;
   $edit_scope[1] = $scope[1] ;

   if ($ok) {

      # Go through all edit and identify vdoms selected by "set syncvd"
      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
         warn "$obj:$subn processing edit id=$id" if $self->debug() ;
         $syncvd = $self->cfg->get_key(\@scope, "syncvd") ;
         $syncvd =~ s/\"//g ;    # Strip "

         warn "$obj:$subn syncvd: $syncvd" if $self->debug() ;
         $self->vd->set(vdom => $syncvd, key => 'ssync', value => "YES") ;

         # Set scope for next id round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = $scope[1] ;
         }
      }

   }

# ---

sub splitconfig_global {
   my $subn = "splitconfig_global" ;

   my $self = shift ;

   my $fh_out = new FileHandle ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   if ($self->cfg->vdom_enable) {

      open $fh_out, '>:encoding(iso-8859-1)', $self->splitconfigdir . "/_global.conf" or die "open: $!" ;

      # Write a header
      print $fh_out $self->cfg->line(1) ;
      print $fh_out $self->cfg->line(2) ;
      print $fh_out $self->cfg->line(3) ;
      print $fh_out "\n\n" ;

      # Get end global index from vdom object
      my $end_global_index = $self->cfg->get_end_global_index() ;

      for (my $index = 5 ; $index < ($end_global_index - 4) ; $index++) {
         warn "$obj:$subn processing global, index=$index" if $self->debug() ;
         print $fh_out $self->cfg->line($index) ;
         }

      close $fh_out ;
      }

   }

# ---

sub _flag_special_image {
   my $subn = "_flag_special_image" ;

   my $self = shift ;

   my $buildno = undef ;

   warn "\n* Entering $subn" if $self->debug() ;

   # Detect special image if build number in line 1 does not match the 3rd or 4th buildno=
   my $build = $self->cfg->build() ;

   if (($buildno) = $self->cfg->line(3) =~ /^(?:#buildno=)(\d{4})/) {
      if ($buildno ne $build) {
         warn "$obj:$subn special image from header line 3 build=$build buildno=$buildno" if $self->debug() ;
         $self->cfg->build_tag($buildno) ;
         if ($buildno != $build) {
            warn "$obj:$subn Looks like a special image" if $self->debug() ;
            $self->warnAdd(warn => 'SPECIAL_IMAGE', severity => 'low', toolTip => 'Firmware is a special image') ;
            }
         }
      }
   if (($buildno) = $self->cfg->line(4) =~ /^(?:#buildno=)(\d{4})/) {
      if ($buildno ne $build) {
         warn "$obj:$subn special image from header line 4 build=$build buildno=$buildno" if $self->debug() ;
         $self->cfg->build_tag($buildno) ;
         if ($buildno != $build) {
            warn "$obj:$subn Looks like a special image" if $self->debug() ;
            $self->warnAdd(warn => 'FORTICARRIER_SPECIAL_IMAGE', severity => 'low', toolTip => 'Firmware is a forticarrier image') ;
            }
         }
      }
   }

# ---

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
