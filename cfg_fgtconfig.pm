# ****************************************************
# *                                                  *
# *               F G T C O N F I G                  *
# *                                                  *
# *  Parser object for fortigate config style        *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************

package cfg_fgtconfig ;
my $obj = "cfg_fgtconfig" ;

use FileHandle ;
use Moose ;
use Data::Dumper ;

# Uses generic dissector tools
use cfg_dissector ;
use cfg_interfaces ;
use cfg_global ;
use cfg_vdoms ;
use cfg_display ;
use cfg_statistics ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

# Definition of the colums details for both TP moode and NAT. Some are optional

my $COLOR = 0 ;

# Ansi foreground colors
my $color_red    = "\e[31m" ;
my $color_white  = "\e[37m" ;
my $color_green  = "\e[32m" ;
my $color_yellow = "\e[33m" ;

my $YES_S = "" ;
my $NO_S  = "" ;
my $END   = "" ;

my %hash_columns = (
   'nat',
   {
      '1',  {'label' => 'interface',    'key' => 'name',         'format' => "20", 'required' => '1'},
      '2',  {'label' => 'alias',        'key' => 'alias',        'format' => "20", 'required' => '0'},
      '3',  {'label' => 'zone',         'key' => 'zone',         'format' => "20", 'required' => '0'},
      '4',  {'label' => 'physical',     'key' => 'physical',     'format' => "20", 'required' => '0'},
      '5',  {'label' => 'mode',         'key' => 'mode',         'format' => "6",  'required' => '0'},
      '6',  {'label' => 'vlan',         'key' => 'vlan',         'format' => "4",  'required' => '0'},
      '7',  {'label' => 'ip',           'key' => 'ip',           'format' => "18", 'required' => '1'},
      '8',  {'label' => 'network',      'key' => 'network',      'format' => "15", 'required' => '1'},
      '9',  {'label' => 'broadcast',    'key' => 'broadcast',    'format' => "15", 'required' => '1'},
      '10', {'label' => 'status',       'key' => 'status',       'format' => "6",  'required' => '1'},
      '11', {'label' => 'mtu-override', 'key' => 'mtu-override', 'format' => "6",  'required' => '0'},
      '12', {'label' => 'PS',           'key' => 'pingserver',   'format' => "2",  'required' => '0'},
      '13', {'label' => 'mtu',          'key' => 'mtu',          'format' => "4",  'required' => '0'},
      '14', {'label' => 'speed',        'key' => 'speed',        'format' => "8",  'required' => '0'},
      '15', {'label' => 'admin',        'key' => 'admin',        'format' => "16", 'required' => '1'},
   },

   'tp',
   {
      '1', {'label' => 'interface', 'key' => 'name',           'format' => "20", 'required' => '1'},
      '2', {'label' => 'alias',     'key' => 'alias',          'format' => "20", 'required' => '0'},
      '3', {'label' => 'zone',      'key' => 'zone',           'format' => "20", 'required' => '0'},
      '4', {'label' => 'physical',  'key' => 'physical',       'format' => "20", 'required' => '0'},
      '5', {'label' => 'vlan',      'key' => 'vlan',           'format' => "4",  'required' => '0'},
      '6', {'label' => 'fwd',       'key' => 'forward-domain', 'format' => "5",  'required' => '0'},
      '7', {'label' => 'status',    'key' => 'status',         'format' => "6",  'required' => '1'},
      '8', {'label' => 'speed',     'key' => 'speed',          'format' => "8",  'required' => '0'},
      '9', {'label' => 'admin',     'key' => 'admin',          'format' => "16", 'required' => '1'},
   },
) ;

has 'splitconfigdir' => (
   isa     => 'Str',
   is      => 'rw',
   default => '.',
   trigger => \&_accessor_debug,
) ;

has 'color' => (
   isa     => 'Str',
   is      => 'rw',
   default => '0',
   trigger => \&_accessor_debug,
) ;

