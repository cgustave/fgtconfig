# ****************************************************
# *                                                  *
# *          C F G   D I S P L A Y                   *
# *                                                  *
# *  Object grouping all display functions           *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#
# All display output is done from this object for global and vdom
#

package cfg_display ;
my $obj = "cfg_display" ;

use Moose ;
use Term::ANSIColor qw( colored ) ;

has 'cfg'   => (isa => 'cfg_dissector',  is => 'rw', required => 1) ;
has 'intfs' => (isa => 'cfg_interfaces', is => 'rw', required => 1) ;
has 'glo'   => (isa => 'cfg_global',     is => 'rw', required => 1) ;
has 'vd'    => (isa => 'cfg_vdoms',      is => 'rw', required => 1) ;
has 'stat'  => (isa => 'cfg_statistics', is => 'rw', required => 1) ;
has 'debug' => (isa => 'Maybe[Int]',     is => 'rw', default  => '0') ;
has 'nb_vdoms' => (isa =>'Int', is => 'rw', default => '1');

# flags to display or hide sections

has 'stats_flag'   => (isa => 'Maybe[Int]', is => 'rw', default => '0') ;
has 'routing_flag' => (isa => 'Maybe[Int]', is => 'rw', default => '0') ;
has 'ipsec_flag'   => (isa => 'Maybe[Int]', is => 'rw', default => '0') ;
has 'color_flag'   => (isa => 'Maybe[Int]', is => 'rw', default => '0') ;

# splicfongi dir
has splitconfigdir => (isa => 'Str', is => 'rw', default => '.') ;

my $fwd_max_count       = 0 ;
my $href_forward_domain = () ;    # For TP mode to detect when a FWD has more than 2 interfaces
my %hash_warning_fwd    = () ;

# Ansi foreground colors
my $color_red    = "\e[31m" ;
my $color_white  = "\e[37m" ;
my $color_green  = "\e[32m" ;
my $color_yellow = "\e[33m" ;

# ---

sub BUILD {
my $subn = "BUILD" ;

   my $self = shift ;
   warn "\n* Entering $obj:$subn with debug=".$self->debug if $self->debug ;
   }

# ---

sub display {
   my $subn = "display" ;

   # Generic display call

   my $self = shift ;
   $self->{_FHOUT} = shift ;

   $self->{_FHOUT} = 'STDOUT' if not defined($self->{_FHOUT}) ;

   warn "\n* Entering $obj:$subn output=" . $self->{_FHOUT} if $self->debug() ;

   # Open the output filehandle
   if (not($self->{_FHOUT} eq 'STDOUT')) {

      # Get splitconfig dir
      my $splitconfig = $self->splitconfigdir() ;
      $splitconfig = "." if $splitconfig eq "-config" ;
      warn "$obj:$subn splitconfig: $splitconfig" if $self->debug() ;

      # Open filehandle for output
      open FHOUT, '>:encoding(iso-8859-1)', "$splitconfig/_config_summary.conf" or die "open: $!" ;
      select(FHOUT) ;
      }

   $self->display_global() ;
   $self->display_aggregate_redundant_switch() ;
   $self->display_all_vdoms() ;
   close(FHOUT) ;
   }

# ---

sub color {

   # converts 0/1 to no/YES in colors
   # returns $self so methods can be chained
   # what

   my $self   = shift ;
   my $status = shift ;

   return "   " if (not(defined($status))) ;

   # match conversion to display user
   $status = 'no'  if ($status eq '0') ;
   $status = 'YES' if ($status eq '1') ;

   return ($status) if (not($self->color_flag())) ;

   if ($status =~ /no|default/) {

      if ($self->color()) {
         $status = $color_green . $status . $color_white . " " ;
         }
      }

   else {
      if ($self->color()) {
         $status = $color_red . $status . $color_white ;
         }
      }

   return ($status) ;
   }

# ---

