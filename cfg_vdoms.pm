# ****************************************************
# *                                                  *
# *             C F G   V D O M S                    *
# *                                                  *
# *  Object for vdom based features                  *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#

package cfg_vdoms ;
my $obj = "cfg_vdoms" ;

use Moose ;
use Data::Dumper ;
extends('cfg_rules') ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

has 'cfg'   => (isa => 'cfg_dissector',  is => 'rw', required => 1) ;
has 'intfs' => (isa => 'cfg_interfaces', is => 'rw', required => 1) ;
has 'glo'   => (isa => 'cfg_global',     is => 'rw') ;
has 'stat'  => (isa => 'cfg_statistics', is => 'rw') ;
has 'debug' => (isa => 'Maybe[Int]',     is => 'rw', default  => '0') ;

has 'ruledebug' => (isa => 'Str', is => 'rw') ;
has 'splitconfigdir' => (isa => 'Str', is => 'rw', default => '.') ;

# ---

sub BUILD {
my $subn="BUILD" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn with debug=".$self->debug() if $self->debug ;
   $self->{VDOM} = {} ;
   }

# ---

sub get {
   my $subn = "get" ;

   # Returns value stored in global object
   # allows -key  -subkey  and -thirdkey

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-vdom requires" if (not(defined($options{'vdom'}))) ;
   die "-key required"  if (not(defined($options{'key'}))) ;

   if (not(defined($options{'subkey'}))) {
      return ($self->{VDOM}->{$options{'vdom'}}->{$options{'key'}}) ;
      }

   else {
      if (not(defined($options{'thirdkey'}))) {
         return ($self->{VDOM}->{$options{'vdom'}}->{$options{'key'}}->{$options{'subkey'}}) ;
         }
      else {
         return ($self->{VDOM}->{$options{'vdom'}}->{$options{'key'}}->{$options{'subkey'}}->{$options{'thirdkey'}}) ;
         }
      }
   }

# ---

sub set {
   my $subn = "set" ;

   # set value stored in global object

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-vdom requires"  if (not(defined($options{'vdom'}))) ;
   die "-key required"   if (not(defined($options{'key'}))) ;
   die "-value required" if (not(defined($options{'value'}))) ;

   $self->{VDOM}->{$options{'vdom'}}->{$options{'key'}} = $options{'value'} ;
   }

# ---

sub system_vdom_limitations {
   my $subn = "system_vdom_limitations" ;

   # Parser for config system vdom-property (edit entries) and focus on configured session, dialup-tunnels and sslvpn limits
   # Warnings will be later raised in raise_vdom_warnings
   # Resource limits can be sent globally for all vdom (config system resource-limits)
   # and then adjusted per vdom (config system vdom-property)
   # This can't be described with a config rules because the vdom is an edit statement

   my $self = shift ;

   my @scope = (undef, undef) ;
   my @edit_scope = () ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my $ok = $self->cfg->scope_config(\@scope, 'config system vdom-property') ;

   if ($ok) {
      my $vdom = "" ;
      $edit_scope[0] = $scope[0] ;
      $edit_scope[1] = $scope[1] ;

      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$vdom)) {
         warn "$obj:$subn processing vdom=$vdom within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug() ;
         my %hash_limits = (
            'session'       => '0',
            'dialup-tunnel' => '0',
            'sslvpn'        => '0'
         ) ;

         foreach my $key (keys %hash_limits) {

            my $value = $hash_limits{$key} ;
            $value = $self->cfg->get_key(\@edit_scope, $key, NOTNESTED, $hash_limits{$key}) ;
            my $max = undef ;

            # only extract the maximum limit set
            ($max) = $value =~ /^(\d*)(?:\s\d*)/ ;
            warn "$obj:$subn vdom=$vdom key=$key value=$value max=$max" if $self->debug() ;

            $self->{VDOM}->{$vdom}->{limits}->{$key} = $max ;
            }

         # Set scope for next vdom round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = $scope[1] ;
         }
      }
   }

# ---