has 'configfile' => (
   isa       => 'Str',
   is        => 'rw',
   required  => 1,
   predicate => 'has_configfile',
   trigger   => \&_accessor_debug,
) ;

# debug level at object creation

has 'debug_level' => (
   isa      => 'Int',
   is       => 'rw',
   required => 0,
   default  => 0,
   trigger  => \&_accessor_debug,
) ;

has 'XMLTrsf' => (is => 'rw') ;

# cfg_dissector object
has 'cfg' => (is => 'rw') ;

# cfg_vdom object
has 'vd' => (is => 'rw') ;

# cfg_interface object
has 'intfs' => (is => 'rw') ;

# cfg_global object
has 'glo' => (is => 'rw') ;

# cfg_statistics object
has 'stat' => (is => 'rw') ;

# cfg_display object
has 'dis' => (is => 'rw') ;

# Ddebug flag for ourself

has 'debug' => (
   isa      => 'Int',
   is       => 'rw',
   required => 0,
   default  => 0,
   trigger  => \&_accessor_debug,
) ;

# ---

sub BUILD {
   my $subn = "BUILD" ;

   # initiate all objects with debugging

   my $self = shift ;

   warn "\n* Entering $obj:$subn debug_level=" . $self->debug_level() if $self->debug_level() ;

   # object debug masks
   # 2  : fgtconfig
   # 4  : cfg_dissector
   # 8  : cfg_interfaces
   # 16 : cfg_global
   # 32 : cfg_vdom
   # 64 : cfg_display
   # 128 : cfg_statistics

   # Set debug for outself if & 2
   $self->debug(1) if ($self->debug_level & 2) ;

   # building the config dissector object
   $self->cfg(cfg_dissector->new(configfile => $self->configfile(), debug => ($self->debug_level & 4))) ;

   # building the config interfaces object
   $self->intfs(cfg_interfaces->new(cfg => $self->cfg, debug => ($self->debug_level & 8))) ;

   # building the vdom object (will provide glo later)
   $self->vd(cfg_vdoms->new(cfg => $self->cfg, intfs => $self->intfs, debug => ($self->debug_level & 32))) ;
   $self->intfs->vd($self->vd) ;

   # since vd needs glo and glo needs vd we have to set the attributes after the new

   # building the global object (giving vd already created)
   $self->glo(cfg_global->new(cfg => $self->cfg, intfs => $self->intfs, vd => $self->vd, debug => ($self->debug_level & 16))) ;

   # give glo to vd
   $self->vd->glo($self->glo) ;

   # building the statistics object
   $self->stat(cfg_statistics->new(cfg => $self->cfg, vd => $self->vd, debug => ($self->debug_level & 128))) ;

   # give stat to vd so vd can update statistics as well
   $self->vd->stat($self->stat) ;

   # building the display object
   $self->dis(
      cfg_display->new(
         cfg            => $self->cfg,
         intfs          => $self->intfs,
         glo            => $self->glo,
         vd             => $self->vd,
         stat           => $self->stat,
         splitconfigdir => $self->splitconfigdir(),
         debug          => ($self->debug_level & 64)
      )
   ) ;

   # Initialise vdom_link_list
   $self->{_IVLINK} = () ;
   }

# ---

sub ruledebug {

   # Sets object with rule processing with a ruledebug information
   # to turn on debugging for a specific rule

   my $self = shift ;
   my $rule = undef ;

   if (@_) {
      $rule = shift ;
      $self->{_RULEDEBUG} = $rule ;
      $self->glo->ruledebug($rule) ;
      $self->vd->ruledebug($rule) ;
      }
   return $self->{_RULEDEBUG} ;
   }

# ---