sub fcolor {
   my $subn = "fcolor" ;

   # add ANSI colot control characted to given string
   # reposition the cursor at the end of the message
   # compensating the added control characters

   my $self    = shift ;
   my $text    = shift ;
   my $color   = shift ;
   my $newText = "" ;

   warn "\n*Entering $subn with text=$text color=$color" if $self->debug() ;

   return ($text) if (not($self->color_flag())) ;

   # Ansi forground colours

   my %colors = (
      'black',   "\e[30m", 'red',  "\e[31m", 'green', "\e[32m", 'yellow', "\e[33m", 'blue', "\e[34m",
      'magenta', "\e[35m", 'cyan', "\e[36m", 'white', "\e[37m", 'none',   "\e[0m",
   ) ;

   my $curMemorise = "\033[s" ;
   my $curReturn   = "\033[u" ;

   # Sanity
   die "unknown color" if (not(defined($colors{$color}))) ;

   if ($self->color()) {

      # Memorize cursor postion
      $newText .= $curMemorise ;

      # print in color
      $newText .= $colors{$color} . $text ;

      # get back to cursor postion
      $newText .= $curReturn ;

      # move cursor on the right by the length of message
      $newText .= "\033[" . length($text) . 'C' ;
      return ($newText) ;
      }
   }

#####################   G L O B A L    #####################

sub display_global {
   my $subn = "display_global" ;

   # ex:
   # =====================================================================================================================================
   #  Model  |     Firmware     |     HA     |      Hostname      |   Fortimanager    |  Fortianalyser  |        Warning Flags           |
   #  FG3K8A |  4.00 B 099 (FW) | standalone |  FG3K8A3407600041  |  192.168.182.126  | 192.168.182.168 |                                |
   # =====================================================================================================================================

   my $self                  = shift ;
   my $display_admin_passwd  = "no" ;
   my $display_all_trusthost = "no" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Format admin user output

   if ($self->glo->get_admin_no_passwd())     { $display_admin_passwd  = "YES" ; }
   if ($self->glo->get_admin_all_trusthost()) { $display_all_trusthost = "YES" ; }

   print "\n" ;
   print
"|=============================================================================================================================================================================|\n"
     ;
   print
"| Model  | Firmware version, build, tag  |     HA     |       Hostname       |  Fortimanager   |  Fortianalyzer  |  Fortianalyzer2 |  Fortianalyzer3 |          Nb VDOMs      |\n"
     ;

   printf "| %6s | %-6s B%-4s(%-3s) %7s %4s| %10s | %20.20s | %15.15s | %15.15s | %15.15s | %15.15s | %22.22s |\n",
     $self->glo->cfg->plateform(),
     $self->glo->cfg->version(),
     $self->glo->cfg->build(),
     $self->glo->cfg->type(),
     $self->glo->cfg->fos_carrier(),
     $self->glo->cfg->build_tag(),
     $self->glo->dataGet(ruleId => 'system.ha',                   key => 'mode'),
     $self->glo->dataGet(ruleId => 'system.global',               key => 'hostname'),
     $self->glo->dataGet(ruleId => 'warn-central-mgmt-fmg',       key => 'ip'),
     $self->glo->dataGet(ruleId => 'logdevice.fortianalyzer.ip',  key => 'fortianalyzer_ip'),
     $self->glo->dataGet(ruleId => 'logdevice.fortianalyzer2.ip', key => 'fortianalyzer_ip'),
     $self->glo->dataGet(ruleId => 'logdevice.fortianalyzer3.ip', key => 'fortianalyzer_ip'),
     $self->cfg->get_nb_vdoms() ;

   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   print
"|                              Fortiguard                                    |                 |     Syslog      |     Syslog2     |     Syslog3     |       Admin users      |\n"
     ;
   printf
"| mod_hostname=%-3s  mgmt=%-3s  webfilter=%-3s  antispam=%-3s  avquery=%-3s       |                 | %15.15s | %15.15s | %15.15s | no_pwd=%-3s trusted=%-3s |\n",
     $self->color($self->glo->hasMatched(ruleId => 'system.fortiguard.hostname')),
     $self->color($self->glo->hasMatched(ruleId => 'system.fortiguard.central-mgmt-status')),
     $self->color($self->glo->hasMatched(ruleId => 'system.fortiguard.webfilter-status')),
     $self->color($self->glo->hasMatched(ruleId => 'system.fortiguard.antispam-status')),
     $self->color($self->glo->hasMatched(ruleId => 'system.fortiguard.avquery-status')),
     $self->glo->dataGet(ruleId => 'logdevice.syslogd.ip',  key => 'syslog_ip'),
     $self->glo->dataGet(ruleId => 'logdevice.syslogd2.ip', key => 'syslog_ip'),
     $self->glo->dataGet(ruleId => 'logdevice.syslogd3.ip', key => 'syslog_ip'),
     $self->color($display_admin_passwd),
     $self->color($display_all_trusthost) ;

   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   # Prints warnings with colors if asked
   print "| warn: " ;
   $self->printfColor($self->display_warnings(color => $self->color_flag), 166) ;
   print "|\n" ;

   print
"|=============================================================================================================================================================================|\n\n"
     ;
   }

