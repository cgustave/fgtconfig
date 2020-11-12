# ****************************************************
# *                                                  *
# *          C F G  I N T E R F A C E S              *
# *                                                  *
# *  Parser object for fortigate config style        *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************

package cfg_interfaces ;
my $obj = "cfg_interfaces" ;

use Moose ;
use Data::Dumper ;
use Net::Netmask ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

has 'cfg' => (isa => 'cfg_dissector', is => 'rw') ;

has 'vd'    => (isa => 'cfg_vdoms',  is => 'rw') ;
has 'debug' => (isa => 'Maybe[Int]', is => 'rw', default => '0') ;

my %hash_interface = (
   vdom                     => 'root',
   type                     => '',
   interface                => '',
   mode                     => 'static',
   status                   => 'up',
   speed                    => 'auto',
   vlanid                   => '',
   ip                       => '',
   allowaccess              => '',
   alias                    => '',
   description              => '',
   gwdetect                 => 'disable',    # 4.3 only
   detectserver             => '',           # 4.3 only
   'forward-domain'         => '',
   'mtu-override'           => 'disable',
   wccp                     => 'disable',
   log                      => 'disable',
   'sflow-sampler'          => 'disable',
   'ips-sniffer-mode'       => 'disable',
   ipmac                    => 'disable',
   'spillover-threshold'    => '0',
   'device-identification'  => 'disable',    # blocks acceleration when enabled
   'ipv6'                   => 0,
   'vrrp'                   => 0,
   inbandwidth              => 0,
   outbandwidth             => 0,
   'egress-shaping-profile' => '',
) ;

# ---

sub BUILD {
   my $subn = "BUILD" ;

   my $self = shift ;

   warn "$obj:$subn debug=" . $self->debug() if $self->debug ;

   $self->{_INTERFACE}      = () ;
   $self->{_INTERFACE_LIST} = () ;
   }

# SUBS

sub get_all_intfs_array {
   my $subn = "all_intfs_array" ;

   # Returns an array of all interfaces

   my $self = shift ;

   return (keys(%{$self->{_INTERFACE}})) ;
   }

# ---

sub get_all_intf_secondary_array {
   my $subn = "get_all_intf_secondary_array" ;

   # Return all secondary ip from an interface

   my $self      = shift ;
   my $interface = shift ;

   return (keys %{$self->{_INTERFACE}->{$interface}->{secondary}}) ;
   }

# ---

sub get_interface_list {
   my $subn = "get_interface_list" ;

   my $self = shift ;
   return (@{$self->{_INTERFACE_LIST}}) ;
   }

# ---

sub add_interface_to_list {
   my $subn = "add_interface_to_list" ;

   my $self      = shift ;
   my $interface = shift ;

   warn "\n* Entering $obj:$subn with interface=$interface" if $self->debug() ;

   push @{$self->{_INTERFACE_LIST}}, $interface ;
   }

# ---

sub get {
   my $subn = "get" ;

   # Get interface attribute value

   my $self    = shift ;
   my %options = @_ ;

   my $value = undef ;

   # sanity
   die "-name is required" if (not(defined($options{'name'}))) ;
   die "-key is required"  if (not(defined($options{'key'}))) ;

   if (not(defined($options{'secondary'}))) {

      $value = $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} ;
      warn "$obj:$subn get name=" . $options{'name'} . " key=" . $options{'key'} if $self->debug() ;
      }

   else {
      $value = $self->{_INTERFACE}->{$options{'name'}}->{secondary}->{$options{'secondary'}}->{$options{'key'}} ;
      warn "$obj:$subn get name=" . $options{'name'} . " secondary=" . $options{'secondary'} . " key=" . $options{'key'} if $self->debug() ;
      }

   return ($value) ;
   }

# ---

sub defined {
   my $subn = "defined" ;

   # Returns 1 if attribut is defined or 0

   my $self    = shift ;
   my %options = @_ ;

   my $return = 0 ;

   # sanity
   die "-name is required" if (not(defined($options{'name'}))) ;

   if (not(defined($options{'secondary'}))) {

      if (defined($options{'key'})) {
         $return = 1 if (defined($self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}})) ;
         }
      else {
         $return = 1 if (defined($self->{_INTERFACE}->{$options{'name'}})) ;
         }

      }

   else {

      if (defined($options{'key'})) {
         $return = 1 if (defined($self->{_INTERFACE}->{$options{'name'}}->{secondary}->{$options{'secondary'}}->{$options{'key'}})) ;
         }
      else {
         $return = 1 if (defined($self->{_INTERFACE}->{$options{'name'}}->{secondary}->{$options{'secondary'}})) ;
         }

      }

   return ($return) ;
   }

# ---