sub parse {
   my $subn = "parse" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Load config and prepare data
   $self->cfg->configfile($self->configfile()) ;
   $self->cfg->load() ;
   $self->cfg->config_header() ;

   # Register all vdoms so we know them and their scopes for rule processsing
   $self->cfg->register_vdoms() ;

   # Get

   # Parse interfaces
   $self->intfs->parse_sp3_port() ;
   $self->intfs->process_interfaces() ;
   $self->intfs->parse_zones() ;
   }

# ---

sub summary {
   my $subn = "summary" ;

   # Dump configuration information such as registered vdoms and correspsonding scopes

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   printf "\tNumber of lines : %d\n", $self->cfg->max_lines ;

   printf "\tPlateform       : %s\n", $self->cfg->plateform ;
   printf "\tVersion         : %s\n", $self->cfg->version ;
   printf "\tType            : %s\n", $self->cfg->type ;
   printf "\tBuild           : %d\n", $self->cfg->build ;

   printf "\tvdom enable     : %d\n", $self->cfg->vdom_enable ;
   printf "\tNumber of vdoms : %d\n", $self->cfg->get_nb_vdoms ;
   printf "\tManagement vdom : %s\n", $self->cfg->get_mgmt_vdom ;

   printf "\tPorts           : " ;
   foreach my $int (@{$self->intfs->{_INTERFACE_LIST}}) {
      next if ($self->intfs->get(name => $int, key => 'type') ne 'physical') ;
      print $int. " " ;
      }
   print "\n" ;

   print "\nVDOMS:\n" ;
   foreach my $vdom ($self->cfg->get_vdom_list()) {
      printf "\tname:%-25s startindex:%d\tendindex:%d\n",
        $vdom,
        $self->cfg->vdom_index(vdom => $vdom, type => 'startindex', action => 'get'),
        $self->cfg->vdom_index(vdom => $vdom, type => 'endindex',   action => 'get') ;
      }

   print "\n" ;
   }

# ---

sub analyse {
   my $subn = "analyse" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # All global warnings and feature we can check generically
   # Use XML based global rule files for processing
   $self->glo->processRules() ;

   # Get other info that can't be set as a rule *config header extraction'
   $self->glo->global_info() ;

   # Warnings and features for all vdoms
   $self->vd->process_vdoms() ;
   $self->vd->system_vdom_limitations() ;

   # All features requiring a special traitment
   $self->glo->parse_resource_limits() ;
   $self->glo->parse_admin_users() ;
   $self->glo->parse_standalone_session_sync() ;
   $self->glo->parse_ha() ;

   # Raise warning flags for special traitement features
   $self->glo->raise_global_warnings() ;

   # $self->_parse_phase1_policy() ; # TO BE DONE

   # The following goes through each vdom, they should be grouped and call with vdom argument
   # instead of repeating vdom loop for each one.

   $self->vd->parse_phase1_ipsec_interface() ;
   $self->vd->parse_phase2_ipsec_interface() ;

   $self->vd->parse_routes() ;
   $self->vd->parse_policies() ;
   $self->vd->parse_interface_policies() ;
   $self->vd->parse_dos_policies() ;

   # Compute stats if needed
   if ($self->dis->stats_flag()) {
      warn "$obj:$subn Starting object statistics" if $self->debug() ;
      $self->stat->object_statistics() ;
      }

   }


# ---

sub pre_split_processing {
   my $subn = "pre_split_processing" ;

   my $self    = shift ;
   my %options = @_ ;
   my $nouuid  = $options{'nouuid'} ;

   warn "*Entering $obj:$subn with nouuid=$nouuid" if $self->debug() ;

   my @scope = (1, $self->cfg->max_lines) ;
   $self->cfg->delete_all_keys_from_block(aref_scope => \@scope, key => 'uuid') ;
   }

# ---