# ---

sub printfColor {
   my $subn = "printfColor" ;

   # In replace for printf "%-<length>",<variable>
   # unlike printf, it adds the necessary chars on the length size to consider the additional
   # ANSI control characters added by the color and cursor movement
   # With it, the cursor position after the command is the same wether there is color or not

   my $self     = shift ;
   my $variable = shift ;
   my $length   = shift ;

   # Sanity
   die "need variable" if (not(defined($variable))) ;
   die "need length"   if (not(defined($length))) ;

   my $count   = 0 ;
   my $match   = 0 ;
   my $origLen = length($variable) ;
   my $origVar = $variable ;

   # Remove control characters one by one in the message and count there corresponding string size
   while (($match) = $variable =~ /((\033\[[su])|(\e\[\d+m)|(\e\[\d+C))/) {

      #warn "variable=$variable match_len=".length($match);
      $count += length($match) ;
      ($variable) =~ s/((\033\[[su])|(\e\[\d+m)|(\e\[\d+C))// ;
      }

   # Increase the length by the number of control characters discovered
   my $len = $length + $count ;

   # prints original message with control characters by with the new calculated length applied
   printf "%-" . $len . "s", $origVar ;
   }

# ---

sub display_warnings {
   my $subn = "display_warnings" ;

   my $self    = shift ;
   my %options = @_ ;
   my $color   = defined($options{'color'}) ? $options{'color'} : 0 ;
   my $vdom    = $options{'vdom'} ;

   my $hrefTable  = undef ;
   my $warnings   = "" ;
   my %colorTable = (
      low    => 'yellow',
      medium => 'magenta',
      high   => 'red'
   ) ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   # Get the warning hash reference for global
   if (not(defined($vdom))) {
      $hrefTable = $self->glo->warnTable() ;
      }
   else {
      $hrefTable = $self->vd->warnTable(vdom => $vdom) ;
      }

   # build warning string with the color chars and return the compiled string
   foreach my $warn (keys %{$hrefTable}) {
      my $severity = $hrefTable->{$warn}->{'severity'} ;
      warn "$obj:$subn warn=$warn severity=$severity" if $self->debug() ;

      if ($color) {
         $warn = $self->fcolor($warn, $colorTable{$severity}) ;
         }

      $warnings .= "$warn " ;
      }
   return $warnings ;
   }

# ---

sub display_aggregate_redundant_switch {
   my $subn = "display_aggregate_redundant_switch" ;

   #=============================================================================
   #AGGREGATE AND REDUNDANT INTERFACES
   #-----------------------------------------------------------------------------
   #Interface           |   type     | Members                                  |
   #----------------------------------------------------------------------------|
   #aggp3p4             | aggregate  | port1 port2 port3 port4                  |
   #=============================================================================

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   if ($self->intfs->has_aggregate_redundant_switch_interface()) {

      print "|====================================================================================================|\n" ;
      print "|                             Aggregate, Redundant and Switch interfaces                             |\n" ;
      print "|----------------------------------------------------------------------------------------------------|\n" ;
      print "| Interface                 |    type     | Members                                                  |\n" ;
      foreach my $int ($self->intfs->get_all_aggregate_redundant_switch_array()) {
         print "|---------------------------|-------------|----------------------------------------------------------|\n" ;
         printf "| %-25s | %-11s | %-56s |\n",
           $int,
           $self->intfs->get_aggregate_redundant_switch(name => $int, key => 'type'),
           $self->intfs->get_aggregate_redundant_switch(name => $int, key => 'members') ;
         }
      print "|=================================+==================================================================|\n\n" ;
      }
   }

#####################   V D O M    #####################

sub display_all_vdoms {
   my $subn = "display_all_vdoms" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   foreach my $vdom ($self->cfg->get_vdom_list()) {
      warn "$obj:$subn vdom=$vdom" if $self->debug() ;
      #my $opmode = $self->vd->dataGet(vdom => $vdom, ruleId => 'system.settings.generic', key => 'opmode') ;
      my $opmode = $self->cfg->get_vdom_opmode($vdom) ;
      $opmode = 'nat' if ($opmode eq '') ;
      if ($opmode eq 'transparent') {
         $self->display_tp_vdom($vdom) ;
         }
      elsif ($opmode eq 'nat') {
         $self->display_nat_vdom($vdom) ;
         }

      if ($self->routing_flag()) {
         $self->display_vdom_routing($vdom) ;
         }

      print
"|=============================================================================================================================================================================|\n"
        ;
      print "\n" ;
      }
   }

# ---

sub display_tp_vdom {
   my $subn = "display_tp_vdom" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   my $vdom_d = $vdom ;

   if (   ($self->glo->dataGet(ruleId => 'system.global', key => 'management-vdom') eq $vdom)
      and ($self->glo->dataGet(ruleId => 'system.global', key => 'vdom-admin') eq 'enable'))
   {
      $vdom_d = $self->fcolor("[ $vdom ]", 'red') ;
      }
   else {
      $vdom_d = $self->fcolor($vdom, 'cyan') ;
      }

   print
"|=============================================================================================================================================================================|\n"
     ;
   printf "| vdom: " ;
   $self->printfColor($vdom_d, 50) ;

   my $manageip = $self->vd->dataGet(vdom => $vdom, ruleId => 'system.settings.generic', key => 'manageip') ;
   printf " opmode: TP   manage ip: %-18s                                                                         |\n",
     $self->intfs->cidr($manageip) ;
   printf
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   printf "| warn: " ;
   $self->printfColor($self->display_warnings(vdom => $vdom, color => $self->color_flag), 166) ;
   print "|\n" ;
   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   $self->display_nat_and_tp_common_features($vdom) ;
   $self->display_tp_specific_features($vdom) ;
   $self->display_authentication($vdom) ;
   $self->display_policies_and_interface_policies($vdom) ;
   $self->display_vdom_statistic($vdom) if $self->stats_flag() ;

   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   print
"| interface (alias)         | zone          | physical / flags      |  vlan  |  fwd  |state |  speed  | admin access                                                          |\n"
     ;
   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   # Go through the different types of interfaces: aggregated,redundant, physical with associated vlans

   $fwd_max_count       = 0 ;
   $href_forward_domain = () ;
   %hash_warning_fwd    = () ;
   foreach my $type ('aggregate', 'redundant', 'fctrl-trunk', 'switch', 'vap-switch', 'physical', 'vdom-link', 'tunnel') {
      foreach my $interface ($self->intfs->get_interface_list()) {
         next if (not $self->intfs->defined(name => $interface, key => 'type')) ;    # This is generally vlans;
         if ($self->intfs->get(name => $interface, key => 'type') eq $type) {
            warn "interface=$interface type=$type" if $self->debug() ;

            # Display physical interface
            if ($self->intfs->get(name => $interface, key => 'vdom') eq $vdom) {
               $self->display_tp_interface($interface, "") ;
               }

            # Display all vlans from this physicall interface
            foreach my $vint ($self->intfs->return_vlan_interface_in_vdom($vdom, $interface)) {
               $self->display_tp_interface($vint, " ") ;
               }

            }    # if type
         }    # foreach interface
      }    # foreach type

   # Warning for fwd > 2 and not port-pair config used
   my $portPair = $self->vd->get(vdom => $vdom, key => 'port-pair') ;
   $portPair = "no" if not(defined($portPair)) ;
   if ($fwd_max_count > 2 and ($portPair eq "no")) {
      my $display = " warnings: there are forward domains with more than 2 interfaces : " ;
      foreach my $key (keys %hash_warning_fwd) {
         $display .= " $key(" . $hash_warning_fwd{$key} . ") " ;
         }
      print "| " . $self->fcolor($display, 'yellow') . "\n" ;
      }
   }

# ---

sub display_policies_and_interface_policies {
   my $subn = "display_policies_and_interface_policies" ;

   # This piece is common between nat/route and transparent mode

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   # Policy : UTM features line first 

   printf "|         %9s policies: applist=%-3s     ipssensor=%-3s  av=%-3s         webfilter=%-3s dnsfilter=%3s voip=%-3s                                                              |\n",
     $self->vd->get(vdom => $vdom, key => 'nb_policy'),
     $self->color($self->vd->get(vdom => $vdom, key => 'applist')),
     $self->color($self->vd->get(vdom => $vdom, key => 'ipssensor')),
     $self->color($self->vd->get(vdom => $vdom, key => 'av')),
     $self->color($self->vd->get(vdom => $vdom, key => 'webfilter')),
     $self->color($self->vd->get(vdom => $vdom, key => 'dnsfilter')),
     $self->color($self->vd->get(vdom => $vdom, key => 'voip_profile')),
     ;

   # Policy : non UTM features line

   printf "|                           : shaping=%-3s     logtraffic=%-3s webcache=%-3s   learning=%-3s                                                                                      |\n",
     $self->color($self->vd->get(vdom => $vdom, key => 'shaping')),
     $self->color($self->vd->get(vdom => $vdom, key => 'logtraffic')),
     $self->color($self->vd->get(vdom => $vdom, key => 'webcache')),
     $self->color($self->vd->get(vdom => $vdom, key => 'learning-mode')),
     ;

    # Interface policy 

   printf
"| %7s interface_policies: applist=%-3s     ipssensor=%-3s  DoS=%-3s        av=%-3s        webfilter=%-3s dlp=%-3s                                                               |\n",
     $self->vd->get(vdom => $vdom, key => 'nb_interface_policy'),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'application-list-status')),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'ips-sensor-status')),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'ips-DoS-status')),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'av-profile-status')),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'webfiltering-profile-status')),
     $self->color($self->vd->get(vdom => $vdom, key => 'interface_policy', subkey => 'dlp-sensor-status')) ;

   printf
