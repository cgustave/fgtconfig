# ****************************************************
# *                                                  *
# *        C F G   D I S S E C T O R                 *
# *                                                  *
# *  Dissector object for fortinet config style      *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#
# This object provides generic tools to dissect a 'Forticonfiguration' file

package cfg_dissector ;
my $obj = "cfg_dissector" ;

use Moose ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

has 'configfile' => (
   isa => 'Str',
   is  => 'rw',

   #   default   => 'fgt_system.conf',
   predicate => 'has_configfile',
   trigger   => \&_accessor_debug,
) ;

has 'version'     => (isa => 'Str', is => 'rw') ;
has 'build'       => (isa => 'Str', is => 'rw') ;
has 'plateform'   => (isa => 'Str', is => 'rw') ;
has 'type'        => (isa => 'Str', is => 'rw') ;
has 'fos_carrier' => (isa => 'Str', is => 'rw') ;
has 'build_tag'   => (isa => 'Str', is => 'rw', default => '') ;
has 'vdom_enable' => (isa => 'Int', is => 'rw', default => 0) ;

has 'debug' => (
   isa     => 'Int',
   is      => 'rw',
   default => 0,
   trigger => \&_accessor_debug,
) ;

# --- PRIVATE ATTRIBUTES ---

# $self->{_CONFIG}              = () ;          # Array of config lines starting a 1 to match config line
# $self->{_CONFIG_LINES}        = 0 ;           # nb of lines in the config
# $self->{_FEEDBACK}            = {} ;          # Href for feedback on search

sub BUILD {
   my $subn = "BUILD" ;

   my $self = shift ;
   warn "\n* Entering $obj:$subn with debug=" . $self->debug if $self->debug ;

   $self->{_FEEDBACK} = {} ;
   $self->{VDOM_LIST} = () ;    # array of list of vdom
   $self->{VDOM}      = {} ;    # Only to store startindex and endindex
   $self->{_CACHE_MGMT_VDOM} ;
   }

# ---

sub load {
   my $subn = "load" ;

   # Load file in memory
   # Index starts at 1 instead of 0 so it matches the line number displayed in text editor when editing the config

   my $self = shift ;

   $self->{_CONFIG} = () ;
   my $index = 1 ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   open(CONFIG, '<', $self->configfile()) or die "Cannot open config file " . $self->configfile() . " for reading (-config )" ;

   while (<CONFIG>) {
      s/\r\n/\n/ ;    # standardize DOS format to normal format...
      $self->{_CONFIG}[$index] = $_ ;
      $index++ ;
      }
   close(CONFIG) ;

   $self->{_CONFIG_LINES} = $index - 1 ;

   warn "$obj:$subn Loaded $index lines" if $self->debug() ;
   }

# ---