sub process_vdoms {
   my $subn = "process_vdoms" ;

   # update vdom properties

   my $self = shift ;

   my $value = undef ;
   my $logic = undef ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Process vdoms always in the same order
   my @sorted_vdoms = sort { $a cmp $b } ($self->cfg->get_vdom_list) ;

   foreach my $vdom (@sorted_vdoms) {

      warn "$obj:$subn processing vdom=$vdom" if $self->debug() ;

      # sanity : vdom must be defined
      die "vdom must be defined and not null"
        if (not(defined($vdom)) or ($vdom eq "")) ;

      # Sets the vdom
      $self->vdomCurrent($vdom) ;

      # Clear all set scopes
      $self->resetScopeSets() ;

      # Process vdom rule based definitions
      $self->processRules() ;

      # vdom warnings that can't be written with a rule_vdom rule
      $self->raise_vdom_warnings() ;

      # Checking vdom based features that can't be described with rules
      $self->vdom_all_features() ;
      }

   warn Dumper $self->{VDOM} if $self->debug() ;
   }

# ---

sub raise_vdom_warnings {
   my $subn = "raise_vdom_warnings" ;

   # Raise vdom warnings which can't be handled by rules direction

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my $vdom = $self->vdomCurrent() ;

   # Resource limitations
   if (defined($self->{VDOM}->{$vdom}->{'limits'}->{'session'})) {
      if ($self->{VDOM}->{$vdom}->{'limits'}->{'session'} ne 0) {
         $self->warnAdd(
            warn     => "SESSION_LIMIT=" . $self->{VDOM}->{$vdom}->{'limits'}->{'session'},
            toolTip  => "A vdom session limit is set",
            severity => 'low'
         ) ;
         }
      }

   if (defined($self->{VDOM}->{$vdom}->{'limits'}->{'dialup-tunnel'})) {
      if ($self->{VDOM}->{$vdom}->{'limits'}->{'dialup-tunnel'} ne 0) {
         $self->warnAdd(
            warn     => "DIAL_TUNNEL_LIMIT=" . $self->{VDOM}->{$vdom}->{'limits'}->{'dialup-tunnel'},
            toolTip  => "A vdom dialup tunnel limit is set",
            severity => 'low'
         ) ;
         }
      }

   if (defined($self->{VDOM}->{$vdom}->{'limits'}->{'sslvpn'})) {
      if ($self->{VDOM}->{$vdom}->{'limits'}->{'sslvpn'} ne 0) {
         $self->warnAdd(
            warn     => "SSLVPN_LIMIT=" . $self->{VDOM}->{$vdom}->{'limits'}->{'sslvpn'},
            toolTip  => "A vdom SSL VPN limit is set",
            severity => 'low'
         ) ;
         }
      }
   }

# ---

sub parse_routes {
   my $subn = "parse_routes" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;
      my $ok = $self->cfg->scope_config(\@scope, 'config router static') ;

      if ($ok) {
         my $route = "" ;
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
            warn "$obj:$subn processing route id=$id in vdom=$vdom within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1]
              if $self->debug() ;

            my $dst      = $self->cfg->get_key(\@edit_scope, 'dst',      NOTNESTED, '0.0.0.0 0.0.0.0') ;
            my $device   = $self->cfg->get_key(\@edit_scope, 'device',   NOTNESTED, '') ;
            my $gateway  = $self->cfg->get_key(\@edit_scope, 'gateway',  NOTNESTED, '') ;
            my $distance = $self->cfg->get_key(\@edit_scope, 'distance', NOTNESTED, '10') ;
            my $priority = $self->cfg->get_key(\@edit_scope, 'priority', NOTNESTED, '') ;
            my $weight   = $self->cfg->get_key(\@edit_scope, 'weight',   NOTNESTED, '') ;

            warn "$obj:$subn id=$id dst=$dst device=$device distance=$distance priority=$priority weight=$weight" if $self->debug() ;

            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{dst}      = $self->intfs->cidr($dst) ;
            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{device}   = $device ;
            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{gateway}  = $gateway ;
            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{distance} = $distance ;
            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{priority} = $priority ;
            $self->{VDOM}->{$vdom}->{static_route}->{$id}->{weight}   = $weight ;

            # For IPsec, counting routes using an ipec interface (phase1)
            if (defined($self->{VDOM}->{$vdom}->{ipsec_phase1}->{$device})) {
               $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$device}->{countroutes}++ ;
               warn "$obj:$subn device is a phase1 (current nb of routes:" . $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$device}->{countroutes} . ")"
                 if $self->debug() ;
               }

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }
         }
      else {
         warn "$obj:$subn no route for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub vdom_all_features {
   my $subn = "vdom_all_features" ;

   # Set flags for all features for the given vdom

   my $self = shift ;

   warn "*Entering $obj:$subn" if $self->debug() ;

   my $vdom = $self->vdomCurrent() ;

   # sanity
   die "vdom required" if (not(defined($vdom))) ;

   # Session synch init to no
   $self->{VDOM}->{$vdom}->{ssync} = 'no' ;

   # device identification to no
   $self->{VDOM}->{$vdom}->{'device-identification'} = 'no' ;
   }