"|       %7s DoS_policies: DoS=%-3s                                                                                                                                         |\n",
     $self->vd->get(vdom => $vdom, key => 'nb_dos_policy'),
     $self->color($self->vd->get(vdom => $vdom, key => 'dos_policy')) ;
   }

# ---

sub display_vdom_statistic {
   my $subn = "display_vdom_statistic" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   printf
"|        firewall ipv4 :   policy=%-5s   addr=%-5s     addrgrp=%-5s   serv_cust=%-5s   schedule=%-5s   ip_pools=%-5s   vip=%-5s   vip_grp=%-5s                        |\n",
     $self->vd->get(vdom => $vdom, key => 'nb_policy'),
     $self->stat->get(vdom => $vdom, key => 'fw_addr'),
     $self->stat->get(vdom => $vdom, key => 'fw_addrgrp'),
     $self->stat->get(vdom => $vdom, key => 'fw_serv_cust'),
     $self->stat->get(vdom => $vdom, key => 'fw_schedule'),
     $self->stat->get(vdom => $vdom, key => 'fw_ip_pools'),
     $self->stat->get(vdom => $vdom, key => 'fw_vip'),
     $self->stat->get(vdom => $vdom, key => 'fw_vip_grp'),
     ;


   printf
"|        firewall ipv6 :   policy6=%-5s  addr6=%-5s    addrgrp6=%-5s                                                                                                       |\n",
     $self->stat->get(vdom => $vdom, key => 'fw_policy6'),
     $self->stat->get(vdom => $vdom, key => 'fw_addr6'),
     $self->stat->get(vdom => $vdom, key => 'fw_addrgrp6'),
     ;
   }