sub set {
   my $subn = "set" ;

   # Set interface attribute value
   # Set interface secondary ip attributes
   # If -condition => undefined : only set value if the attribute is not already defined

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-name is required"  if (not(defined($options{'name'}))) ;
   die "-key is required"   if (not(defined($options{'key'}))) ;
   die "-value is required" if (not(defined($options{'value'}))) ;

   $options{'condition'} = "" if (not(defined($options{'condition'}))) ;

   if (not(defined($options{'secondary'}))) {

      if ($options{'condition'} eq 'undefined') {
         return if (defined($self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}})) ;
         }

      $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} = $options{'value'} ;
      warn "$obj:$subn set value=" . $options{'value'} . " for name=" . $options{'name'} . " key=" . $options{'key'} if $self->debug() ;
      }

   else {

      if ($options{'condition'} eq 'undefined') {
         return if (defined($self->{_INTERFACE}->{$options{'name'}}->{secondary}->{$options{'secondary'}}->{$options{'key'}})) ;
         }

      $self->{_INTERFACE}->{$options{'name'}}->{secondary}->{$options{'secondary'}}->{$options{'key'}} = $options{'value'} ;
      warn "$obj:$subn set value="
        . $options{'value'}
        . " for secondary="
        . $options{'secondary'}
        . " name="
        . $options{'name'} . " key="
        . $options{'key'}
        if $self->debug() ;
      }

   }

# ---

sub increment {
   my $subn = "increment" ;

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-name is required" if (not(defined($options{'name'}))) ;
   die "-key is required"  if (not(defined($options{'key'}))) ;

   $options{'value'} = 1 if (not(defined($options{'value'}))) ;

   # initialize to 0 if attr not defined
   $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} = 0
     if (not(defined($self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}}))) ;

   # increment by value
   $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} += $options{'value'} ;
   }

# ---

sub concat {
   my $subn = "concat" ;

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-name is required"  if (not(defined($options{'name'}))) ;
   die "-key is required"   if (not(defined($options{'key'}))) ;
   die "-value is required" if (not(defined($options{'value'}))) ;

   # Create attribute if not defined

   if (not(defined($self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}}))) {
      $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} = $options{'value'} ;
      }

   else {
      $self->{_INTERFACE}->{$options{'name'}}->{$options{'key'}} .= $options{'value'} ;
      }

   }

# ---

sub get_all_aggregate_redundant_switch_array {
   my $subn = "get_all_aggregate_redundant_switch_array" ;

   my $self   = shift ;
   my @sorted = sort { $a cmp $b } keys(%{$self->{_AGGREDSW}}) ;
   return (@sorted) ;
   }

# ---

sub has_aggregate_redundant_switch_interface {
   my $subn = "has_aggregate_redundant_switch_interface" ;

   my $self   = shift ;
   my $return = 0 ;

   if (defined($self->{_AGGREDSW})) {
      $return = 1 ;
      }

   return ($return) ;
   }

# ---

sub get_aggregate_redundant_switch {
   my $subn = "has_aggregate_redundant_switch" ;

   my $self    = shift ;
   my %options = @_ ;

   warn "\n* Entering $obj:$subn with name=" . $options{'name'} . " and key=" . $options{'key'}
     if $self->debug() ;

   # sanity
   die "-name is required"             if (not defined($options{'name'})) ;
   die "-key is required"              if (not defined($options{'key'})) ;
   die "-key can only be type|members" if ($options{'key'} !~ /type|members/) ;

   if ($options{'key'} eq 'type') {
      return ($self->{_AGGREDSW}->{$options{'name'}}->{type}) ;
      }

   elsif ($options{'key'} eq 'members') {
      if (defined($self->{_AGGREDSW}->{$options{'name'}}->{members})) {
         return ($self->{_AGGREDSW}->{$options{'name'}}->{members}) ;
         }
      else {
         return ("") ;
         }
      }

   }

# ---

sub process_interfaces {
   my $subn = "process_interfaces" ;

   my $self = shift ;

   warn "\n*Entering $obj:$subn" if $self->debug() ;
   $self->parse_interfaces() ;
   $self->update_interfaces() ;
   }

# ---

