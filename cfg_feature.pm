# ****************************************************
# *                                                  *
# *             C F G   F E A T U R E                *
# *                                                  *
# *  Dissector object for feature check              *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#
# This object provides generic tools to check feature
# This is a virtual object

package cfg_feature ;
my $obj = cfg_feature ;

use Moose ;
use Data::Dumper ;
use XML::LibXML ;

use constant NESTED    => 1 ;
use constant NOTNESTED => 0 ;

# ---

sub BUILD {

   my $self = shift ;
   }

# ---

sub vdom_feature {
   my $subn = "vdom_feature" ;

   # Generic function to verify if a vdom feature is configured.
   # principle :
   # -vdom   => <vdom_name>		    : (optinal) if defined, a vdom scope is done first
   # -config => 'config statement' 	    : refine first scope to a config statement. Required
   # -config_default => 'value'             : (optional) value to return when the first config statement is not found
   #                                        :            sometime there is no config statement appearing for the default value
   # -config2 => 'config statement' 	    : (optional) refine scope with a second config statement
   # -key => 'keyword' -value => 'value_re' : (optional) verify is a set key exists. Verify its value matched the value regexp given
   # -default => 'default'                  : (optional) default value if not found in the config
   # -loop_edit => 1 			    : (optional) tell if key should be search in a edit sequences
   # -edit => 'value'                       : (optional) requires -loop_edit => 1. Refines selection to the specified edit statement
   # -edit_ignore => '/regex/'	      	    : (optional) in case edit loop is asked, we can ignore some entries (see config user local -> guest)
   # -nested => 0|1  			    : (optional) key search may or may not be nested (default 0)
   # -stop_nomatch => 0|1                   : (optional, default 1). Only applicable with -loop_edit => 1 if key was found but not matching,
   #                                          should we continue searching in further edit sequences ?
   # -warning => 'warning message'          : (optional) Global (if no vdom set) of per vdom warning to add
   # -get_key => <what key>		    : (optional) upon a match for key, return value for key <what key> on the same scope
   # -version => <Version_regexp>           : (optional) if specified, only check the feature if the version matches this regexp
   # -reverse => 1                          : (optional) if 1, reverse the matching logic

   # returned value:
   # if -get-key is used, the returned value is the result for this key

# ex 1 : feature: logdisc
# config log disk setting -> set status enable  (enable being the default for status statement)
# $self->vdom_feature(vdom => $vdom, feature => 'logdisc',  config => 'config log disk setting', key => 'status', value => 'enable', default => 'enable') ;

# ex 2 : feature: logmem
# config log memory setting -> set status enable  (disable being the default for status statement)
# $self->vdom_feature(vdom => $vdom, feature => 'logmem',   config => 'config log memory setting', key => 'status', value => 'enable', default => 'disable') ;

   # ex 3 : feature ldap
   # config user ldap -> we don't check any further statements
   # $self->vdom_feature(vdom => $vdom, feature => 'ldap',     config => 'config user ldap') ;

# ex 4 : feature wanopt
# config wanopt rule -> edit 1 -> set status enable
# $self->vdom_feature(vdom => $vdom, feature => 'wanopt',   config => 'config wanopt rule', loop_edit => 1, key => 'status', value => 'enable', default => 'enable')

   my $self    = shift ;
   my %options = @_ ;

   my @scope      = (0,     9999999999) ;
   my @edit_scope = (undef, undef) ;
   my $ok         = 0 ;
   my ($id, $path, $value) = undef ;
   my $return = 0 ;

   # Sanity checks
   die "-feature is required" if (not(defined($options{feature}))) ;
   die "-config  is required" if (not(defined($options{config}))) ;

   my $set_key           = defined($options{key})            ? $options{key}            : "" ;
   my $set_value         = defined($options{value})          ? $options{value}          : "" ;
   my $set_value_default = defined($options{default})        ? $options{default}        : "" ;
   my $loop_edit         = defined($options{loop_edit})      ? $options{loop_edit}      : 0 ;
   my $nesting           = defined($options{netsted})        ? $options{netsted}        : 0 ;
   my $flag_return_key   = defined($options{get_key})        ? 1                        : 0 ;
   my $config_default    = defined($options{config_default}) ? $options{config_default} : "" ;
   my $version           = defined($options{version})        ? $options{version}        : "" ;
   my $debug             = defined($options{debug})          ? $options{debug}          : 0 ;

   warn "\n* Entering $obj:$subn with vdom=$options{vdom} feature=$options{feature} "
     . "config=$options{config} key=$set_key value=$options{value} default=$set_value_default "
     . "loop_edit=$loop_edit nested=$nesting edit_ignore=$options{edit_ignore} get_key=$flag_return_key config_default=$config_default version=$version"
     if $self->debug()
     or $debug ;

   $options{'reverse'} = 0 if (not(defined($options{'reverse'}))) ;

   # What is our start path (depends if vdom is specified or not)
   if (defined($options{vdom})) {
      $path = $self->{VDOM}->{$options{vdom}} ;
      }
   else {
      $path = $self->{GLOBAL} ;
      }

   # Stop here if feature is already found enable
   if (defined($path->{$options{feature}})) {
      if ($path->{$options{feature}} eq 'YES') {
         warn "$subn: feature=$options{feature} already found enabled" if $self->debug() or $debug ;
         return (1) ;
         }
      }

   # See if there is a restriction on code version
   if ($version ne "") {
      if ($self->cfg->version() !~ /$version/) {
         warn "$subn: feature=$options{feature} does not pass version condition (version=$version) config version=" . $self->cfg->version()
           if $self->debug()
           or $debug ;
         return (0) ;
         }
      }

   # since we are using a regexp for matching, some chars need to be escaped
   # ex : config user tacacs+ => + needs escaping in regexp
   $options{config} =~ s/\+/\\+/ ;

   # default the feature to no
   if ($options{'reverse'}) {
      $path->{$options{feature}} = 'YES' ;
      }
   else {
      $path->{$options{feature}} = 'no' ;
      }

   # scope on vdom if vdom is provided
   if (defined($options{vdom})) {
      warn "$subn: feature=$options{feature} scoping vdom $options{vdom}" if $self->debug() or $debug ;
      @scope = $self->scope_vdom($options{vdom}) ;
      }

   # Adjust scope withing the provided -config statment
   # if config statement is not found and config_default is given, return default (undef otherwise)
   $ok = $self->cfg->scope_config(\@scope, $options{config}) ;
   if (not($ok)) {
      my $return = undef ;
      if ($config_default ne "") {
         warn "$subn: primary config statement ("
           . $options{config}
           . ") not found, returning config_default=$config_default version="
           . $self->cfg->version()
           if $self->debug()
           or $debug ;
         if ($config_default =~ /$set_value/) {
            $self->_record_feature_set($path, %options) ;
            $return = 1 ;
            }
         else {
            $return = 0 ;
            }
         }

      return ($return) ;
      }

   warn "$subn: feature=$options{feature} found -config statement" if $self->debug() or $debug ;

   # Optionally refine scope with a second config statement
   if (defined($options{config2})) {
      $ok = $self->cfg->scope_config(\@scope, $options{config2}) ;
      return (undef) if (not($ok)) ;
      warn "$subn: feature=$options{feature} found -config2 statement" if $self->debug() or $debug ;
      }

   # not looking into edit sequences
   if (not($options{loop_edit})) {

      # not looking for a specific key ?
      if ($set_key eq '') {
         $self->_record_feature_set($path, %options) ;

         # Return value for get_key if asked
         if ($flag_return_key) {
            $return = $self->cfg->get_key(\@scope, $options{get_key}, NOTNESTED, "") ;
            warn "$subn: get_key=$options{get_key} => $return" if $self->debug() or $debug ;
            return ($return) ;
            }

         }

      # Looking for a key : see if statement exists in the config scope
      $value = $self->cfg->get_key(\@scope, $set_key, $nesting, $set_value_default) ;

      if (defined($value)) {

         if ($set_value eq "") {
            warn "$subn: feature=$options{feature} key found, don't expect any value => YES" if $self->debug() or $debug ;
            $self->_record_feature_set($path, %options) ;

            # Return value for get_key if asked otherwise return 1
            if ($flag_return_key) {
               $return = $self->cfg->get_key(\@scope, $options{get_key}, NOTNESTED, "") ;
               warn "$subn: get_key=$options{get_key} => $return" if $self->debug() or $debug ;
               return ($return) ;
               }
            else { return (1) ; }
            }

         elsif ($value =~ /$set_value/) {
            warn "$subn: feature=$options{feature} key found matching value regexp $set_value => YES" if $self->debug() or $debug ;
            $self->_record_feature_set($path, %options) ;

            # Return value for get_key if asked otherwise return 1
            if ($flag_return_key) {
               $return = $self->cfg->get_key(\@scope, $options{get_key}, NOTNESTED, "") ;
               warn "$subn: get_key=$options{get_key} => $return" if $self->debug() or $debug ;
               return ($return) ;
               }
            else { return (1) ; }
            }

         else {
            warn "$subn: feature=$options{feature} key found but regexp does not match $set_value => no " if $self->debug() or $debug ;

            if ($options{reverse}) {
               $path->{$options{feature}} = "YES" ;
               }

            else {
               # the found value is not the one we want
               return (undef) if ($flag_return_key) ;
               return (0) ;
               }
            }
         }

      warn "$subn: vdom=$options{vdom} feature=$options{feature} result=" . $path->{$options{feature}}
        if $self->debug()
        or $debug ;
      }    # if (not($options{loop_edit}))

   else {

      # Looking through edit sequences (looping the edit statements)
      $edit_scope[0] = $scope[0] ;
      $edit_scope[1] = $scope[1] ;

      while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
         warn "$obj:$subn processing rule id=$id in vdom=$options{vdom} within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1]
           if $self->debug()
           or $debug ;

         # If edit_ignore statement, verify if the edit statement is acceptable
         # if not, skip it
         if (defined($options{edit_ignore})) {
            if ($id =~ /$options{edit_ignore}/) {
               warn "$subn: edit statement $id matches edit_ignore regexp $options{edit_ignore} => edit statement is ignored"
                 if $self->debug()
                 or $debug ;

               # set scope for next round
               $edit_scope[0] = $edit_scope[1] ;
               $edit_scope[1] = $scope[1] ;
               next ;
               }
            }

         # if edit statement is given, make sure we select the right one
         if (defined($options{edit})) {
            if ($id !~ /$options{edit}/) {
               warn "$subn: edit statement $id does not matches edit regexp $options{edit_ignore} => edit statement is skipped"
                 if $self->debug()
                 or $debug ;

               # set scope for next round
               $edit_scope[0] = $edit_scope[1] ;
               $edit_scope[1] = $scope[1] ;
               next ;
               }
            }

         $value = $self->cfg->get_key(\@edit_scope, $set_key, $nesting, $set_value_default) ;

         if (defined($value)) {

            if ($set_value eq "") {
               warn "$subn: feature=$options{feature} key found, don't expect any value => YES" if $self->debug() or $debug ;
               $self->_record_feature_set($path, %options) ;

               # Return value for get_key if asked
               if ($flag_return_key) {
                  $return = $self->cfg->get_key(\@edit_scope, $options{get_key}, NOTNESTED, "") ;
                  warn "$subn: get_key=$options{get_key} => $return" if $self->debug() or $debug ;
                  return ($return) ;
                  }
               else { $return = 1 ; }

               }

            elsif ($value =~ /$set_value/) {
               warn "$subn: feature=$options{feature} key found, matching value regexp $set_value => YES" if $self->debug() or $debug ;
               $self->_record_feature_set($path, %options) ;

               # Return value for get_key if asked
               if ($flag_return_key) {
                  $return = $self->cfg->get_key(\@edit_scope, $options{get_key}, NOTNESTED, "") ;
                  warn "$subn: get_key=$options{get_key} => $return" if $self->debug() or $debug ;
                  return ($return) ;
                  }
               else { $return = 1 ; }

               }
            }

         # update stats if called from vdom object
         if (ref($self) eq 'cfg_vdoms') {
            $self->stat->increase(vdom => $options{vdom}, key => $options{feature}) ;
            }

         # set scope for next round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = $scope[1] ;
         }    # while

      }    # else

   # Return to tell if we matched or not (if not get_key)
   return ($return) ;
   }

# ---

sub _record_feature_set {
   my $subn = "_record_feature_set" ;

   # Set feature flag to YES/no and raise warnings

   my $self    = shift ;
   my $path    = shift ;
   my %options = @_ ;

   warn "\n* Entering $obj:$subn" if $self->debug() ;

   # sanity
   die "feature needed" if (not(defined($options{feature}))) ;

   # Set feature flag to yes (unless reverse logic)
   if ($options{reverse}) {
      $path->{$options{feature}} = "no" ;
      }

   else {

      $path->{$options{feature}} = "YES" ;

      # apply warning to the right path if needed
      if (defined($options{'warning'})) {

         # Avoid duplicate warning flags
         if (defined($path->{'warnings'})) {
            return if ($path->{'warnings'} =~ /$options{'warning'}/) ;
            }

         $path->{'warnings'} .= $options{'warning'} . " " ;
         warn "$obj:$subn adding warning, we have now=" . $path->{'warnings'} if $self->debug ;
         }
      }
   }

# ---

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
