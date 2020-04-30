# ****************************************************
# *                                                  *
# *        C F G    S T A T I S T I Q U E S          *
# *                                                  *
# *  Parser object for fortigate config style        *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************

package cfg_statistics ;
my $obj = "cfg_statistics" ;

use Moose ;
use Data::Dumper ;

has 'cfg'       => (isa => 'cfg_dissector', 	is => 'rw') ;
has 'vd'        => (isa => 'cfg_vdoms', 	is => 'rw') ;
has 'debug'     => (isa => 'Maybe[Int]', 	is => 'rw', default => '0') ;

# Config objects we want to count for statistics

my %object_stats_list = (
   
   sys_interfaces => 'config system interface',
   sys_storage    => 'config system storage',
   sys_dns        => 'config system dns',
   sys_vpn_certificate_ca    => 'config vpn certificate ca',
   sys_vpn_certificate_local => 'config vpn certificate local',
   sys_session_helper => 'config system session-helper',
   sys_dhcp_server => 'config system dhcp server',
   sys_zone        => 'config system zone',

   # Admins
   sys_admin      => 'config system admin',

   # Users
   user_local      => 'config user local',
   user_fortitoken => 'config user fortitoken',
   user_group      => 'config user group',

   # Firewall ipv4
   fw_addr       => 'config firewall address',
   fw_addrgrp    => 'config firewall addrgrp',
   fw_serv_cat   => 'config firewall service category',
   fw_serv_cust  => 'config firewall service custom',
   fw_serv_group => 'config firewall service group',
   fw_schedule   => 'config firewall schedule recurring',
   fw_ip_pools   => 'config firewall ippool',
   fw_vip        => 'config firewall vip',
   fw_vip_grp    => 'config firewall vipgrp',
   fw_policy     => 'config firewall policy',
   fw_local_in_policy  => 'config firewall local-in-policy',
   fw_interface_policy => 'config firewall interface-policy',
   fw_profile_protocol_options => 'config firewall profile-protocol-options',
   fw_deep_inspection_options => 'config firewall deep-inspection-options',
   fw_identity_based_route => 'config firewall identity-based-route',
   fw_shaper_traffic_shaper => 'config firewall shaper traffic-shaper',
   fw_multicast_address => 'config firewall multicast-address',
   fw_DoS_policy  => 'config firewall DoS-policy',
   fw_sniffer     => 'config firewall sniffer',

   # Endpoint control
   ep_profile     => 'config endpoint-control profile',

   # Application 
   app_list      => 'config application list',

   # IPS
   ips_sensor    => 'config ips sensor',

   # Dos
   fw_DoS_policy6 => 'config firewall DoS-policy6',

   # DLP
   dlp_filepattern    => 'config dlp filepattern',
   dlp_fp_sensitivity => 'config dlp fp-sensitivity',
   dlp_sensor         => 'config dlp sensor',

   # WANopt
   wanopt_profile => 'config wanopt profile',

   # Firewall ipv6
   fw_addr6    => 'config firewall address6',
   fw_addrgrp6 => 'config firewall addrgrp6',
   fw_policy6  => 'config firewall policy6',
   fw_local_in_policy6 => 'config firewall local-in-policy6', 
   fw_interface_policy6 => 'config firewall sniff-interface-policy6',
   fw_DoS_policy6  => 'config firewall DoS-policy6',

   # Antivirus
   antivirus_profile => 'config antivirus profile',

   # Webfilter
   wf_ftgd_local_cat => 'config webfilter ftgd-local-cat',
   wf_content        => 'config webfilter content',
   wf_content_header => 'config webfilter content-header',
   wf_urlfilter      => 'config webfilter urlfilter',
   wf_profile        => 'config webfilter profile',
   wf_override       => 'config webfilter override',
   wf_override_user  => 'config webfilter override-user',
   wf_ftgd_warning   => 'config webfilter ftgd-warning',
   wf_ftdg_local_rating => 'config webfilter ftgd-local-rating',

   # Spam filter
   sf_bword          => 'config spamfilter bword',
   sf_bwl            => 'config spamfilter bwl',
   sf_mheader        => 'config spamfilter mheader',
   sf_dnsbl          => 'config spamfilter dnsbl',
   sf_iptrust        => 'config spamfilter iptrust',
   sf_profile        => 'config spamfilter profile',

   # VPN SSL
   vpn_ssl_web_portal => 'config vpn ssl web portal',

   # IPsec interface mode
   ipsec_phase1_interface => 'config vpn ipsec phase1-interface',
   ipsec_phase2_interface => 'config vpn ipsec phase2-interface',
   ipsec_phase1           => 'config vpn ipsec phase1',
   ipsec_phase2           => 'config vpn ipsec phase2',

   # Voip
   voip_profile      => 'config voip profile',

   # DNS database
   sys_dns_database  => 'config system dns-database',
   sys_dns_server    => 'config system dns-server',
) ;