sub parse_interfaces {
   my $subn = "parse_interfaces" ;

   # Parses config system interface and retrieve all keys for each of them

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = () ;
   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Scope for 'config global' if vdoms
   if ($self->cfg->vdom_enable) {
      $self->cfg->scope_config(\@scope, 'config global') ;
      }

   my $ok = $self->cfg->scope_config(\@scope, 'config system interface') ;
   die "Could not find interfaces" if (not $ok) ;

   $edit_scope[0] = $scope[0] ;
   $edit_scope[1] = $scope[1] ;

   my $interface = "" ;
   while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$interface)) {
      warn "$obj:$subn processing interface=$interface" if $self->debug() ;
      push @{$self->{_INTERFACE_LIST}}, $interface ;

      # Set default values
      $self->set_interface_defaults($interface) ;
      $self->parse_interface_details(\@edit_scope, $interface) ;

      # Get secondary IP, IPv6, VRRP  info if any (based on edit scope without modifying it (need a copy)
      my @scope_sec = () ;
      $scope_sec[0] = $edit_scope[0] ;
      $scope_sec[1] = $edit_scope[1] ;
      $self->parse_interface_secondary_ip(\@scope_sec, $interface) ;
      $self->parse_interface_ipv6(\@scope_sec, $interface) ;
      $self->parse_interface_vrrp(\@scope_sec, $interface) ;

      # set scope for next round
      $edit_scope[0] = $edit_scope[1] ;
      $edit_scope[1] = $scope[1] ;
      }
   }

# ---

sub set_interface_defaults {
   my $subn = "_set_interface_defaults" ;

   my $self      = shift ;
   my $interface = shift ;

   warn "\n* Entering $subn with interface=$interface" if $self->debug() ;

   foreach my $attr (
      qw /alias wccp zone mode vlanid ip network broadcast status gwdetect mtu-override allowaccess log sflow-sampler ips-sniffer-mode ipmac spillover-threshold device-identification ipv6 vrrp inbandwidth outbandwidth egress-shaping-profile /
     )
   {
      $self->set(name => $interface, key => $attr, value => "") ;
      }
   }

# ---

sub parse_interface_details {
   my $subn = "parse_interface_details" ;

   # Get keys from %hash_interface  and look for "set key <value>
   # Build {_INTERFACE} hash and {_INTERFACE_LIST}

   my $self       = shift ;
   my $aref_scope = shift ;
   my $interface  = shift ;

   my ($key, $default, $value) = undef ;

   warn "\n* Entering $obj:$subn with interface=$interface scope=(" . $$aref_scope[0] . "," . $$aref_scope[1] . ")" if $self->debug() ;

   foreach $key (keys %hash_interface) {
      warn "$obj:$subn  processing key=$key, default=" . $hash_interface{$key} if $self->debug() ;
      $value = $self->cfg->get_key($aref_scope, $key, NOTNESTED, $value = $hash_interface{$key}) ;

      warn "$obj:$subn interface=$interface key=$key value=$value" if $self->debug() ;
      $self->set(name => $interface, key => $key, value => $value) ;
      }
   $self->set(name => $interface, key => 'zone', value => "") ;
   }

# ---

sub parse_interface_secondary_ip {
   my $subn = "parse_interface_secondary_ip" ;

   # Parses the config

   my $self       = shift ;
   my $aref_scope = shift ;
   my $int        = shift ;

   my @edit_scope = () ;

   warn "\n* Entering $obj:$subn with int=$int" if $self->debug() ;

   my $ok = $self->cfg->scope_config($aref_scope, 'config secondaryip') ;

   if ($ok) {
      my $id = "" ;
      $edit_scope[0] = $$aref_scope[0] ;
      $edit_scope[1] = $$aref_scope[1] ;

      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
         warn "$obj:$subn processing id=$id within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug() ;
         my %hash_secondary = (
            'allowaccess'  => '',
            'detectserver' => '',
            'gwdetect'     => '',
            'ip'           => '',
         ) ;

         foreach my $key (keys %hash_secondary) {
            my $value = $hash_secondary{$key} ;
            $value = $self->cfg->get_key(\@edit_scope, $key, NOTNESTED, $hash_secondary{$key}) ;
            warn "$obj:$subn int=$int id=$id key=$key value=$value" if $self->debug() ;
            $self->set(name => $int, secondary => $id, key => $key, value => $value) ;
            }

         # Set scope for next id round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = $$aref_scope[1] ;
         }

      }

   else {
      warn "$obj:$subn no secondary ip for interface=$int" if $self->debug() ;
      }
   }

# ---