# ---

sub display_authentication {
   my $subn = "display_authentication" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   printf
"|                       auth: local=%-3s       fsso=%-3s       ldap=%-3s       radius=%-3s    tacacs=%-3s    token=%-3s                                                             |\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.userlocal')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.fsso')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.ldap')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.radius')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.tacacs')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.fortitoken')),
     ;
   }

# ---

sub display_nat_and_tp_common_features {
   my $subn = "display_nat_and_tp_common_features" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   printf
"|                   features: snat=%-3s        ipsec=%-3s      webproxy=%-3s   wanopt=%-3s    gtp=%-3s       ssync=%-3s     client_rep=%-3s    dev_ident=%-3s                         |\n",
     $self->color($self->vd->get(vdom => $vdom, key => 'snat')),    # checked in policies
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.ipsec')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.webproxy')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.wanopt')),
     $self->color($self->vd->get(vdom => $vdom, key => 'gtp')),      # checked in policies
     $self->color($self->vd->get(vdom => $vdom, key => 'ssync')),    # Checked in global with vdoms as arguments
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.client-reputation')),
     $self->color($self->vd->get(vdom => $vdom, key => 'device-identification')),    # checked in cfg_interface
     ;

   printf
"|                   features: localinpol=%-3s  anypol=%-3s     mcastpol=%-3s   geoaddr=%-3s   fqdnaddr=%-3s  logdisc=%-3s                                                           |\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.local-in-policy')),
     $self->color($self->vd->get(vdom => $vdom, key => 'anypolicy')),                # checked in policies
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.multicast-policy')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.firewall.geoaddress')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.firewall.fqdnaddress')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.log.disk')),
     ;
   }