# ---

sub BUILD {
my $subn = "BUILD" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn with debug=".$self->debug if $self->debug;
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
      return ($self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}}) ;
      }

   else {
      if (not(defined($options{'thirdkey'}))) {
         return ($self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}}->{$options{'subkey'}}) ;
         }
      else {
         return ($self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}}->{$options{'subkey'}}->{$options{'thirdkey'}}) ;
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

   $self->{VDOM_STATS}->{$options{'vdoms'}}->{$options{'key'}} = $options{'value'} ;
   }

# ---

sub increase {
   my $subn = "increase" ;

   my $self    = shift ;
   my %options = @_ ;

   # sanity
   die "-vdom requires"  if (not(defined($options{'vdom'}))) ;
   die "-key required"   if (not(defined($options{'key'}))) ;


   # initialise
   $self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}} = 0
     if (not(defined($self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}}))) ;

   $self->{VDOM_STATS}->{$options{'vdom'}}->{$options{'key'}}++ ;
   }

# ---

sub object_statistics {
   my $subn = "object_statistics" ;

   my $self = shift ;

   my @scope      = (undef, undef) ;
   my @edit_scope = (undef, undef) ;
   my $id         = "" ;
   my ($object, $count) = undef ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list()) {

      foreach $object (keys %object_stats_list) {

         warn "\n* Entering $obj:$subn processing vdom=$vdom object=$object config_statement=" . $object_stats_list{$object} if $self->debug() ;
         $count                                    = 0 ;
         @scope                                    = $self->cfg->scope_vdom($vdom) ;
         $self->{VDOM_STATS}->{$vdom}->{$object} = 0 ;
         my $ok = $self->cfg->scope_config(\@scope, $object_stats_list{$object}) ;

         if ($ok) {
            $edit_scope[0] = $scope[0] ;
            $edit_scope[1] = $scope[1] ;

            while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
               $count++ ;
               warn "$obj:$subn vdom=$vdom object=$object count=$count edit_id=$id" if $self->debug() ;

               # set scope for next round
               $edit_scope[0] = $edit_scope[1] ;
               $edit_scope[1] = $scope[1] ;
               }    # While edit

            # Grand-total (summary of objects within all vdoms)
	    $self->{TOTAL_STATS}->{$object} = 0 if not($self->{TOTAL_STATS}->{$object});
	    $self->{TOTAL_STATS}->{$object} += $count;

	    # Counting by vdom
            warn "$obj:$subn vdom=$vdom object=$object\tfound count=$count - total=".$self->{TOTAL_STATS}->{$object}  if $self->debug() ;
            $self->{VDOM_STATS}->{$vdom}->{$object} = $count ;
            }    # OK config scope is found


         }    #foreach objects
      }    # foreach vdom
   }

# ---

sub dump {
my $subn = "dump" ;

   my $self = shift ;

   my $vd_count = 0 ;

   warn "\n* Entering $subn" if $self->debug ;

   print "Statistics by vdoms : vdom_name, object, count\n" ;
   print "----------------------------------------------\n\n";

   foreach my $vdom ($self->cfg->get_vdom_list()) {
      $vd_count++ ;
      my @sorted_list = sort { $a cmp $b || length($a) <=> length($b)} keys %{$self->{VDOM_STATS}->{$vdom}} ;
      foreach my $item (@sorted_list) {
         printf "%-15s\t%-30s\t%-30s\n", $vdom, $item, $self->{VDOM_STATS}->{$vdom}->{$item} ;
         }
      }

   # Only if more than 1 vdom
   if ($vd_count > 1) {
      print "\n\nOverall statistics for the $vd_count vdoms : object, count\n";
      print "--------------------------------------------------- \n\n";
      my @sorted_list = sort { $a cmp $b || length($a) <=> length($b)} keys %{$self->{TOTAL_STATS}} ;
      foreach my $item (@sorted_list) {
         printf "%-30s\t%-30s\n", $item, $self->{TOTAL_STATS}->{$item} ;
         }
      }
   }


# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