sub parse_interface_ipv6 {
   my $subn = "parse_interface_ipv6" ;

   my $self       = shift ;
   my $aref_scope = shift ;
   my $int        = shift ;

   my @edit_scope = () ;
   my ($autoconf, $address, $mode) = "" ;
   my $result = 0 ;

   warn "\n* Entering $obj:$subn with int=$int" if $self->debug() ;

   my $ok = $self->cfg->scope_config($aref_scope, 'config ipv6') ;
   if ($ok) {
      $autoconf = $self->cfg->get_key($aref_scope, 'autoconf', 'NOTNESTED', 'disable') ;
      $result   = 1 if ($autoconf ne 'disable') ;

      $mode   = $self->cfg->get_key($aref_scope, 'mode', 'NOTNESTED', 'static') ;
      $result = 1 if ($mode ne 'static') ;

      $address = $self->cfg->get_key($aref_scope, 'ip6-address', 'NOTNESTED', '::/0') ;
      $result  = 1 if ($address ne '::/0') ;

      warn "$obj:$subn (autoconf=$autoconf mode=$mode address=$address ) => result=$result" if $self->debug() ;

      $self->set(name => $int, key => 'ipv6_autoconf', value => $autoconf) ;
      $self->set(name => $int, key => 'ipv6_mode',     value => $mode) ;
      $self->set(name => $int, key => 'ipv6_address',  value => $address) ;
      }

   $self->set(name => $int, key => 'ipv6', value => $result) ;
   }

# ---

sub parse_interface_vrrp {
   my $subn = "parse_interface_vrrp" ;

   my $self       = shift ;
   my $aref_scope = shift ;
   my $int        = shift ;

   my @edit_scope = () ;
   my ($autoconf, $address, $mode) = "" ;
   my $result = 0 ;

   warn "\n* Entering $obj:$subn with int=$int" if $self->debug() ;
   my $ok = $self->cfg->scope_config($aref_scope, 'config vrrp') ;
   if ($ok) {
      my $id = "" ;
      $edit_scope[0] = $$aref_scope[0] ;
      $edit_scope[1] = $$aref_scope[1] ;

      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
         warn "$obj:$subn processing id=$id within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug() ;
         my $vrip = $self->cfg->get_key(\@edit_scope, 'vrip', NOTNESTED, "") ;
         warn "$obj:$subn int=$int id=$id vrip=$vrip" if $self->debug() ;
         if ($vrip ne "") {
            $result = 1 ;
            last ;
            }
         }

      }
   $self->set(name => $int, key => 'vrrp', value => $result) ;
   }

# ---

sub update_interfaces {
   my $subn = "update_interfaces" ;

   # Update the interface object with computed values like network address and broadcast
   # Also creates the hash for redundant and aggregate

   my $self = shift ;

   my @scope = (undef, undef) ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $key (keys(%{$self->{_INTERFACE}})) {

      # updates hash for aggregate/redundant
      if (defined($self->{_INTERFACE}->{$key}->{type})) {
         if ($self->{_INTERFACE}->{$key}->{type} eq 'aggregate') {
            warn "$obj:$subn got an aggregate interface=$key" if $self->debug() ;
            $self->update_aggregate_redundant_switch($key, 'aggregate') ;
            }
         elsif ($self->{_INTERFACE}->{$key}->{type} eq 'redundant') {
            warn "$obj:$subn got a redundant interface=$key" if $self->debug() ;
            $self->update_aggregate_redundant_switch($key, 'redundant') ;
            }
         elsif ($self->{_INTERFACE}->{$key}->{type} eq 'fctrl-trunk') {
            warn "$obj:$subn got a fctrl-trunk interface=$key" if $self->debug() ;
            $self->update_aggregate_redundant_switch($key, 'fctrl-trunk') ;
            }
         elsif ($self->{_INTERFACE}->{$key}->{type} eq 'switch') {
            warn "$obj:$subn got a switch interface=$key" if $self->debug() ;
            $self->update_aggregate_redundant_switch($key, 'switch') ;
            }
         elsif ($self->{_INTERFACE}->{$key}->{type} eq 'vap-switch') {
            warn "$obj:$subn got a vap-switch interface=$key" if $self->debug() ;
            }
         elsif ($self->{_INTERFACE}->{$key}->{type} eq 'hard-switch') {
            warn "$obj:$subn got a hard-switch interface=$key" if $self->debug() ;
            $self->update_aggregate_redundant_hardswitch($key) ;
            }

         # shorten allowaccess with first and last letter
         $self->shortcut_allowaccess(\$self->{_INTERFACE}->{$key}->{allowaccess}) ;
         }

      # Update ip in cidr + network + broadcast
      ($self->{_INTERFACE}->{$key}->{ip}, $self->{_INTERFACE}->{$key}->{network}, $self->{_INTERFACE}->{$key}->{broadcast}) =
        $self->ipcidr_network_broadcast($self->{_INTERFACE}->{$key}->{ip}) ;

      # only show ping-server enabled with 'X'
      # note : later changed with 'config router gwdetect' (not anymore on interface level)
      $self->{_INTERFACE}->{$key}->{gwdetect} = '' if (not(defined($self->{_INTERFACE}->{$key}->{gwdetect}))) ;
      if ($self->{_INTERFACE}->{$key}->{gwdetect} eq 'enable') {
         $self->{_INTERFACE}->{$key}->{gwdetect} = 'X' ;
         }
      else { $self->{_INTERFACE}->{$key}->{gwdetect} = ''  }

      # only show mtu-override enabled with 'X'
      $self->{_INTERFACE}->{$key}->{'mtu-override'} = '' if (not(defined($self->{_INTERFACE}->{$key}->{'mtu-override'}))) ;
      if ($self->{_INTERFACE}->{$key}->{'mtu-override'} eq 'enable') {
         $self->{_INTERFACE}->{$key}->{'mtu-override'} = 'X' ;
         }
      else { $self->{_INTERFACE}->{$key}->{'mtu-override'} = ''  }

      # Raise device-identity feature
      if (defined($self->{_INTERFACE}->{$key}->{'device-identification'})) {
         if ($self->{_INTERFACE}->{$key}->{'device-identification'} eq 'enable') {
            $self->vd->set(vdom => $self->{_INTERFACE}->{$key}->{'vdom'}, key => 'device-identification', value => 'YES') ;
            }
         }
      else {
         $self->{_INTERFACE}->{$key}->{'device-identification'} = 'disable' ;
         }

      # Raise inbandwidth and outbandwidth flags
      $self->{_INTERFACE}->{$key}->{'inbandwidth'} = '' if (not(defined($self->{_INTERFACE}->{$key}->{'inbandwidth'}))) ;
      }

   # Update gwdetect with interfaces configured in 'config router gwdetect'
   $self->parser_gwdetect() ;
   }

