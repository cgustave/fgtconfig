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
   $self->cfg->get_key($aref_scope, $key, $nested, '') ;
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