# ---

sub display_tp_specific_features {
   my $subn = "display_tp_specific_features" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   printf
"|                TP features: port-pair=%3s                                                                                                                                   |\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.tp.port-pair')) ;
   }

# ---

sub display_tp_interface {
   my $subn = "display_tp_interface" ;

   my $self      = shift ;
   my $interface = shift ;
   my $indent    = shift || "" ;

   warn "\n* Entering $obj:$subn with interface=$interface indent=$indent" if $self->debug() ;

   my $type           = $self->intfs->interface_flags($interface) ;
   my $disp_interface = $indent . $interface ;
   if ($self->intfs->get(name => $interface, key => 'alias') ne "") {
      $disp_interface .= " (" . $self->intfs->get(name => $interface, key => 'alias') . ")" ;
      }
   my $status = ($self->intfs->get(name => $interface, key => 'status')) ;

   # Forward domain accounting
   my $forward_domain = $self->intfs->get(name => $interface, key => 'forward-domain') ;
   $forward_domain = 0 if ($forward_domain eq '') ;
   $href_forward_domain->{$forward_domain} = 0 if (not(defined($href_forward_domain->{$forward_domain}))) ;

   # count forward domain but ignore vap-switch or if status is down
   $href_forward_domain->{$forward_domain}++
     if ((not($type =~ /[VSH]/) and $status eq 'up')) ;

   if ($href_forward_domain->{$forward_domain} > 2) {
      $fwd_max_count = ($href_forward_domain->{$forward_domain} > $fwd_max_count) ? $href_forward_domain->{$forward_domain} : $fwd_max_count ;
      $hash_warning_fwd{$forward_domain} = $href_forward_domain->{$forward_domain} ;
      }

   printf "| %-26.26s| %-14.14s| %-22.22s| %-6.6s | %-5.5s | %-4.4s | %-7.7s | %-69.69s |\n",
     $disp_interface,
     $self->intfs->get(name => $interface, key => 'zone'),
     $self->intfs->get(name => $interface, key => 'interface') . $type,
     $self->intfs->get(name => $interface, key => 'vlanid'),
     $forward_domain,
     $self->intfs->get(name => $interface, key => 'status'),
     $self->intfs->get(name => $interface, key => 'speed'),
     $self->intfs->get(name => $interface, key => 'allowaccess') ;
   }

# ---