# ---

sub update_aggregate_redundant_hardswitch {
   my $subn = "update_aggregate_redundant_hardswitch" ;

   my $self      = shift ;
   my $interface = shift ;

   my @scope        = (undef, undef) ;
   my $scope_config = undef ;

   warn "\n* Entering $obj:$subn with interface=$interface" if $self->debug() ;

   $scope_config = "config system virtual-switch" ;
   $self->cfg->scope_config(\@scope, $scope_config) ;
   my $edit = "edit \"" . $interface . "\"" ;
   $self->cfg->scope_edit(\@scope, $edit) ;
   $self->cfg->scope_config(\@scope, 'port') ;    # config port
   my $id         = "" ;
   my @edit_scope = (undef, undef) ;
   $edit_scope[0] = $scope[0] ;
   $edit_scope[1] = $scope[1] ;

   while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
      warn "$obj:$subn processing port=$id" if $self->debug() ;
      $id =~ s/\"//g if (defined($id)) ;

      # Create hash entry
      $self->{_AGGREDSW}->{$interface}->{type}    = 'hard-switch' ;
      $self->{_AGGREDSW}->{$interface}->{members} = $id ;

      # Set scope for next round
      $edit_scope[0] = $edit_scope[1] ;
      $edit_scope[1] = $scope[1] ;
      }
   }

# ---

sub update_aggregate_redundant_switch {
   my $subn = "update_aggregate_redundant_switch" ;

   my $self      = shift ;
   my $interface = shift ;
   my $type      = shift ;

   my @scope        = (undef, undef) ;
   my $scope_config = undef ;

   warn "\n* Entering $obj:$subn with interface=$interface and type=$type" if $self->debug() ;

   if ($type =~ /aggregate|redundant/) {
      $scope_config = "config system interface" ;
      }
   else {
      $scope_config = "config system switch-interface" ;
      }

   $self->cfg->scope_config(\@scope, $scope_config) ;
   my $edit = "edit \"" . $interface . "\"" ;
   $self->cfg->scope_edit(\@scope, $edit) ;
   my $value = $self->cfg->get_key(\@scope, "member") ;
   $value =~ s/\"//g if (defined($value)) ;                # Strip "
   warn "$obj:$subn members: $value" if $self->debug() ;

   # Create hash entry
   $self->{_AGGREDSW}->{$interface}->{type}    = $type ;
   $self->{_AGGREDSW}->{$interface}->{members} = $value ;
   }

# ---