sub splitconfig {
   my $subn = "splitconfig" ;

   my $self   = shift ;
   my $config = shift ;

   my $fh_out      = new FileHandle ;
   my $splitconfig = "" ;

   warn "*Entering $obj:$subn with config=$config" if $self->debug() ;

   # Get splitconfig dir
   $splitconfig = $self->splitconfigdir() ;
   $splitconfig = "." if $splitconfig eq "-config" ;
   warn "$obj:$subn splitconfig: $splitconfig" if $self->debug() ;

   # Split all vdoms in files
   $self->vd->splitconfigdir($splitconfig) ;
   $self->vd->splitconfig_vdoms() ;

   # Generated _global.conf file if needed
   $self->glo->splitconfigdir($splitconfig) ;
   $self->glo->splitconfig_global($splitconfig) ;

   # Generate config summary file
   $self->dis->splitconfigdir($splitconfig) ;
   $self->dis->display('file') ;
   }

# ---
# Following methods are used to interact with fortigate configuration file
# They have been added for translate.pl conversion tool in Nov 2018
# ---

sub set_key {
   my $subn = "set_key" ;

   # Inserts or update the configuration key
   # The key is first search on the given scope, if found the key is replaced (no new line added)
   # If not found, a new line with the key is added in the configuration

   my $self            = shift ;
   my %options         = @_ ;
   my $aref_scope      = $options{'aref_scope'} ;
   my $key             = $options{'key'} ;
   my $value           = $options{'value'} ;
   my $index_increment = defined($options{'index_increment'}) ? $options{'index_increment'} : 1 ;    # increment of position to add from scope start
   my $nb_spaces       = defined($options{'nb_spaces'}) ? $options{'nb_spaces'} : 0 ;                # number of spaces before the "set"
   my $nested          = defined($options{'nested'}) ? $options{'nested'} : NOTNESTED ;              # use NESTED|NOTNESTED (declared as constant)

   warn "\n* Entering $obj:$subn with scope, key=$key, value=$value, index_increment=$index_increment, nb_spaces=$nb_spaces index_nested=$nested"
     if $self->debug ;

   # See if the key exists, if so, get its index (we don't provide any default value here
   my $return = $self->cfg->get_key($aref_scope, $key, $nested, '') ;
   my $found = $self->cfg->feedback('found') ;

   my $content = " " x $nb_spaces . "set $key $value\n" ;

   if ($found) {
      my $old_value = $self->cfg->feedback('value') ;
      my $index     = $self->cfg->feedback('index') ;
      warn "$obj:$subn key $key found => replacing existing value \"$old_value\" with \"$value\" at index=$index" if $self->debug ;
      $self->cfg->set_line(index => $index, content => $content) ;
      }

   else {
      # Get index where to add the statement, index is at scope start + index increment
      my $scope_start = $$aref_scope[0] ;
      my $index       = $scope_start + $index_increment ;
      warn "$obj:$subn key $key not found => adding a new key statement with value \"$value\" at index=$index" if $self->debug ;
      chomp($content) ;
      $self->cfg->insert(index => $index, content => $content) ;

      # Config has been touched, need to register vdoms again
      $self->cfg->register_vdoms() ;
      }
   }

# ---

sub unset_key {
   my $subn = "unset_key" ;

   # remove the line with the key if found in the given scope
   # if not found, no action is taken

   my $self       = shift ;
   my %options    = @_ ;
   my $aref_scope = $options{'aref_scope'} ;
   my $key        = $options{'key'} ;
   my $nested     = defined($options{'nested'}) ? $options{'nested'} : NOTNESTED ;

   warn "\n* Entering $obj:$subn with scope, key=$key, nested=$nested scope=[" . $$aref_scope[0] . "-" . $$aref_scope[1] . "]" if $self->debug ;

   # Sanity
   die "key is required" if (not(defined($key))) ;

   # See if the key exists, if so, get its index (we don't provide any default value here)

   my $return = $self->cfg->get_key($aref_scope, $key, $nested, '', 0) ;    # Don't want any value, only see existance of key
   my $found = $self->cfg->feedback('found') ;

   if ($found) {
      my $index = $self->cfg->feedback('index') ;
      warn "$obj:$subn key $key found => deleting (blanking) line at index=$index" if $self->debug ;
      $self->cfg->delete(index => $index) ;
      }

   else {
      warn "$obj:$subn key $key was not found, do nothing" if $self->debug ;
      }
   }