# ---

sub parse_phase1_ipsec_interface {
   my $subn = "parse_phase1_ipsec_interface" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;
      my $ok = $self->cfg->scope_config(\@scope, 'config vpn ipsec phase1-interface') ;

      if ($ok) {
         my $route = "" ;
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
            warn "$obj:$subn processing phase1 id=$id in vdom=$vdom within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1]
              if $self->debug() ;
            my $interface  = $self->cfg->get_key(\@edit_scope, 'interface',   NOTNESTED) ;
            my $mode       = $self->cfg->get_key(\@edit_scope, 'mode',        NOTNESTED, 'main') ;
            my $ikeversion = $self->cfg->get_key(\@edit_scope, 'ike-version', NOTNESTED, '1') ;
            my $type       = $self->cfg->get_key(\@edit_scope, 'type',        NOTNESTED, 'static') ;
            my $proposal   = $self->cfg->get_key(\@edit_scope, 'proposal',    NOTNESTED) ;
            my $peertype   = $self->cfg->get_key(\@edit_scope, 'peertype',    NOTNESTED, 'any') ;
            my $remotegw   = $self->cfg->get_key(\@edit_scope, 'remote-gw',   NOTNESTED, '0.0.0.0') ;
            if ($remotegw ne '0.0.0.0' and defined($self->{VDOM}->{$vdom}->{_remote_gw_list}->{$remotegw})) {
               $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{_DUP} = '[ DUPLICATE ]' ;
               }
            else { $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{_DUP} = '' ; }

            my $dpdretrycount    = $self->cfg->get_key(\@edit_scope, 'dpd-retrycount') ;
            my $dpdretryinterval = $self->cfg->get_key(\@edit_scope, 'dpd-retryinterval') ;
            my $addgwroute       = $self->cfg->get_key(\@edit_scope, 'add-gw-route', NOTNESTED, '') ;
            my $localgw          = $self->cfg->get_key(\@edit_scope, 'local-gw', NOTNESTED, '') ;

            warn
"$obj:$subn vdom=$vdom id=$id : interface=$interface mode=$mode proposal=$proposal remotegw=$remotegw dpdretrycount=$dpdretrycount  dpdretryinterval=$dpdretryinterval addgwroute=$addgwroute localgw=$localgw"
              if $self->debug() ;

            if ($self->intfs->defined(name => $id)) {
               $self->intfs->set(name => $id, key => '_has_ipsec', value => 'YES') ;
               }

            else {

               # This is a bug (Speak with Steph about it), adjusting script to support it
               print "warning: ipsec config bug : interface $id is built on a non defined interface in 'config system interface'\n" ;

               $self->warnAdd(
                  warn     => "IPSEC_CONFIG_BUG",
                  toolTip  => "interface $id is built on a non defined interface in 'config system interface'",
                  severity => 'low'
               ) ;

               $self->intfs->add_interface_to_list($id) ;
               $self->intfs->set_interface_defaults($id) ;
               $self->intfs->set(name => $id, key => '_has_ipsec', value => 'YES') ;
               $self->intfs->set(name => $id, key => 'type',       value => 'transport') ;
               $self->intfs->set(name => $id, key => 'vdom',       value => $vdom) ;
               $self->intfs->set(name => $id, key => 'interface',  value => $interface) ;
               }

            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{methode}          = 'interface' ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{type}             = $type ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{mode}             = $mode ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{ikeversion}       = $ikeversion ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{proposal}         = $proposal ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{remotegw}         = $remotegw ;
            $self->{VDOM}->{$vdom}->{_remote_gw_list}->{$remotegw}            = 'Y' ;                 # Used to find duplicates
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{localgw}          = $localgw ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{peertype}         = $peertype ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{dpdretrycount}    = $dpdretrycount ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{dpdretryinterval} = $dpdretryinterval ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{addgwroute}       = $addgwroute ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{countph2}         = 0 ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{countsrc}         = 0 ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{countdst}         = 0 ;
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{countroutes}      = 0 ;

            # Adjusting mode for ike v2 : in ike v2, there is no main nor aggressive
            $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$id}->{mode} = "IKEv2" if ($ikeversion eq '2') ;

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }
         }
      else {
         warn "$obj:$subn no phase1 for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub parse_phase2_ipsec_interface {
   my $subn = "parse_phase2_ipsec_interface" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;
      my $ok = $self->cfg->scope_config(\@scope, 'config vpn ipsec phase2-interface') ;

      if ($ok) {
         my $route = "" ;
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
            warn "$obj:$subn processing phase2 id=$id in vdom=$vdom within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1]
              if $self->debug() ;

            my $keepalive   = $self->cfg->get_key(\@edit_scope, 'keepalive') ;
            my $phase1name  = $self->cfg->get_key(\@edit_scope, 'phase1name') ;
            my $proposal    = $self->cfg->get_key(\@edit_scope, 'proposal') ;
            my $srcaddrtype = $self->cfg->get_key(\@edit_scope, 'src-addr-type') ;
            my $srcstartip  = $self->cfg->get_key(\@edit_scope, 'src-start-ip') ;
            my $srcendip    = $self->cfg->get_key(\@edit_scope, 'src-end-ip') ;
            my $srcsub      = $self->cfg->get_key(\@edit_scope, 'src-subnet') ;      # TO BE VERIFIED
            my $srcproto    = $self->cfg->get_key(\@edit_scope, 'src-protocol') ;    # TO BE VERIFIED
            my $srcport     = $self->cfg->get_key(\@edit_scope, 'src-port') ;        # TO BE VERIFIED
            my $dstaddrtype = $self->cfg->get_key(\@edit_scope, 'dst-addr-type') ;
            my $dststartip  = $self->cfg->get_key(\@edit_scope, 'dst-start-ip') ;
            my $dstendip    = $self->cfg->get_key(\@edit_scope, 'dst-end-ip') ;
            my $dstsub      = $self->cfg->get_key(\@edit_scope, 'dst-subnet') ;      # TO BE VERIFIED
            my $dstproto    = $self->cfg->get_key(\@edit_scope, 'dst-protocol') ;    # TO BE VERIFIED
            my $dstport     = $self->cfg->get_key(\@edit_scope, 'dst-port') ;        # TO BE VERIFIED

            # Build the phase2 src selector src
            my $src = "" ;
            if (defined($srcaddrtype)) { $src .= substr($srcaddrtype, 0, 1) }
            else                       { $src .= "s" }
            $src .= ": " ;
            if (defined($srcstartip)) { $src .= $srcstartip . "-" }
            if (defined($srcendip))   { $src .= $srcendip . " " }
            if (defined($srcsub))     { $src .= $srcsub . ":" }
            if (defined($srcproto))   { $src .= $srcproto . "/" }
            if (defined($srcport))    { $src .= $srcport }
            if (not(defined($srcaddrtype)) and (not(defined($srcsub))))   { $src .= '0.0.0.0/0 ' }
            if (not(defined($srcaddrtype)) and (not(defined($srcproto)))) { $src .= '0/' }
            if (not(defined($srcaddrtype)) and (not(defined($srcport))))  { $src .= '0' }
            warn "$obj:$subn src=$src" if $self->debug() ;

            my $dst .= "" ;
            if (defined($dstaddrtype)) { $dst .= substr($dstaddrtype, 0, 1) }
            else                       { $dst .= "s" }
            $dst .= ": " ;
            if (defined($dststartip)) { $dst .= $dststartip . "-" }
            if (defined($dstendip))   { $dst .= $dstendip . " " }
            if (defined($dstsub))     { $dst .= $dstsub . ":" }
            if (defined($dstproto))   { $dst .= $dstproto . "/" }
            if (defined($dstport))    { $dst .= $dstport }
            if (not(defined($dstaddrtype)) and (not(defined($dstsub))))   { $dst .= '0.0.0.0/0 ' }
            if (not(defined($dstaddrtype)) and (not(defined($dstproto)))) { $dst .= '0/' }
            if (not(defined($dstaddrtype)) and (not(defined($dstport))))  { $dst .= '0' }
            warn "$obj:$subn dst=$dst" if $self->debug() ;

            warn "$obj:$subn vdom=$vdom id=$id : phase1name=$phase1name keepalive=$keepalive proposal=$proposal" if $self->debug() ;

            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{type}       = 'interface' ;
            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{phase1name} = $phase1name ;
            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{proposal}   = $proposal ;
            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{keepalive}  = $keepalive ;
            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{src}        = $src ;
            $self->{VDOM}->{$vdom}->{ipsec_phase2}->{$id}->{dst}        = $dst ;

            # Increase phase1 count
            if (defined($self->{VDOM}->{$vdom}->{ipsec_phase1}->{$phase1name}->{countph2})) {
               $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$phase1name}->{countph2}++ ;
               warn "$obj:$subn phase1=$phase1name count=" . $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$phase1name}->{countph2} if $self->debug() ;
               }
            else {
               die "Config is wrong : Phase2 $id has no phase1" ;
               }

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }
         }
      else {
         warn "$obj:$subn no phase1 for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub get_ipsec_phase2s {
   my $subn = "get_ipsec_phase2s" ;

   # returns the list of phase 2 sorted by name for a given vdom

   my $self       = shift ;
   my $vdom       = shift ;
   my @sortedList = () ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   @sortedList = sort { $a cmp $b || length($a) <=> length($b)} keys %{$self->{VDOM}->{$vdom}->{ipsec_phase2}} ;
   return (@sortedList) ;
   }