sub parser_gwdetect {
   my $subn = "parser_gwdetect" ;

   # ping server was originally at interface level and was transfered to 'config router gwdetect'
   # 2 format possible 4.0 and 5.0

   # FG600C-5.00-FW-build228
   # config router gwdetect
   # edit 1
   #     set interface "port4"
   #     set interval 1
   #     set server "172.16.26.1"
   # next

   # FG3K9B-4.00-FW-build640
   #config router gwdetect
   # edit "vl114_p5"
   #     set ha-priority 10
   #     set interval 1
   #     set server "10.185.0.163"
   # next

   my $self       = shift ;
   my @scope      = (undef, undef) ;
   my @edit_scope = () ;
   my $id         = undef ;
   my $interface  = undef ;
   my $server     = undef ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;
   my $ok = $self->cfg->scope_config(\@scope, 'config router gwdetect') ;

   $edit_scope[0] = $scope[0] ;
   $edit_scope[1] = $scope[1] ;

   if ($ok) {

      # Go through all edit and identify interfaces from the edit statement
      (my $base) = $self->cfg->config_version() =~ /(\d)\./ ;
      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
         warn "$obj:$subn processing id=$id base_version=$base " if $self->debug() ;

         if ($base eq '4') {
            $interface = $id ;
            }
         else {
            $interface = $self->cfg->get_key(\@edit_scope, 'interface', NOTNESTED) ;
            }

         $server = $self->cfg->get_key(\@edit_scope, 'server', NOTNESTED) ;
         if (defined($server)) {
            warn "$obj:$subn found gwdetect for interface=$interface (server=$server)" if $self->debug() ;
            $self->{_INTERFACE}->{$interface}->{gwdetect} = 'X' ;
            }

         # Set scope for next round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = $scope[1] ;
         }
      }
   }

# ---

sub return_vlan_interface_in_vdom {
   my $subn = "return_vlan_interface_in_vdom" ;

   # Returns the list of vlan interfaces sorted by vlan

   my $self      = shift ;
   my $vdom      = shift ;
   my $interface = shift ;

   my %list       = () ;
   my @sortedList = () ;

   warn "*Entering $obj:$subn with vdom=$vdom interface=$interface" if $self->debug() ;

   foreach my $int (keys(%{$self->{_INTERFACE}})) {

      next if (not(defined($self->{_INTERFACE}->{$int}->{vlanid}))) ;

      warn "int=$int"     if (not(defined($self->{_INTERFACE}->{$int}->{vdom}))) ;
      warn "vdom=$vdom"   if (not(defined($vdom))) ;
      warn "vlanid undef" if (not(defined($self->{_INTERFACE}->{$int}->{vlanid}))) ;

      if (   ($self->{_INTERFACE}->{$int}->{vdom} eq $vdom)
         and (not($self->{_INTERFACE}->{$int}->{vlanid} eq ''))
         and ($self->{_INTERFACE}->{$int}->{interface} eq $interface))
      {
         warn "$obj:$subn found vlan interface $int in vdom=$vdom based on interface=$interface (vlan=" . $self->{_INTERFACE}->{$int}->{vlanid} . ")"
           if $self->debug() ;
         $list{$int} = $self->{_INTERFACE}->{$int}->{vlanid} ;
         }
      }

   @sortedList = sort { $list{$a} cmp $list{$b} || length($list{$a}) <=> length($list{$b}) } keys %list ;
   return (@sortedList) ;
   }

# ---

sub parse_zones {
   my $subn = "parse_zones" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list()) {
      warn "\n* Entering $obj:$subn processing vdom=$vdom" if $self->debug() ;
      @scope = $self->cfg->scope_vdom($vdom) ;
      my $ok = $self->cfg->scope_config(\@scope, 'config system zone') ;

      if ($ok) {
         my $zone = "" ;
         $edit_scope[0] = $scope[0] ;
         $edit_scope[1] = $scope[1] ;

         while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$zone)) {
            warn "$obj:$subn processing zone=$zone in vdom=$vdom within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1]
              if $self->debug() ;
            my $interfaces = $self->cfg->get_key(\@edit_scope, 'interface', NOTNESTED, '') ;
            $interfaces =~ s/\"\s\"/,/g ;    # replace " " with , to get a comman separated list
            warn "$obj:$subn zone=$zone interface list:$interfaces" if $self->debug() ;

            # Update zone attributes for interfaces in the list
            foreach my $int (split(',', $interfaces)) {
               warn "$obj:$subn updating zone=$zone for interface=$int" if $self->debug() ;
               $self->set(name => $int, key => 'zone', value => $zone) ;
               }

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $scope[1] ;

            }
         }
      else {
         warn "$obj:$subn no zones for vdom=$vdom" if $self->debug() ;
         }
      }
   }

# ---

sub shortcut_allowaccess {
   my $subn = "shortcut_allowaccess" ;

   my $self             = shift ;
   my $sref_allowaccess = shift ;

   warn "\n* Entering $obj:$subn with deref sref_allowaccess=" . $$sref_allowaccess if $self->debug() ;

   $$sref_allowaccess =~ s/https/hs/ ;
   $$sref_allowaccess =~ s/http/hp/ ;
   $$sref_allowaccess =~ s/ping/p/ ;
   $$sref_allowaccess =~ s/ssh/sh/ ;
   $$sref_allowaccess =~ s/telnet/t/ ;
   $$sref_allowaccess =~ s/snmp/sp/ ;
   $$sref_allowaccess =~ s/fgfm/f/ ;
   $$sref_allowaccess =~ s/capwap/cp/ ;
   $$sref_allowaccess =~ s/auto-ipsec/ai/ ;

   $$sref_allowaccess = "" if (not(defined($$sref_allowaccess))) ;
   }