sub config_header {
   my $subn = "config_header" ;

   my $self = shift ;

   my ($plateform, $version, $type, $build) = undef ;

   warn "Entering $obj:$subn" if $self->debug() ;

   # Inspect first header line
   # ex: #config-version=FG3K8A-4.00-FW-build099-090407:opmode=0:vdom=1:user=admin
   # ex  #config-version=FG3K9B-5.00-FW-build292-140801:opmode=0:vdom=1:user=fwmd_fortigate
   # ex: #config-version=FGT3KB-4.00-FW-build513-120130:opmode=0:vdom=1:user=admin
   # ex: #config-version=FG1K2D-5.04-FW-build1011-151221:opmode=0:vdom=0:user=cgustave
   # ex: #config-version=FGT1KD-5.6.2-FW-build1486-170816:opmode=0:vdom=1:user=ravindrab
   # ex: #config-version=FGVMK6-6.0.0-FW-build0009-171026:opmode=0:vdom=0:user=admin
   # do not start RE with ^ as it seems some invisible control chars may sneak in at beginning of the line

   ($plateform, $version, $type, $build) = $self->line(1) =~ /
        (?:\#config-version=)
        (\S{6})
        (?:-)
        (\d\.\d{1,2}\.?\d{1,2}?)
        (?:\-)(FW|FOC)(?:-build)(\w{3,4})(?:-)
        /x ;

   if (defined($plateform)) {
      warn "$obj:$subn plateform=$plateform version=$version type=$type build=$build" if $self->debug() ;
      $self->plateform($plateform) ;
      $self->version($version) ;
      $self->type($type) ;
      $self->build($build) ;
      }
   else {
      warn "$subn: Is first config line ok ? can't recognise the plateform: line=" . $self->line(1) ;
      }

   # FortiOS Carrier has a typical 2md line header:
   #config-version=FG5A01-3.00-FW-build730-090317:opmode=0:vdom=1:user=admin
   #version=FortiOS-Carrier-5001A 3.00,build8102,090317
   #conf_file_ver=15993214564799777768
   #buildno=8102

   if ($self->line(2) =~ /(#version=FortiOS-Carrier-)|(#version=FortiCarrier)/) {
      warn "$obj:$subn FortiOS Carrier" if $self->debug() ;
      $self->fos_carrier("CARRIER") ;
      }
   else { $self->fos_carrier("")  }

   }

# ---

sub config_version {
   my $subn = "config_version" ;

   # Return the major and minor version (3.0, 4.1, 4.2, 4.3, 5.0, 5.2)
   # from version and build number
   # returns "" for special image (high build number)

   my $self = shift ;

   my $return = "" ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Use cache if possible
   return ($self->{_CFG}->{_CACHE_BASE_BRANCH})
     if (defined($self->{_CFG}->{_CACHE_BASE_BRANCH})) ;

   # sanity
   die "undefined version" if (not(defined($self->version()))) ;
   die "undefined build"   if (not(defined($self->build()))) ;

   my ($version, $build) = undef ;
   $version = $self->version() ;
   $build   = $self->build() ;

   warn "$obj:$subn version=$version build=$build" if $self->debug ;

   if ($version eq "3.00") {
      $return = "3.0" ;
      $return = "3.1" if ($build >= 247) ;
      $return = "3.2" if ($build >= 318) ;
      $return = "3.3" if ($build >= 400) ;
      $return = "3.5" if ($build >= 405) ;
      $return = "3.6" if ($build >= 406) ;
      $return = "3.7" if ($build >= 410) ;
      $return = "3.8" if ($build >= 411) ;
      $return = "3.9" if ($build >= 413) ;
      $return = "3.10" if ($build >= 415) ;
      $return = "3.13" if ($build >= 417) ;
      $return = "3.14" if ($build >= 418) ;
      }

   elsif ($version eq "4.00") {
      $return = "4.0" ;
      $return = "4.1" if ($build >= 178) ;
      $return = "4.2" if ($build >= 272) ;
      $return = "4.3" if ($build >= 441) ;
      }

   elsif ($version eq "5.00") {
      $return = "5.0" ;
      }

   elsif (($version eq "5.02") or ($version eq "5.2")) {
      $return = "5.2" ;
      }

   elsif (($version eq "5.04") or ($version eq "5.4")) {
      $return = "5.4" ;
      }

   # Now, there is no need to guess based on build

   else {
      $return = $version ;
      }

   # fill cache
   $self->{_CFG}->{_CACHE_BASE_BRANCH} = $return ;
   return $return ;
   }

# ---

sub line {
   my $subn = "line" ;

   # Returns config line from the line index provided (starting from 1)

   my $self = shift ;
   my $line = shift ;

   warn "\n* Entering $obj:$subn with line=$line" if $self->debug() ;

   # Sanity
   die "line index required" if (not(defined($line))) ;

   return ($self->{_CONFIG}[$line]) ;
   }

# ---

sub get_line {
   my $subn = "get_line" ;

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;

   warn "\n* Entering $obj:$subn with index=$index" if $self->debug() ;

   # sanity
   die "index is required" if (not(defined($index))) ;
   die "index should be numeric" if ($index !~ /\d+/) ;

   return ($self->{_CONFIG}[$index]) ;
   }

# ---

sub set_line {
   my $subn = "set_line" ;

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;
   my $content = $options{'content'} ;

   warn "\n* Entering $obj:$subn with index=$index content=$content" if $self->debug() ;

   # sanity
   die "index is required" if (not(defined($index))) ;
   die "index should be numeric" if ($index !~ /\d+/) ;
   $self->{_CONFIG}[$index] = $content ;
   }

# ---

sub max_lines {
   my $subn = "max_lines" ;

   my $self = shift ;
   warn "\n* Entering $obj:$subn max_line=" . $self->{_CONFIG_LINES} if $self->debug() ;

   return ($self->{_CONFIG_LINES}) ;
   }

# ---


# ---

sub insert {
   my $subn = "insert" ;

   # Inserts a line "content" at provided index
   # config grows by one line and shift to the bottom

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;
   my $content = $options{'content'} ;
   $content = "" if (not(defined($content))) ;

   warn "\n* Entering $obj:$subn with index=$index and content=$content" if $self->debug ;

   # sanity
   die "index is required" if (not(defined($index))) ;
   die "index should be an integer" if (not($index =~ /\d+/)) ;

   # shift config from bottom up until our index
   for (my $i = $self->{_CONFIG_LINES} ; $i >= $index ; $i--) {
      warn "$obj:$subn shift line ($i+1) to line $i" if $self->debug ;
      $self->{_CONFIG}[$i + 1] = $self->{_CONFIG}[$i] ;
      }

   # put content line with new line
   warn "$obj:$subn put content=$content at line $index" if $self->debug ;
   $self->{_CONFIG}[$index] = $content . "\n" ;

   # Increase config lines
   $self->{_CONFIG_LINES}++ ;
   }

# ---

sub delete {
   my $subn = "delete" ;

   # Deletes line at provided index
   # config shriks by one line and shift up

   my $self    = shift ;
   my %options = @_ ;
   my $index   = $options{'index'} ;
   my $action  = $options{'action'} ;

   $action = "blank" if (not(defined($action)) or ($action eq "")) ;

   warn "\n* Entering $obj:$subn with index=$index action=$action" if $self->debug ;

   # sanity
   die "index is required" if (not(defined($index))) ;
   die "index should be an integer" if (not($index =~ /\d+/)) ;

   if ($action eq "shrink") {

      # Shrink config
      for (my $i = $index ; $i < $self->{_CONFIG_LINES} ; $i++) {
         warn "$obj:$subn shift line ($i+1) to line $i" if $self->debug ;
         $self->{_CONFIG}[$i] = $self->{_CONFIG}[$i + 1] ;
         }

      # Erase previous last line
      $self->{_CONFIG}[$self->{_CONFIG_LINES}] = "" ;

      # Decrease config lines
      $self->{_CONFIG_LINES}-- ;
      }

   elsif ($action eq "blank") {
      $self->{_CONFIG}[$index] = "\n" ;
      }
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

   # Sanity
   die "startindex is required" if (not(defined($startindex)) or ($startindex eq "")) ;
   die "endindex is required"   if (not(defined($endindex))   or ($endindex eq "")) ;
   die "startindex should be numeric" if ($startindex !~ /\d+/) ;
   die "endindex should be numeric"   if ($endindex !~ /\d+/) ;

   # Copy config just after the block at our startindex
   my $diff = $endindex - $startindex ;
   for (my $i = $startindex ; $i <= $self->max_lines - $diff ; $i++) {
      $self->{_CONFIG}[$i] = $self->{_CONFIG}[$i + $diff + 1] ;
      }

   # Wipe config bottom
   for (my $i = $self->max_lines - $diff ; $i < $self->max_lines ; $i++) {
      $self->{_CONFIG}[$i] = "" ;
      }

   # Reduce max_line
   $self->{_CONFIG_LINES} = $self->{_CONFIG_LINES} - $diff - 1 ;
   }

# ---

sub delete_all_keys_from_block {
   my $subn = "delete_all_keys_from_block" ;

   # Blank any lines from the block that need to be deleted
   # Do not delete the lines as this would shift all vdoms index
   # deletion of empty lines may be done at a later stage

   my $self       = shift ;
   my %options    = @_ ;
   my $key        = $options{'key'} ;
   my $aref_scope = $options{'aref_scope'} ;

   warn "\n* Entering $obj:$subn with key=$key scope start=" . $$aref_scope[0] . " end=" . $$aref_scope[1] if $self->debug ;

   # Sanity
   die "key is required"        if (not(defined($key))) ;
   die "aref_scope is required" if (not(defined($aref_scope))) ;

   # Mark likes for deletion
   my @delete = () ;
   for (my $i = $$aref_scope[0] ; $i <= $$aref_scope[1] ; $i++) {
      if ($self->{_CONFIG}[$i] =~ /^(?:\s|\t)*(?:set\s)$key(?:\s|\t)/) {
         warn "$obj:$subn delete index=$i line=" . ($self->{_CONFIG}[$i]) if $self->debug ;
         $self->{_CONFIG}[$i] = "\n" ;
         }
      }
   }

# ---

sub get_end_global_index {

   # needed for splitconfig in cfg_global

   my $self = shift ;

   return ($self->{_endglobalindex}) ;
   }

# ---

sub register_vdoms {
   my $subn = "register_vdoms" ;

   # Registers all vdom
   # we only register a vdom when entering the vdom for config so we ignore the first 'config vdom'
   # in the config which are immediately followed-up with an 'end' (or a next since 5.0.4)

   my $self = shift ;

   my $vdom          = undef ;
   my $previous_vdom = undef ;
   my $flag          = 0 ;
   my $index         = 0 ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # Clear out list so we can be called multiple times
   $self->{VDOM_LIST} = () ;
   $self->{VDOM}      = {} ;

   # Parses all config and registers vdom, marking the index start and end

   foreach my $line (@{$self->{_CONFIG}}) {

      if ($flag == 1) {    # flag==1 means line is "config vdom"
                           # Get vdom name
         ($vdom) = $line =~ /edit\s((\w|-)*)/ ;
         if (defined($vdom)) {
            $flag = 2 ;    # got vdom name
            }
         else { die "config error"  }
         }

      elsif ($flag == 2) {
         if (not($line =~ /^(end|next)/)) {    # Avoid the first vdom definition that need to be ignored

            $self->vdom_index(vdom => $vdom, action => 'set', type => 'startindex', value => $index) ;

            # This is needed for splitconfig
            if (not(defined($self->{_endglobalindex}))) {
               $self->{_endglobalindex} = $index ;
               }

            # register vdom
            push @{$self->{VDOM_LIST}}, $vdom ;
            warn "$obj:$subn registering vdom $vdom starting line $index" if $self->debug() ;

            # Terminates previous vdom if there was one (4 lines before)
            if (defined($previous_vdom)) {
               my $previous_vdom_end_index = ($index - 4) ;
               $self->vdom_index(vdom => $previous_vdom, type => 'endindex', action => 'set', value => $previous_vdom_end_index) ;
               warn "$obj:$subn updating vdom $previous_vdom ending line $previous_vdom_end_index" if $self->debug() ;
               }
            $previous_vdom = $vdom ;
            }
         $flag = 0 ;
         }

      # reset flags
      if ($flag == 1) { $flag = 0  }

      # Set flag = 1 when reaching config vdom
      if (defined($line)) {
         if ($line =~ /config vdom/) {
            warn "$subn : found config vdom" if $self->debug() ;
            $flag = 1 ;
            }
         }
      $index++ ;
      }

   # Case where there is no vdoms (only the default root vdom)
   if (not(defined($vdom))) {
      warn "$obj:$subn no vdoms" if $self->debug() ;
      $vdom = 'root' ;
      $self->vdom_index(vdom => $vdom, type => 'startindex', action => 'set', value => '4') ;

      $self->vdom_enable(0) ;
      push @{$self->{VDOM_LIST}}, 'root' ;
      }

   else {
      $self->vdom_enable(1) ;
      }

   # Terminates the last vdom (need to remove 1 line_
   $self->vdom_index(vdom => $vdom, type => 'endindex', action => 'set', value => ($index - 1)) ;
   }

# ---

sub vdom_index {
   my $subn = "vdom_index" ;

   # Set or get startindex and endindex

   my $self    = shift ;
   my %options = @_ ;
   my $vdom    = $options{'vdom'} ;
   my $type    = $options{'type'} ;
   my $action  = $options{'action'} ;
   my $value   = $options{'value'} ;

   warn "$obj:$subn with vdom=$vdom type=$type action=$action value=$value" if $self->debug ;

   # Sanity
   die "vdom is required" if (not(defined($vdom))) ;

   die "type is required"                     if (not(defined($type))) ;
   die "type can only be startindex|endindex" if ($type !~ /startindex|endindex/) ;
   die "action is required"                   if (not(defined($action))) ;
   die "action can only be get|set"           if ($action !~ /get|set/) ;
   die "set value cannot be undef"            if (($action eq 'set') and not(defined($value))) ;

   if (defined($value) and ($action eq "set")) {
      $self->{VDOM}->{$vdom}->{$type} = $value ;
      }
   if (not(defined($value)) and ($action eq "get")) {
      return $self->{VDOM}->{$vdom}->{$type} ;
      }
   }

# ---

sub get_nb_vdoms {
   my $subn = "get_nb_vdoms" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   return (scalar @{$self->{VDOM_LIST}}) ;
   }

# ---

sub get_vdom_list {
   my $subn = "get_vdom_list" ;

   # returns the vdom list sorted alphabetically with management vdom on top

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   my @sortedList = () ;

   # Get and push management vdom first
   my $mgmt = $self->get_mgmt_vdom() ;

   # build a list of vdoms without the management vdom
   my @listNoMgmt = () ;
   foreach my $element (@{$self->{VDOM_LIST}}) {
      if ($element ne $mgmt) {
         push @listNoMgmt, $element ;
         }
      }

   # sort our list and add management vdom at the begining
   @sortedList = sort { $a cmp $b } (@listNoMgmt) ;
   unshift @sortedList, $mgmt ;

   return @sortedList ;
   }

# --
sub get_vdom_opmode {
   my $subn = "get_vdom_opmode" ;

   my $self = shift ;
   my $vdom = shift ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug ;

   # sanity
   die "register_vdom first" if (not($self->{VDOM}) or not($self->{VDOM_LIST})) ;

   if ($self->{VDOM}->{$vdom}->{'opmode'}) {
      warn "$obj:$subn from cache vdom=$vdom opmode=" . $self->{VDOM}->{$vdom}->{'opmode'} if $self->debug ;
      return ($self->{VDOM}->{$vdom}->{'opmode'}) ;
      }

   else {
      my @scope = $self->scope_vdom($vdom) ;
      if ($self->scope_config(\@scope, 'config system settings')) {
         my $opmode = $self->get_key(\@scope, 'opmode', NOTNESTED, 'nat') ;
         warn "$obj:$subn vdom=$vdom opmode=$opmode" if $self->debug ;

         # put in cache
         $self->{VDOM}->{$vdom}->{'opmode'} = $opmode ;
         return ($opmode) ;
         }

      else {
         warn "$obj:$subn could not find config system settings to get vdom opmode for vdom $vdom, assuming nat-route" if $self->debug;
	 return ('nat');
         }
      }
   }

# ---

sub get_mgmt_vdom {
   my $subn = "get_mgmt_vdom" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   if (not($self->{_CACHE_MGMT_VDOM})) {

      # Init scop
      my @scope = (1, $self->max_lines) ;
      $self->scope_config(\@scope, 'config system global') ;
      if ($self->feedback('found')) {
         my $mgmt_vdom = $self->get_key(\@scope, 'management-vdom', NOTNESTED, "root") ;
         warn "$obj:$subn management vdom=$mgmt_vdom" if $self->debug ;
         $self->{_CACHE_MGMT_VDOM} = $mgmt_vdom ;
         return ($mgmt_vdom) ;
         }
      else {
         warn "$obj:$subn default management vdom=root" if $self->debug ;
         $self->{_CACHE_MGMT_VDOM} = 'root' ;
         return ('root') ;
         }
      }
   else {
      warn "$obj:$subn from cache=" . $self->{_CACHE_MGMT_VDOM} if $self->debug ;
      return ($self->{_CACHE_MGMT_VDOM}) ;
      }
   }

# ---

sub print_config {

   # For debugging purpose

   my $self  = shift ;
   my $start = shift ;
   my $stop  = shift ;

   $stop = $self->max_lines if (not(defined($stop))) ;
   print "\nConfig Extract from start=$start and stop=$stop\n" ;

   for (my $i = $start ; $i <= $stop ; $i++) {
      print "[ $i ]: " . $self->line($i) ;
      }
   }

# ---

sub scope_vdom {
   my $subn = "scope_vdom" ;

   # Returns the scope for a vdom
   # Requires first register_vdoms

   my $self   = shift ;
   my $vdom   = shift ;
   my @return = () ;

   warn "\n* Entering $obj:$subn with vdom=$vdom" if $self->debug() ;

   my $value = $self->vdom_index(type => 'startindex', vdom => $vdom, action => 'get') ;
   warn "$obj:$subn start=$value" if $self->debug() ;
   push(@return, $value) ;
   $value = $self->vdom_index(type => 'endindex', vdom => $vdom, action => 'get') ;
   warn "$obj:$subn stop=$value" if $self->debug() ;
   push(@return, $value) ;

   return (@return) ;
   }

# ---

sub scope_config {
   my $subn = "scope_config" ;

   # Withing a start/end index (like the vdom), specify a config statement
   # arguments :
   # ref of scope (array of 2 values startindex, stopindex)

   #  returns 1 if found else 0

   my $self             = shift ;
   my $aref_scope       = shift ;
   my $config_statement = shift ;
   my $partial_flag     = shift || 0 ;

   warn "\n* Entering $obj:$subn with scope=("
     . $$aref_scope[0] . ","
     . $$aref_scope[1]
     . ") statement ->$config_statement<- partial_flag=$partial_flag "
     if $self->debug() ;

   # clear feedback
   $self->{_FEEDBACK} = {} ;
   $self->{_FEEDBACK}->{'found'} = 0 ;

   # remove the result line if still here

   my @return = $self->_config_seek($$aref_scope[0], $$aref_scope[1], $config_statement, 'end', 'config', $partial_flag) ;
   $$aref_scope[0] = $return[1] ;
   $$aref_scope[1] = $return[2] ;

   # Report feedback
   $self->{_FEEDBACK}->{'found'}      = $return[0] ;
   $self->{_FEEDBACK}->{'startindex'} = $return[1] ;
   $self->{_FEEDBACK}->{'endindex'}   = $return[2] ;

   return $return[0] ;
   }

# ---

sub scope_edit {
   my $subn = "_scope_edit" ;

   # Withing a start/end index (like the vdom), specify a config statement

   my $self           = shift ;
   my $aref_scope     = shift ;
   my $edit_statement = shift ;
   my $ref_key        = shift ;

   my $partial_flag = undef ;

   if (defined($ref_key)) {
      $partial_flag = 1 ;
      }
   else {
      $partial_flag = 0 ;
      }

   warn "\n* Entering $obj:$subn with scope=("
     . $$aref_scope[0] . ","
     . $$aref_scope[1]
     . ")  statement ->$edit_statement<- partial_flag=$partial_flag"
     if $self->debug() ;

   # clear feedback
   $self->{_FEEDBACK} = {} ;
   $self->{_FEEDBACK}->{'found'} = 0 ;

   my @return = $self->_config_seek($$aref_scope[0], $$aref_scope[1], $edit_statement, 'next', 'edit', $partial_flag) ;

   $$aref_scope[0] = $return[1] ;
   $$aref_scope[1] = $return[2] ;

   if (defined($ref_key)) {
      $$ref_key = $return[3] ;
      }

   # Report feedback
   $self->{_FEEDBACK}->{'found'}      = $return[0] ;
   $self->{_FEEDBACK}->{'startindex'} = $return[1] ;
   $self->{_FEEDBACK}->{'endindex'}   = $return[2] ;

   return $return[0] ;
   }

# ---

sub get_key {
   my $subn = "get_key" ;

   # Withing the define scope, retrieve the value after the statement
   # don't search the statement inside a nested config/end or edit/next
   # ex: get_key(\@scope,'hostname', NESTED|NOTNESTED, 'default_value') ;

   my $self       = shift ;
   my $aref_scope = shift ;
   my $key        = shift ;
   my $nested     = shift ;    # use NESTED|NOTNESTED (decalred as constant)
   my $default    = shift ;    # default value to return if get is not found
   my $get_value  = shift ;

   $get_value = 1 if (not(defined($get_value))) ;

   my $flag_found   = 0 ;
   my $nested_count = 0 ;
   my ($nested_key, $line, $return, $value) = undef ;

   # Initialise
   $$aref_scope[0] = 1       if (not(defined($$aref_scope[0]))) ;
   $$aref_scope[1] = 1000000 if (not(defined($$aref_scope[1]))) ;
   $nested         = 0       if (not(defined($nested))) ;

   $self->{_FEEDBACK} = {} ;
   $self->{_FEEDBACK}->{'found'} = 0 ;

   warn "\n* Entering $obj:$subn with scope=(" . $$aref_scope[0] . "," . $$aref_scope[1] . ") key=$key nested=$nested get_value=$get_value"
     if $self->debug() ;

   my $index = $$aref_scope[0] ;
   $index++ ;    # to avoid the initial config/edit is counted as a nested block

   while (
          ($index <= $self->{_CONFIG_LINES})
      and ($index <= $$aref_scope[1])    # Stricly to avoid the last end/next is counted as a nested block
      and (not($flag_found))
     )
   {
      $line = $self->{_CONFIG}[$index] ;

      if (not(defined($line))) {
         $index++ ;
         next ;
         }

      # Detect start of netsted config/end or edit/next
      if (($nested_key) = $line =~ /^(?:\s|\t)*(config|edit)/) {
         warn "$obj:$subn found start of nested block $nested_key line=$index" if $self->debug() ;
         $nested_key++ ;
         }

      # Detect end of nested config/end or edit/next
      if (($nested_key) = $line =~ /^(?:\s|\t)*(end|next)$/) {
         warn "$obj:$subn found end of nested block $nested_key line=$index" if $self->debug() ;
         $nested_key-- ;
         }

      # Did we found the statement  ?
      if (  (($nested_count == 0) and (not($nested)))
         or ($nested))
      {

         if ($get_value) {

            # Trying to extract values (no list with brackets possible here)
            if (($value) = $line =~ /^(?:\s|\t)*(?:set\s)$key(?:\s|\t)(?:")?((.)*)(?:")?(?:(\s|\t)*)(?:\n)?$/) {
               if (defined($value)) { $value =~ s/(\s|\t|\")*$//  }    # remove trailing spaces
               warn "$obj:$subn found key at line=$index config line:->$line<- value=$value" if $self->debug() ;
               $flag_found                   = 1 ;
               $self->{_FEEDBACK}->{'found'} = $flag_found ;
               $self->{_FEEDBACK}->{'index'} = $index ;
               $self->{_FEEDBACK}->{'key'}   = $key ;
               $self->{_FEEDBACK}->{'value'} = $value ;
               return ($value) ;
               }
            }

         else {
            warn "no value key=$key line=$line" if $self->debug ;

            # Don't extract value, only need the index
            if ($line =~ /^(?:\s|\t)*(?:set\s)$key(?:\s|\t)/) {
               warn "$obj:$subn found key at line=$index config line:->$line<- (novalue)" if $self->debug() ;
               $flag_found                   = 1 ;
               $self->{_FEEDBACK}->{'found'} = $flag_found ;
               $self->{_FEEDBACK}->{'index'} = $index ;
               return () ;
               }
            }

         }
      $index++ ;
      }

   # Use default if needed
   if (defined($default) and (not($flag_found))) {
      warn "$obj:$subn using provided default value default=$default for key=$key" if $self->debug() ;
      $value = $default ;
      }

   warn "$obj:$subn returning value=$value for key=$key" if $self->debug() ;
   return ($value) ;
   }

# ---

sub scope_config_and_multiget {
   my $subn = "scope_config_and_multiget" ;

   # Enters a config block and get multiple values from it
   # Returns 1 if config block exists, 0 if not
   # 1st argument : scope array reference
   # 2nd argument : config statement (ex :config system settings
   # 3rd argument : reference of a hash where the key is the key to retrieve and the value the default value
   #                values of the hash is updated with the values retrieved from the config
   # 4th argument : hashref to use to build a hash table with all the config keys ex: FAZ would build  $self->{_FAZ}->{<key>} = <value>
   #                if not defined, no hash is build

   my $self        = shift ;
   my $aref_scope  = shift ;
   my $config      = shift ;
   my $hrefkeys    = shift ;
   my $key_hashref = shift ;

   my @scope  = (undef, undef) ;
   my $return = 0 ;
   my $value  = undef ;

   warn "\n* Entering $obj:$subn with scope=(" . $$aref_scope[0] . "," . $$aref_scope[1] . ") config=$config key_hashref=$key_hashref"
     if $self->debug() ;

   $return = $self->scope_config(\@scope, $config) ;

   my @hash = keys %{$hrefkeys} ;

   foreach my $key (@hash) {
      warn "$obj:$subn comes with key=$key default_value=" . $$hrefkeys{$key} if $self->debug() ;
      if ($return) {
         $value = $self->get_key(\@scope, $key, NOTNESTED, $$hrefkeys{$key}) ;
         }
      else {
         warn "$obj:$subn could not find the config statement so use default values" if $self->debug() ;
         $value = $$hrefkeys{$key} ;
         }

      $$hrefkeys{$key} = $value ;

      warn "$obj:$subn out with key=$key value=" . $$hrefkeys{$key} if $self->debug() ;

      # Create a hash with the hash key
      $$key_hashref->{$key} = $$hrefkeys{$key} ;
      }

   return ($return) ;
   }

# ---

sub feedback {
   my $subn = "feedback" ;

   # Returns some feedback on the last search done

   my $self = shift ;
   my $key  = shift ;

   warn "\n* Entering $obj:$subn with key=$key" if $self->debug ;

   # Sanity
   die "key is required" if (not(defined($key))) ;
   die "key can only be found, index, key, value, startindex, endindex" if ($key !~ /found|index|key|value|startindex|endindex/) ;

   return $self->{_FEEDBACK}->{$key} ;
   }

# ---

sub print_feedback {

   # For debugging purpose

   my $self = shift ;

   print "print_feedback: " ;
   print " found :" . $self->feedback('found') ;
   print " index :" . $self->feedback('index')           if (defined($self->feedback('index'))) ;
   print " value :" . $self->feedback('value')           if (defined($self->feedback('value'))) ;
   print " startindex :" . $self->feedback('startindex') if (defined($self->feedback('startindex'))) ;
   print " endindex :" . $self->feedback('endindex')     if (defined($self->feedback('endindex'))) ;
   print "\n" ;
   }

# ---

sub save_config {
   my $subn = "save_config" ;

   # Save configuration from memory to file

   my $self     = shift ;
   my %options  = @_ ;
   my $filename = $options{'filename'} ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "filename is required" if (not(defined($filename)) or ($filename eq "")) ;

   open(fh_out, '>', $filename) or die "Cannot open file $filename for writing" ;

   for (my $i = 1 ; $i <= $self->max_lines ; $i++) {

      # Make sure we don't copy an empty line
      if ($self->line($i) =~ /^\n/) {
         warn "$obj:$subn empty line at index=" . $i if $self->debug ;
         }
      else {
         print fh_out $self->line($i) ;
         }
      }

   close fh_out ;
   }

# ---

sub _config_seek {
   my $subn = "_config_seek" ;

   # Generic seak for config/end and edit/next
   # inputs:
   #   - start index
   #   - end index
   #   - starting bareword
   #   - ending   bareword
   #   - key : 'edit' or 'config' to count nested element
   #   - partial_flag : 1 or undef : 1 if the statement can only match the beginning of a line
   #
   # returns an array of 3 values :
   #  - first  value : 1 for success (statement found), 0 for failure
   #  - second value : start index of the config_statement provided  "config xxxx"
   #  - third  value : end   index of the end statement corresponding to the config statement
   #  - fourth value : in case partial_flag is set, retrieves the key in edit <key>

   my $self               = shift ;
   my $startindex         = shift ;
   my $endindex           = shift ;
   my $starting_statement = shift ;
   my $ending_statement   = shift ;
   my $key                = shift ;
   my $partial_flag       = shift ;

   my $flag_found    = 0 ;
   my $exit_loop     = 0 ;
   my $line          = undef ;
   my @return        = () ;
   my $nested_config = 0 ;
   my $regexp        = undef ;

   $startindex   = 1       if (not(defined($startindex))) ;
   $endindex     = 1000000 if (not(defined($endindex))) ;
   $partial_flag = 0       if (not(defined($partial_flag))) ;

   die "wrong key" if (not($key =~ /config|edit/)) ;

   my $start_return = $startindex ;
   my $end_return   = $endindex ;

   warn
"\n* Entering $obj:$subn with startindex=$startindex endindex=$endindex starting_statement:->$starting_statement<- ending_statement:->$ending_statement<- key=$key partial_flag=$partial_flag"
     if $self->debug() ;

   my $index = $startindex ;

   while (($index <= $self->{_CONFIG_LINES})
      and ($index <= $endindex)
      and (not($exit_loop)))
   {

      $line = $self->{_CONFIG}[$index] ;

      if (not(defined($line))) {
         $index++ ;
         next ;
         }

      # If we see some other config/edit statement once we have found ours, they are nested so we have to ignore them
      if (($line =~ /^(\s|\t)*$key/) and ($flag_found)) {
         $nested_config++ ;
         warn "$obj:$subn found a nested $key statement line=$index (nested_config=$nested_config)" if $self->debug() ;
         }

      # Did we found the config/edit statement ?
      if (not($flag_found)) {

         #$regexp = '^(\s|\t)*' . $starting_statement ;
         $regexp = '(\s|\t)*' . $starting_statement ;
         $regexp = $regexp . '$' if (not($partial_flag)) ;

         #warn "$obj:$subn regexp=$regexp" if $self->debug() ;
         if ($line =~ /$regexp/) {
            $flag_found   = 1 ;
            $start_return = $index ;

            # Retrieve the key, it could be the name in edit <NAME>
            ($return[3]) = $line =~ /^(?:\s|\t)*(?:edit|config)(?:\s|\t)*(?:")?(.*)(?:")?(?:\r|\n)*/ ;
            $return[3] =~ s/\"$// ;    #regexp may left a " at the end we need to clean
            warn "$obj:$subn found $key statement at line=$index id=" . $return[3] if $self->debug() ;
            }
         }

      # Exit if we have found the corresponding end statement
      # meaning  with no other nested_config
      if (($line =~ /^(\s|\t)*$ending_statement$/) and ($flag_found)) {
         if ($nested_config > 0) {
            $nested_config-- ;
            warn "$obj:$subn end of a nested $key, decreasing : (nested_config=$nested_config), line=$index" if $self->debug() ;
            }
         else {
            warn "$obj:$subn end of the $key statement we are looking for line=$index" if $self->debug() ;
            $exit_loop  = 1 ;
            $end_return = $index ;
            }
         }

      $index++ ;
      }

   warn "$obj:$subn returning success=$flag_found, starting=$start_return, ending=$end_return" if $self->debug() ;
   $return[0] = $flag_found ;
   $return[1] = $start_return ;
   $return[2] = $end_return ;
   return @return ;
   }

# --------------------------------------------------
#
# Internal functions not exposed outside this object
#
# ---------------------------------------------------

sub _dump_config {
   my $self = shift ;

   # used for debugging purpose only

   for (my $i = 1 ; $i <= $self->{_CONFIG_LINES} ; $i++) {
      printf("[ %d ] %s", $i, $self->{_CONFIG}[$i]) ;
      }

   print "\n_CONFIG_LINES=" . $self->{_CONFIG_LINES} . "\n" ;
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

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