sub display_nat_vdom {
   my $subn = "display_nat_vdom" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   my $vdom_d = $vdom ;

   if (   ($self->glo->dataGet(ruleId => 'system.global', key => 'management-vdom') eq $vdom)
      and ($self->glo->dataGet(ruleId => 'system.global', key => 'vdom-admin') eq 'enable'))
   {
      $vdom_d = $self->fcolor("[ $vdom ]", 'red') ;
      }
   else {
      $vdom_d = $self->fcolor($vdom, 'cyan') ;
      }

   print
"|=============================================================================================================================================================================|\n"
     ;
   printf "| vdom: " ;
   $self->printfColor($vdom_d, 50) ;
   printf " opmode: %-3s                                                                                                        |\n",
     $self->cfg->get_vdom_opmode($vdom) ;
   printf
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   print "| warn: " ;
   $self->printfColor($self->display_warnings(vdom => $vdom, color => $self->color_flag), 166) ;
   print "|\n" ;
   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   printf
"|                   features: gre=%-3s         pptp=%-3s       l2tp=%-3s       ssl=%-3s       dnstrans=%-3s  wccp=%-3s      icap=%-3s                                                |\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.gre')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.pptp')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.l2tp')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.sslvpn')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.dns-translation')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.wccp')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.icap')) ;

   printf
"|                   features: vip=%-3s         vip_lb=%-3s     vip_slb=%-3s    centnat=%-3s                                                                                       |\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.vip.standard')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.vip.load-balance')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.vip.server-load-balance')),
     $self->color($self->vd->get(vdom => $vdom, key => 'centnat')) ;    # from policy parsing

   $self->display_nat_and_tp_common_features($vdom) ;
   $self->display_authentication($vdom) ;
   $self->display_policies_and_interface_policies($vdom) ;
   $self->display_vdom_statistic($vdom) if $self->stats_flag() ;

   printf
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   printf
"| interface (alias)         | zone          | physical / flags      |  mode  | vlan |     ip address     |     network     |    broadcast    |state |PS|MO|   admin access    |\n"
     ;
   printf
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   # Go through the different types of interfaces: aggregated,redundant, physical with associated vlans

   foreach my $type ('hard-switch', 'aggregate', 'redundant', 'fctrl-trunk', 'switch', 'vap-switch', 'physical', 'vdom-link', 'tunnel', 'transport','loopback') {

      foreach my $interface ($self->intfs->get_interface_list()) {
         next if (not $self->intfs->defined(name => $interface, key => 'type')) ;    # This is generally vlans;
         if ($self->intfs->get(name => $interface, key => 'type') eq $type) {
            warn "interface=$interface type=$type" if $self->debug() ;

            # Display physical interface
            if ($self->intfs->get(name => $interface, key => 'vdom') eq $vdom) {
               $self->display_nat_interface($interface, "") ;
               $self->display_nat_secondary_interface($interface) ;
               if ($self->ipsec_flag() and ($self->intfs->defined(name => $interface, key => '_has_ipsec'))) {
                  $self->display_ipsec_interface($vdom, $interface) ;
                  }
               }

            # Display all vlans from this physical interface
            foreach my $vint ($self->intfs->return_vlan_interface_in_vdom($vdom, $interface)) {
               $self->display_nat_interface($vint, " ") ;
               $self->display_nat_secondary_interface($vint) ;
               if ($self->ipsec_flag() and ($self->intfs->defined(name => $vint, key => '_has_ipsec'))) {
                  $self->display_ipsec_interface($vdom, $vint) ;
                  }
               }

            }
         }
      }
   }

# ---

sub display_nat_interface {
   my $subn = "display_nat_interface" ;

   my $self      = shift ;
   my $interface = shift ;
   my $indent    = shift || "" ;

   warn "\n* Entering $obj:$subn with interface=$interface indent=$indent" if $self->debug() ;

   my $type = $self->intfs->interface_flags($interface) ;

   my $disp_interface = $indent . $interface ;
   if ($self->intfs->get(name => $interface, key => 'alias') ne "") {
      $disp_interface .= " (" . $self->intfs->get(name => $interface, key => 'alias') . ")" ;
      }

   printf "| %-26.26s| %-14.14s| %-22.22s| %-6.6s | %-4.4s | %18.18s | %15.15s | %15.15s | %-4.4s |%-2.2s|%-2.2s| %-17.17s |\n",
     $disp_interface,
     $self->intfs->get(name => $interface, key => 'zone'),
     $self->intfs->get(name => $interface, key => 'interface') . $type,
     $self->intfs->get(name => $interface, key => 'mode'),
     $self->intfs->get(name => $interface, key => 'vlanid'),
     $self->intfs->get(name => $interface, key => 'ip'),
     $self->intfs->get(name => $interface, key => 'network'),
     $self->intfs->get(name => $interface, key => 'broadcast'),
     $self->intfs->get(name => $interface, key => 'status'),
     $self->intfs->get(name => $interface, key => 'gwdetect'),
     $self->intfs->get(name => $interface, key => 'mtu-override'),
     $self->intfs->get(name => $interface, key => 'allowaccess') ;

   }

# ---