# ---

sub interface_flags {
   my $subn = "interface_flags" ;

   my $self      = shift ;
   my $interface = shift ;

   my $type = "" ;

   warn "\n* Entering $obj:$subn with interface=$interface" if $self->debug() ;

   # Add one space char to separate physical interface to flags
   $type .= " " if ($self->{_INTERFACE}->{$interface}->{interface} ne "") ;

   if ($self->{_INTERFACE}->{$interface}->{type} eq 'tunnel')      { $type .= '[T]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'vdom-link')   { $type .= '[VL]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'aggregate')   { $type .= '[A]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'redundant')   { $type .= '[R]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'switch')      { $type .= '[SW]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'vap-switch')  { $type .= '[VSW]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'hard-switch') { $type .= '[HSW]'  }
   if ($self->{_INTERFACE}->{$interface}->{type} eq 'loopback')    { $type .= '[LO]'  }

   # Flag wccp interface
   if ($self->{_INTERFACE}->{$interface}->{wccp} eq 'enable') { $type .= '[WCCP]'  }

   # Flag logging enabled at interface level
   if ($self->{_INTERFACE}->{$interface}->{log} eq 'enable') {
      $type .= '[LOG]' ;
      }

   # Flag and count interface policy attached
   if (defined($self->{_INTERFACE}->{$interface}->{'nb_interface_policy'})) {
      $type .= "[IPO " . $self->{_INTERFACE}->{$interface}->{'nb_interface_policy'} . "]" ;
      }

   # Flag for sp3 interface
   if (defined($self->{_INTERFACE}->{$interface}->{sp3port})) {
      $type .= "[SP3]" ;
      }

   # Flag for sflow enabled
   if ($self->{_INTERFACE}->{$interface}->{'sflow-sampler'} eq 'enable') {
      $type .= "[sflow]" ;
      }

   # Flag for sniffer interface (IDS only)
   if ($self->{_INTERFACE}->{$interface}->{'ips-sniffer-mode'} eq 'enable') {
      $type .= "[SNIFF]" ;
      }

   # IPMac enabled
   if ($self->{_INTERFACE}->{$interface}->{'ipmac'} eq 'enable') {
      $type .= "[IPMAC]" ;
      }

   # Spillover threshold
   if ($self->{_INTERFACE}->{$interface}->{'spillover-threshold'} ne '0') {
      $type .= "[SPIL]" ;
      }

   # Device identifiction
   if ($self->{_INTERFACE}->{$interface}->{'device-identification'} eq 'enable') {
      $type .= "[DevID]" ;
      }

   # ipv6
   if ($self->{_INTERFACE}->{$interface}->{'ipv6'} eq '1') {
      $type .= "[v6]" ;
      }

   # VRRP
   if ($self->{_INTERFACE}->{$interface}->{'vrrp'} eq '1') {
      $type .= "[VRRP]" ;
      }

   # Flag inbandwith and outbandwidth
   if ($self->{_INTERFACE}->{$interface}->{'inbandwidth'} ne '0') {
      $type .= "[InBW]" ;
      }

   if ($self->{_INTERFACE}->{$interface}->{'outbandwidth'} ne '0') {
      $type .= "[OutBW]" ;
      }

   # Flag interface with shaping profile
   if ($self->{_INTERFACE}->{$interface}->{'egress-shaping-profile'} ne '') {
      $type .= "[SHP]" ;
      }

   return $type ;
   }

# ---