# ---

sub get {
   my $subn = "get" ;

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;

   warn "\n* Entering $obj:$subn with index=$index" if $self->debug ;

   return ($self->cfg->get_line(index => $index)) ;
   }

# ---
sub replace {
   my $subn = "replace" ;

   # Replaces a line in the configuration at a defined index

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;
   my $content = $options{'content'} ;

   warn "\n* Entering $obj:$subn with index=$index, content=$content" if $self->debug ;

   # Insert our line
   $self->cfg->set_line(index => $index, content => $content) ;
   }

# ---

sub insert {
   my $subn = "insert" ;

   # inserts a line in the configuration at a defined index

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;
   my $content = $options{'content'} ;

   warn "\n* Entering $obj:$subn with index=$index, content=$content" if $self->debug ;

   # Insert our line
   $self->cfg->insert(index => $index, content => $content) ;

   # Reregister our vdoms because of our change
   $self->cfg->register_vdoms() ;
   }

# ---

sub delete {
   my $subn = "delete" ;

   # Deletes line a defined index

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;

   warn "\n* Entering $obj:$subn with index=$index" if $self->debug ;

   # Delete our line
   $self->cfg->delete(index => $index) ;

   # Reregister our vdoms because of our change
   $self->cfg->register_vdoms() ;
   }

# ---

sub delete_block {
   my $subn = "delete_block" ;

   # Deletes and entire block of config delimimited by scopes
   my $self       = shift ;
   my %options    = @_ ;
   my $startindex = $options{'startindex'} ;
   my $endindex   = $options{'endindex'} ;

   warn "\n* Entering $obj:$subn with startindex=$startindex endindex=$endindex" if $self->debug ;
   $self->cfg->delete_block(startindex => $startindex, endindex => $endindex) ;
   $self->cfg->register_vdoms() ;
   }

# ---

sub get_key {
   my $subn = "get_key" ;

   # Wrapper to cfg_dissector get_key method
   # Used to retrieve a key value within a defined scope of search

   # Withing the define scope, retrieve the value after the statement
   # don't search the statement inside a nested config/end or edit/next
   # ex: get_key(\@scope,'hostname', NESTED|NOTNESTED, 'default_value') ;

   my $self       = shift ;
   my %options    = @_ ;
   my $aref_scope = $options{'aref_scope'} ;
   my $key        = $options{'key'} ;
   my $nested     = defined($options{'nested'}) ? $options{'nested'} : NOTNESTED ;
   my $default    = defined($options{'default'}) ? $options{'default'} : "" ;

   my $return = $self->cfg->get_key($aref_scope, $key, $nested, $default) ;
   }

# ---