# ---

sub parse_policies {
   my $subn = "parse_policies" ;

   my $self       = shift ;
   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;

      # Defaults
      foreach my $feature ('shaping', 'applist', 'webfilter', 'av', 'ipssensor', 'dnsfilter', 'anypolicy', 'gtp', 'snat', 'centnat', 'voip_profile', 'logtraffic',
         'webcache', 'learning-mode')
      {
         $self->{VDOM}->{$vdom}->{$feature} = 'no' ;
         }

      # Counter number of policies for the vdom
      $self->{VDOM}->{$vdom}->{'nb_policy'} = 0 ;
      my $ok = $self->cfg->scope_config(\@scope, 'config firewall policy') ;

      if ($ok) {
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
            warn "$obj:$subn processing policy id=$id in vdom=$vdom (policy_count="
              . $self->{VDOM}->{$vdom}->{'nb_policy'}
              . ") within scope start="
              . $edit_scope[0] . " end="
              . $edit_scope[1]
              if $self->debug() ;

            my $status = $self->cfg->get_key(\@edit_scope, 'status', NOTNESTED, 'enable') ;    # Need to be active

            if ($status ne 'disable') {
               $self->{VDOM}->{$vdom}->{'nb_policy'}++ ;

               # Check all features enabled on the policy
               $self->check_policy_features($vdom, $id, \@edit_scope) ;
               }                                                                               # if status enable

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }
         }
      else {
         warn "$obj:$subn no policies for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub check_policy_features {
   my $subn = "check_policy_features" ;

   my $self            = shift ;
   my $vdom            = shift ;
   my $id              = shift ;
   my $aref_edit_scope = shift ;

   warn "\n* Entering $subn with vdom=$vdom id=$id and aref_edit_scope=$aref_edit_scope" if $self->debug() ;

   my $srcintf = $self->cfg->get_key($aref_edit_scope, 'srcintf') ;
   my $dstintf = $self->cfg->get_key($aref_edit_scope, 'dstintf') ;

   # Any policies
   $self->{VDOM}->{$vdom}->{'anypolicy'} = "YES" if (($srcintf eq 'any') or ($dstintf eq 'any')) ;

   # Ipsec interface based
   if (defined($self->{VDOM}->{$vdom}->{ipsec_phase1}->{$srcintf})) {
      $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$srcintf}->{countsrc}++ ;
      warn "$obj:$subn srcintf is an ipsec phase1 (countsrc=" . $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$srcintf}->{countsrc} . ")"
        if $self->debug() ;
      }

   if (defined($self->{VDOM}->{$vdom}->{ipsec_phase1}->{$dstintf})) {
      $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$dstintf}->{countdst}++ ;
      warn "$obj:$subn srcintf is an ipsec phase1 (countdst=" . $self->{VDOM}->{$vdom}->{ipsec_phase1}->{$dstintf}->{countdst} . ")"
        if $self->debug() ;
      }

   # source nat
   my $snat = $self->cfg->get_key($aref_edit_scope, 'nat', NOTNESTED, '') ;
   warn "$obj:$subn id=$id  snat=$snat" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{snat} = "YES" if ($snat ne "") ;

   # central nat
   my $centnat = $self->cfg->get_key($aref_edit_scope, 'central-nat', NOTNESTED, '') ;
   warn "$obj:$subn id=$id  centnat=$centnat" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{centnat} = "YES" if ($centnat ne "") ;

   # Traffic shaping
   my $g_traffic_shaper = $self->cfg->get_key($aref_edit_scope, 'traffic-shaper', NOTNESTED, '') ;    # 4.0 style
   my $p_trafficshaping = $self->cfg->get_key($aref_edit_scope, 'trafficshaping', NOTNESTED, '') ;    # 3.0 style
   warn "$obj:$subn id=$id dstintf=$dstintf traffic-shaper=$g_traffic_shaper trafficshaping= $p_trafficshaping" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{shaping} = "YES" if (($g_traffic_shaper ne "") or ($p_trafficshaping ne "")) ;

   # Application control
   my $applist = $self->cfg->get_key($aref_edit_scope, 'application-list', NOTNESTED, '') ;
   warn "$obj:$subn id=$id applist=$applist" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{applist} = "YES" if ($applist ne "") ;

   # Voip profile
   my $voip_profile = $self->cfg->get_key($aref_edit_scope, 'voip-profile', NOTNESTED, '') ;
   warn "$obj:$subn id=$id voip_profile=$voip_profile" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{voip_profile} = "YES" if ($voip_profile ne "") ;

   # Antivirus
   my $av = $self->cfg->get_key($aref_edit_scope, 'av-profile', NOTNESTED, '') ;
   warn "$obj:$subn id=$id av=$av" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{av} = "YES" if ($av ne "") ;

   # Webfiltering
   my $webfilter = $self->cfg->get_key($aref_edit_scope, 'webfilter-profile', NOTNESTED, '') ;
   warn "$obj:$subn id=$id webfilter=$webfilter" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{webfilter} = "YES" if ($webfilter ne "") ;

   # dns-filtering
   my $dnsfilter = $self->cfg->get_key($aref_edit_scope, 'dnsfilter-profile', NOTNESTED, '') ;
   warn "$obj:$subn id=$id dnsfilter=$dnsfilter" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{dnsfilter} = "YES" if ($dnsfilter ne "");

   # IPS Sensor in policy
   my $ipssensor = $self->cfg->get_key($aref_edit_scope, 'ips-sensor', NOTNESTED, '') ;
   warn "$obj:$subn id=$id ipssensor=$ipssensor" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{ipssensor} = "YES" if ($ipssensor ne "") ;

   # logtraffic enable
   my $logtraffic = $self->cfg->get_key($aref_edit_scope, 'logtraffic', NOTNESTED, '', 'disable') ;
   warn "$obj:$subn id=$id logtraffic=$logtraffic" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{logtraffic} = "YES" if ($logtraffic ne "") ;

   # GTP
   my $gtp = $self->cfg->get_key($aref_edit_scope, 'gtp-profile', NOTNESTED, '') ;
   warn "$obj:$subn id=$id gtp=$gtp" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{gtp} = "YES" if ($gtp ne "") ;

   # capture packet enabled
   my $packet_capture = $self->cfg->get_key($aref_edit_scope, 'capture-packet', NOTNESTED, 'disable') ;
   warn "$obj:$subn id=$id packet_capture=$packet_capture" if $self->debug() ;
   if ($packet_capture eq "enable") {
      $self->warnAdd(
         warn     => "POLICY_PCAP",
         toolTip  => "Policy has pcap capture enable",
         severity => 'high'
         ) ;
      }

   # Webcache enabled
   my $webcache = $self->cfg->get_key($aref_edit_scope, 'webcache', NOTNESTED, '', 'disable') ;
   warn "$obj:$subn id=$id webcache=$webcache" if $self->debug() ;
   $self->{VDOM}->{$vdom}->{webcache} = "YES" if ($webcache ne "") ;

   # policy-learning
   my $learningMode = $self->cfg->get_key($aref_edit_scope, 'learning-mode', NOTNESTED, '', 'disable') ;
   warn "$obj:$subn id=$id learning-mode=$learningMode status=".$self->{VDOM}->{$vdom}->{'learning-mode'} if $self->debug() ;
   $self->{VDOM}->{$vdom}->{'learning-mode'} = "YES" if ($learningMode ne "") ;
   }