sub display_nat_secondary_interface {
   my $subn = "display_nat_secondary_interface" ;

   my $self      = shift ;
   my $interface = shift ;

   my ($ip, $network, $broadcast) = undef ;

   warn "\n* Entering obj:$subn with interface=$interface" if $self->debug() ;

   if ($self->intfs->defined(name => $interface, key => 'secondary')) {
      foreach my $id ($self->intfs->get_all_intf_secondary_array($interface)) {

         # Update ip in cidr + network + broadcast
         ($ip, $network, $broadcast) = $self->intfs->ipcidr_network_broadcast($self->intfs->get(name => $interface, secondary => $id, key => 'ip')) ;

         $self->intfs->set(name => $interface, secondary => $id, key => 'ip',        value => $ip) ;
         $self->intfs->set(name => $interface, secondary => $id, key => 'network',   value => $network) ;
         $self->intfs->set(name => $interface, secondary => $id, key => 'broadcast', value => $broadcast) ;

         # only show ping-server enabled with 'X'
         if ($self->intfs->get(name => $interface, secondary => $id, key => 'gwdetect') eq "enable") {
            $self->intfs->set(name => $interface, secondary => $id, key => 'gwdetect', value => 'X') ;
            }
         else {
            $self->intfs->set(name => $interface, secondary => $id, key => 'gwdetect', value => '') ;
            }

         # Shortcut allowaccess
         $self->intfs->shortcut_allowaccess(\$self->intfs->get(name => $interface, secondary => $id, key => 'allowaccess')) ;

         printf "| %-26.26s| %-14.14s| %-22.22s| %6.6s | %-4.4s | %18.18s | %15.15s | %15.15s | %-4.4s |%-2.2s|%-2.2s| %-17.17s |\n",
           "   secondary " . $id, "", "", "", "",
           $self->intfs->get(name => $interface, secondary => $id, key => 'ip'),
           $self->intfs->get(name => $interface, secondary => $id, key => 'network'),
           $self->intfs->get(name => $interface, secondary => $id, key => 'broadcast'), "",
           $self->intfs->get(name => $interface, secondary => $id, key => 'gwdetect'), "",
           $self->intfs->get(name => $interface, secondary => $id, key => 'allowaccess') ;

         }
      }
   }

# ---

sub display_vdom_routing {
   my $subn = "display_vdom_routing" ;

   my $self = shift ;

   my $vdom = shift ;

   my $rip  = "no" ;
   my $ospf = "no" ;
   my $isis = "no" ;
   my $bgp  = "no" ;
   my $pim  = "no" ;

   warn "\n* Entering $obj:$subn vdom=$vdom" if $self->debug() ;

   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;
   printf
"|  id  | subnets            | device        | gateway               |  dist  | prio | weig |    id_route=%-3s   p_route=%-3s   rip=%-3s   ospf=%-3s   isis=%-3s   bgp=%-3s   pim=%-3s|\n",
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.identity-based-route')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.policy-route')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.rip')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.ospf')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.isis')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.bgp')),
     $self->color($self->vd->hasMatched(vdom => $vdom, ruleId => 'feature.pim')) ;
   print
"|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n"
     ;

   #@keys = sort { $a <=> $b } (@keys) ;
   my @keys = $self->vd->sort_routes($vdom) ;

   foreach my $key (@keys) {
      printf
"| %4s | %18.18s | %13.13s | %21.21s | %6.6s | %4.4s | %4.4s |                                                                                  |\n",
        $key,
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'dst'),
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'device'),
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'gateway'),
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'distance'),
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'priority'),
        $self->vd->get(vdom => $vdom, key => 'static_route', subkey => $key, thirdkey => 'weight') ;
      }

   }

# ---

sub display_ipsec_interface {
   my $subn = "display_ipsec_interface" ;

   my $self      = shift ;
   my $vdom      = shift ;
   my $interface = shift ;

   warn "\n* Entering $obj:$subn vdom=$vdom interface=$interface" if $self->debug() ;

   # Phase 1
   printf
"|                 ............................................................................................................................................................|\n"
     ;
   printf
     "| %-13s   type:%-7s    rem-gw:%-15s mode:%-10s  loc-gw:%-15s     peer=%-15s            ph2: %-3s src: %-3s  dst: %-3s  routes: %-3s |\n",
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => '_DUP'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'type'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'remotegw'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'mode'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'localgw'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'peertype'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'countph2'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'countsrc'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'countdst'),
     $self->vd->get(vdom => $vdom, key => 'ipsec_phase1', subkey => $interface, thirdkey => 'countroutes') ;

   # phase 2
   foreach my $ph2 ($self->vd->get_ipsec_phase2s($vdom)) {
      if ($self->vd->get(vdom => $vdom, key => 'ipsec_phase2', subkey => $ph2, thirdkey => 'phase1name') eq $interface) {
         printf "|                 %-32s                   %-40s -> %-40s                     |\n",
           $ph2,
           $self->vd->get(vdom => $vdom, key => 'ipsec_phase2', subkey => $ph2, thirdkey => 'src'),
           $self->vd->get(vdom => $vdom, key => 'ipsec_phase2', subkey => $ph2, thirdkey => 'dst') ;
         }
      }

   print
"|.............................................................................................................................................................................|\n"
     ;
   }

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