sub delete_all_keys {
   my $subn = "delete_all_keys" ;

   my $self       = shift ;
   my %options    = @_ ;
   my $aref_scope = $options{'aref_scope'} ;
   my $key        = $options{'key'} ;
   my $nested     = defined($options{'nested'}) ? $options{'nested'} : NOTNESTED ;

   warn "\n* Entering $obj:$subn with key=$key nested=$nested scope=" . $$aref_scope[0] . "-" . $$aref_scope[1] if $self->debug ;

   $self->cfg->delete_all_keys_from_block(aref_scope => $aref_scope, key => $key) ;
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
   if ($self->cfg->scope_config(\@scope, 'config system ha', 0)) {
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

sub fullstats {
   my $subn = "fullstats" ;

   my $self = shift ;

   # Parsing configuration using cfg_dissector
   $self->parse() ;

   my @vdoms = $self->cfg->get_vdom_list();
   foreach my $vd (@vdoms) {
      warn "processing vd=$vd" if $self->debug;
      }

   # building a stat object from cfg_statistics
   # providing a dissector configuration
   $self->stat(cfg_statistics->new(cfg => $self->cfg, vd => $self->vd, debug => ($self->debug_level & 128))) ;

   # Run all statistics on the config defined in the cfg_statistics object
   $self->stat->object_statistics();

   # For testing purpose, dump the statistic object results for each vdom
   $self->stat->dump();
   }

# ---

sub test {
   my $subn = "test" ;

   # this method is used for testing purpose

   my $self    = shift ;
   my %options = @_ ;

   die "object name is required" if (not(defined($options{'object'}))) ;
   die "key is required"         if (not(defined($options{'key'}))) ;

   if ($options{'object'} eq 'glo') {
      return ($self->glo->get(%options)) ;
      }
   elsif ($options{'object'} eq 'vd') {
      return ($self->vd->get(%options)) ;
      }
   elsif ($options{'object'} eq 'intfs') {
      return ($self->intfs->get(%options)) ;
      }
   elsif ($options{'object'} eq 'stat') {
      return ($self->stat->get(%options)) ;
      }
   elsif ($options{'object'} eq 'cfg') {
      return ($self->cfg->get(%options)) ;
      }

   }

# --------------------------------------------------
#
# Internal functions not exposed outside this object
#
# ---------------------------------------------------

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

      warn "$obj:$subn name=$name status=$status alias=$alias vdom=$vdom vlanid=$vlanid ip=$ip allowaccess=$allowaccess description=$description" if $self->debug ;

      # Sanity
      die "name needed" if ($name eq "") ;

      # set scope index
      my @scope = () ;
      my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $name) ;

      if (not($found)) {
         warn "$obj:$subn could not find interface $name in configuration, create it at index=$scope[0]" if $self->debug ;
         $self->_interface_creation(interface => $name, index => $scope[0]) ;
         $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $name) ;
         }

      # Also force a status UP (or this could be useless unless said differently
      if ($status eq "down") {
         print "   o set interface $name status down\n" ;
         $self->set_key(aref_scope => \@scope, key => 'status', value => 'down', nb_spaces => 8) ;
         }

      else {
         print "   o set interface $name status up\n" ;
         $self->set_key(aref_scope => \@scope, key => 'status', value => 'up', nb_spaces => 8) ;
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
         $self->set_key(aref_scope => \@scope, key => 'ip', value => $ip, nb_spaces => 8) ;
         }

	  # vlanid
	  if ($vlanid ne "") {
		  warn "$obj:$subn name=name => set vlanid=$vlanid" if $self->debug ;
		  die "vlanid should be an integer, not ($vlanid)" if ($vlanid !~ /\d+/) ;
		  print "   o set interface $name vlanid $vlanid\n" ;
		  $self->set_key(aref_scope => \@scope, key => 'vlanid', value => $vlanid, nb_spaces => 8) ;
          }

      # Allowaccess
      if ($allowaccess ne "") {
         warn "$obj:$subn name=name => set allowaccess $allowaccess" if $self->debug ;
         print "   o set interface $name allowaccess\n" ;
         $self->set_key(aref_scope => \@scope, key => 'allowaccess', value => $allowaccess, nb_spaces => 8) ;
         }

      # Alias
      if ($alias ne "") {
         warn "$obj:$subn name=name => set alias $alias" if $self->debug ;
         print "   o set interface $name alias\n" ;
         $self->set_key(aref_scope => \@scope, key => 'alias', value => "\"" . $alias . "\"", nb_spaces => 8) ;
         }

      # Vdom
      if ($vdom ne "") {
         warn "$obj:$subn name=name => set vdom $vdom" if $self->debug ;
         print "   o set interface $name vdom\n" ;
         $self->set_key(aref_scope => \@scope, key => 'vdom', value => "\"" . $vdom . "\"", nb_spaces => 8) ;
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
   $self->insert(index => $index, content => "    next") ;
   $self->insert(index => $index, content => "        set type physical") ;
   $self->insert(index => $index, content => "        set status up") ;
   $self->insert(index => $index, content => "    edit \"$interface\"") ;

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
      $self->insert(index => $index, content => "    edit \"$vdlink\"") ;
      $index++ ;
      $self->insert(index => $index, content => "        set type $type") ;
      $index++ ;
      $self->insert(index => $index, content => "    next") ;
      $index++ ;
      }

   else {
      warn "$obj:$subn config system vdom-link does not exists" if $self->debug ;

      # Create a new config statement before config system interface
      $self->cfg->scope_config(\@scope, 'config system interface') ;
      my $index = ($self->cfg->feedback('startindex')) ;
      $self->insert(index => $index, content => "config system vdom-link") ;
      $index++ ;
      $self->insert(index => $index, content => "    edit \"$vdlink\"") ;
      $index++ ;
      $self->insert(index => $index, content => "        set type \"$type\"") ;
      $index++ ;
      $self->insert(index => $index, content => "    next") ;
      $index++ ;
      $self->insert(index => $index, content => "end") ;
      $index++ ;
      }
   }