# ---

sub parse_interface_policies {
   my $subn = "parse_interface_policies" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;
   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;

      # Defaults
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'application-list-status'}     = 'no' ;
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'ips-DoS-status'}              = 'no' ;    # 4.3 only
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'ips-sensor-status'}           = 'no' ;
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'av-profile-status'}           = 'no' ;    # 5.0
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'webfiltering-profile-status'} = 'no' ;    # 5.0
      $self->{VDOM}->{$vdom}->{'interface_policy'}->{'dlp-sensor-status'}           = 'no' ;

      # Counter number of policies for the vdom
      $self->{VDOM}->{$vdom}->{'nb_interface_policy'} = 0 ;

      my $ok = $self->cfg->scope_config(\@scope, 'config firewall interface-policy') ;

      if ($ok) {
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {

            # Get the interface where interface policy is applied
            my $interface = $self->cfg->get_key(\@edit_scope, 'interface', NOTNESTED, 'enable') ;

            # initialization is required if the interface policy is applied on a zone
            # in this case we need to create a dummy interface with basic details

            $self->intfs->set(name => $interface, key => 'vdom',   value => $vdom, condition => 'undefined') ;
            $self->intfs->set(name => $interface, key => 'vlanid', value => '',    condition => 'undefined') ;
            $self->intfs->increment(name => $interface, key => 'nb_interface_policy') ;

            warn "$obj:$subn processing policy_id=$id in vdom=$vdom interface=$interface within scope start="
              . $edit_scope[0] . " end="
              . $edit_scope[1]
              if $self->debug() ;

            my $status = $self->cfg->get_key(\@edit_scope, 'status', NOTNESTED, 'enable') ;    # Need to be active

            # Start with all disabled per default
            my $app_list_status             = 'disable' ;
            my $ips_dos_status              = 'disable' ;
            my $ips_sensor_status           = 'disable' ;
            my $av_profile_status           = 'disable' ;
            my $webfiltering_profile_status = 'disable' ;
            my $dlp_sensor_status           = 'disable' ;

            if ($status ne 'disable') {
               $self->{VDOM}->{$vdom}->{'nb_interface_policy'}++ ;

               $app_list_status = $self->cfg->get_key(\@edit_scope, 'application-list-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom app_list_status=$app_list_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'application-list-status'} = "YES" if ($app_list_status ne 'disable') ;

               $ips_dos_status = $self->cfg->get_key(\@edit_scope, 'ips-DoS-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom ips_dos_status=$ips_dos_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'ips-DoS-status'} = "YES" if ($ips_dos_status ne 'disable') ;

               $ips_sensor_status = $self->cfg->get_key(\@edit_scope, 'ips-sensor-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom ips_sensor_status=$ips_sensor_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'ips-sensor-status'} = "YES" if ($ips_sensor_status ne 'disable') ;

               $av_profile_status = $self->cfg->get_key(\@edit_scope, 'av-profile-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom av-profile-status=$av_profile_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'av-profile-status'} = "YES" if ($av_profile_status ne 'disable') ;

               $webfiltering_profile_status = $self->cfg->get_key(\@edit_scope, 'webfiltering-profile-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom webfiltering-profile-status=$webfiltering_profile_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'webfiltering-profile-status'} = "YES" if ($webfiltering_profile_status ne 'disable') ;

               $dlp_sensor_status = $self->cfg->get_key(\@edit_scope, 'dlp-sensor-status', NOTNESTED, 'disable') ;
               warn "$obj:$subn policy_id=$id in vdom=$vdom dlp-sensor-status=$dlp_sensor_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'interface_policy'}->{'dlp-sensor-status'} = "YES" if ($dlp_sensor_status ne 'disable') ;
               }

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }

         }
      else {
         warn "$obj:$subn no interface policy found for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub parse_dos_policies {
   my $subn = "parse_dos_policies" ;

   # 'config firewall DoS-policy' only exists in 5.0
   # in 4.0, this is under config interface policy

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;
   foreach my $vdom ($self->cfg->get_vdom_list) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;

      # Default
      $self->{VDOM}->{$vdom}->{'dos_policy'} = 'no' ;

      # Counter
      $self->{VDOM}->{$vdom}->{'nb_dos_policy'} = 0 ;

      my $ok = $self->cfg->scope_config(\@scope, 'config firewall DoS-policy') ;

      if ($ok) {
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {

            # Get the interface where interface policy is applied
            my $interface = $self->cfg->get_key(\@edit_scope, 'interface', NOTNESTED) ;

            # initialization is required if the interface policy is applied on a zone
            # in this case we need to create a dummy interface with basic details

            $self->intfs->set(name => $interface, key => 'vdom',   value => $vdom, condition => 'undefined') ;
            $self->intfs->set(name => $interface, key => 'vlanid', value => "",    condition => 'undefined') ;
            $self->intfs->increment(name => $interface, key => 'nb_dos_policy') ;

            warn "$obj:$subn processing policy_id=$id in vdom=$vdom interface=$interface within scope start="
              . $edit_scope[0] . " end="
              . $edit_scope[1]
              if $self->debug() ;

            # Start with all disabled per default
            my $dos_status = 'disable' ;
            $dos_status = $self->cfg->get_key(\@edit_scope, 'status', NOTNESTED, 'enable') ;    # Need to be active

            if ($dos_status ne 'disable') {
               $self->{VDOM}->{$vdom}->{'nb_dos_policy'}++ ;

               warn "$obj:$subn policy_id=$id in vdom=$vdom DoS_status=$dos_status" if $self->debug() ;
               $self->{VDOM}->{$vdom}->{'dos_policy'} = "YES" if ($dos_status ne 'disable') ;
               }

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;
            }

         }
      else {
         warn "$obj:$subn no DoS policy found for this vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub sort_routes {
   my $subn = "sort_routes" ;

   my $self = shift ;
   my $vdom = shift ;

   my ($v, $w, $x, $y, $z) = (0, 0, 0, 0, 0) ;
   my $index = 0 ;
   my @array = () ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   # Create sorting value
   my @keys = keys(%{$self->{VDOM}->{$vdom}->{'static_route'}}) ;
   foreach my $key (@keys) {
      ($v, $w, $x, $y, $z) =
        $self->{VDOM}->{$vdom}->{'static_route'}->{$key}->{dst} =~ /^(\d{1,3})(?:\.)(\d{1,3})(?:\.)(\d{1,3})(?:\.)(\d{1,3})(?:\/)(\d{1,2})/ ;
      $index = 0 ;
      $index = (($y) + ($x * 256) + ($w * 65536) + ($v * 16777216)) ;
      warn "$obj:$subn v=$v, w=$w, x=$x, y=$y, (z=$z) index=$index" if $self->debug() ;
      $self->{VDOM}->{$vdom}->{'static_route'}->{$key}->{'sort_index'}  = $index ;
      $self->{VDOM}->{$vdom}->{'static_route'}->{$key}->{'sort_index2'} = $z ;
      }

   #my %hash = %{$self->{_VDOM}->{$vdom}->{'static_route'}} ;
   # Sort by sorting value
   @array = sort {
           $self->{VDOM}->{$vdom}->{'static_route'}->{$a}->{'sort_index'} <=> $self->{VDOM}->{$vdom}->{'static_route'}->{$b}->{'sort_index'}
        || $self->{VDOM}->{$vdom}->{'static_route'}->{$a}->{'sort_index2'} <=> $self->{VDOM}->{$vdom}->{'static_route'}->{$b}->{'sort_index2'}
        || $self->{VDOM}->{$vdom}->{'static_route'}->{$a}->{'device'} cmp $self->{VDOM}->{$vdom}->{'static_route'}->{$b}->{'device'}
        || $self->{VDOM}->{$vdom}->{'static_route'}->{$a}->{'gateway'} cmp $self->{VDOM}->{$vdom}->{'static_route'}->{$b}->{'gateway'}
        }
     keys(%{$self->{VDOM}->{$vdom}->{'static_route'}}) ;

   foreach my $key (@array) {
      warn "$obj:$subn sorted as: " . $self->{VDOM}->{$vdom}->{'static_route'}->{$key}->{dst} if $self->debug() ;
      }
   return @array ;
   }

# ---

sub splitconfig_vdoms {
   my $subn = "splitconfig_vdoms" ;

   my $self = shift ;

   my $fh_out = new FileHandle ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list()) {

      my $startindex = $self->cfg->vdom_index(vdom => $vdom, action => 'get', type => 'startindex');
      my $endindex   = $self->cfg->vdom_index(vdom => $vdom, action => 'get', type => 'endindex') ;

      warn "$obj:$subn processing vdom=$vdom startindex=$startindex endindex=$endindex" if $self->debug() ;

      # Oped file with vdom name for writing and dump al vdom lines, then close
      open $fh_out, '>:encoding(iso-8859-1)', $self->splitconfigdir . "/$vdom.conf" or die "open: $!" ;

      # Write a header
      print $fh_out $self->cfg->line(1) ;
      print $fh_out $self->cfg->line(2) ;
      print $fh_out $self->cfg->line(3) ;
      print $fh_out "\n\n" ;

      for (my $line = $startindex ; $line < $endindex ; $line++) {
         warn "$obj:$subn processing vdom $vdom, line=$line" if $self->debug() ;
         print $fh_out $self->cfg->line($line) ;
         }
      close $fh_out ;
      }
   }

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