sub parse_sp3_port {

   my $subn = "parse_sp3_port" ;

   my $self = shift ;

   my @scope = (undef, undef) ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my %hash_sp3port = ('interface' => 'none',) ;

   $self->cfg->scope_config_and_multiget(\@scope, 'config system sp3-port', \%hash_sp3port, \$self->{'_SP3PORT'}) ;
   warn "$obj:$subn interface line :" . $self->{_SP3PORT}->{'interface'} if $self->debug() ;
   my @interfaces = () ;
   if ((@interfaces) = $self->{_SP3PORT}->{'interface'} =~ /(\w+)(?:\")*(?:\s)*/g) {
      foreach my $interface (@interfaces) {
         warn "$obj:$subn found interface=$interface" if $self->debug() ;
         $self->{_INTERFACE}->{$interface}->{sp3port} = "yes" ;
         }
      }
   }

# ---

sub has_sp3_port {
   my $subn = "has_sp3_port" ;

   my $self   = shift ;
   my $return = 0 ;

   return (0) if (not(defined($self->{_SP3PORT}->{'interface'}))) ;

   if ($self->{_SP3PORT}->{'interface'} ne 'none') {
      $return = 1 ;
      }

   return ($return) ;
   }

# ---

sub ipcidr_network_broadcast {
   my $subn = "ip_network_broadcast" ;

   # Return an array with 1st element=ip in cidr, 2nd=network, 3rd=broadcast

   my $self   = shift ;
   my $ipmask = shift ;
   my @return = () ;

   warn "\n* Entering $obj:$subn with $ipmask=$ipmask" if $self->debug() ;

   if (not($ipmask) eq '') {
      my @ip_mask = split(/\s/, $ipmask) ;
      my $ipnet   = new Net::Netmask($ip_mask[0], $ip_mask[1]) ;
      push @return, $self->cidr($ipmask) ;
      push @return, $ipnet->base() ;
      push @return, $ipnet->broadcast() ;
      warn "$obj:$subn ip=" . $return[0] . " network=" . $return[1] . " broadcast=" . $return[2] if $self->debug() ;
      }
   else {
      @return = ('', '', '') ;
      }
   return (@return) ;
   }

# ---

sub cidr {
   my $subn = "cidr" ;

   my $self = shift ;
   my $ipm  = shift ;

   warn "\n* Entering $obj:$subn with ipm=$ipm" if $self->debug() ;

   return "" if (not(defined($ipm))) ;

   if ($ipm ne '') {
      $ipm =~ s/(\/|\s)255.255.255.255/\/32/ ;
      $ipm =~ s/(\/|\s)255.255.255.254/\/31/ ;
      $ipm =~ s/(\/|\s)255.255.255.252/\/30/ ;
      $ipm =~ s/(\/|\s)255.255.255.248/\/29/ ;
      $ipm =~ s/(\/|\s)255.255.255.240/\/28/ ;
      $ipm =~ s/(\/|\s)255.255.255.224/\/27/ ;
      $ipm =~ s/(\/|\s)255.255.255.192/\/26/ ;
      $ipm =~ s/(\/|\s)255.255.255.128/\/25/ ;
      $ipm =~ s/(\/|\s)255.255.255.0/\/24/ ;
      $ipm =~ s/(\/|\s)255.255.254.0/\/23/ ;
      $ipm =~ s/(\/|\s)255.255.252.0/\/22/ ;
      $ipm =~ s/(\/|\s)255.255.248.0/\/21/ ;
      $ipm =~ s/(\/|\s)255.255.240.0/\/20/ ;
      $ipm =~ s/(\/|\s)255.255.224.0/\/19/ ;
      $ipm =~ s/(\/|\s)255.255.192.0/\/18/ ;
      $ipm =~ s/(\/|\s)255.255.128.0/\/17/ ;
      $ipm =~ s/(\/|\s)255.255.0.0/\/16/ ;
      $ipm =~ s/(\/|\s)255.254.0.0/\/15/ ;
      $ipm =~ s/(\/|\s)255.252.0.0/\/14/ ;
      $ipm =~ s/(\/|\s)255.248.0.0/\/13/ ;
      $ipm =~ s/(\/|\s)255.240.0.0/\/12/ ;
      $ipm =~ s/(\/|\s)255.224.0.0/\/11/ ;
      $ipm =~ s/(\/|\s)255.192.0.0/\/10/ ;
      $ipm =~ s/(\/|\s)255.128.0.0/\/9/ ;
      $ipm =~ s/(\/|\s)255.0.0.0/\/8/ ;
      $ipm =~ s/(\/|\s)254.0.0.0/\/7/ ;
      $ipm =~ s/(\/|\s)252.0.0.0/\/6/ ;
      $ipm =~ s/(\/|\s)248.0.0.0/\/5/ ;
      $ipm =~ s/(\/|\s)240.0.0.0/\/4/ ;
      $ipm =~ s/(\/|\s)224.0.0.0/\/3/ ;
      $ipm =~ s/(\/|\s)192.0.0.0/\/2/ ;
      $ipm =~ s/(\/|\s)128.0.0.0/\/1/ ;
      $ipm =~ s/(\/|\s)0.0.0.0/\/0/ ;
      }

   return ($ipm) ;
   }

# ---

sub dump {
   my $subn = "dump" ;

   # This is for debugging purpose

   my $self = shift ;

   warn "\n\n* _INTERFACE:" ;
   print Dumper $self->{_INTERFACE} ;

   warn "\n\n* _INTERFACE_LIST:" ;
   print Dumper $self->{_INTERFACE_LIST} ;
   }

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;