# ---

sub _get_scope_edit_interface {
   my $subn = "_get_scope_edit_interface" ;

   # Position scope for config system interdace -> edit ><name>

   my $self       = shift ;
   my %options    = @_ ;
   my $interface  = $options{'interface'} ;
   my $aref_scope = $options{'aref_scope'} ;

   warn "\n* Entering $obj:$subn with scope and interface=$interface" if $self->debug ;

   $self->cfg->scope_config($aref_scope, 'config system interface') ;
   $self->cfg->scope_edit($aref_scope, "edit \"" . $interface . "\"") ;
   if ($self->cfg->feedback('found')) {
      warn "$obj:$subn found with scope : [" . $self->cfg->feedback('startindex') . ":" . $self->cfg->feedback('endindex') . "]" if $self->debug ;
      return 1 ;
      }

   return 0 ;
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
   my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      print "   o remove interface $interface speed\n" ;
      $self->unset_key(aref_scope => \@scope, key => $key) ;
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
   my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->set_key(aref_scope => \@scope, key => 'description', value => "\"" . $description . "\"", nb_spaces => 8) ;
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
   my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->set_key(aref_scope => \@scope, key => 'alias', value => "\"" . $alias . "\"", nb_spaces => 8) ;
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
   my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;
   if ($found) {
      $self->set_key(aref_scope => \@scope, key => 'type', value => $dst_type, nb_spaces => 8) ;
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
   my $found = $self->_get_scope_edit_interface(aref_scope => \@scope, interface => $interface) ;

   if ($found) {
      print "   o change interface $interface to status $status\n" ;
      $self->set_key(aref_scope => \@scope, key => 'status', value => $status, nb_spaces => 8) ;
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
               $self->delete_all_keys(aref_scope => \@scope, key => 'auto-asic-offload', nested => NOTNESTED) ;

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
               $self->set_key(aref_scope => \@edit_scope, key => 'psksecret', value=>$psksecret, nb_spaces=>8, nested => NOTNESTED) ;
              
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

sub _accessor_debug {

   my $self     = shift ;
   my $value    = shift ;
   my $href_att = shift ;

   #my $accessor = $$href_att{'accessor'} ;
   #my $isa      = $$href_att{'isa'} ;

   #if (defined($accessor)) {
   #if ($self->debug() or $accessor eq 'debug') {
   #   warn "* Accessor $accessor : set value=$value (type=$isa)" ;
   #   }
   #}

   # Parse all attributes
   #foreach my $item (keys %{$href_att}) {
   #   warn "key=".$item." value=".$$href_att{$item};
   #   }

   }

# ---

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;

