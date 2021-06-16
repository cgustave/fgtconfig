# ****************************************************
# *                                                  *
# *             C F G   F E A T U R E                *
# *                                                  *
# *  XML rules based feature check                   *
# *                                                  *
# *  Author : Cedric Gustave cgustave@fortinet.com   *
# *                                                  *
# ****************************************************
#
# This object provides generic tools to check feature
# from rules defined in XML files
# This is a virtual object
# use for both global and vdom

package cfg_rules ;
my $obj = cfg_rules ;

use Moose ;
use Data::Dumper ;
use XML::LibXML ;

# record the current processed vdom (undef if global section)
has 'vdomCurrent' => (isa => 'Str', is => 'rw') ;

# ---

sub BUILD {

   my $self = shift ;

   # Load rules_global.xml and rules_vdom.xml
   $self->{XMLDOC} = undef ;    # LIBXML DOC reference

   # Init tag list
   $self->{TAGS} = undef ;

   # Init scope memory
   $self->{SCOPE_MEMORY} = undef ;

   # Load the XML rule files
   $self->_load_XML_rules() ;

   # Init scope
   $self->{SCOPE} = (undef, undef) ;    # means scope on all config
   }

# ---

sub initScope {
   my $subn = "initScope" ;

   # Initialize object scopes before processing global and each vdom
   # scope is set depending on vdom or global

   my $self = shift ;

   warn "\n* Entering $obj:$subn vdomCurrent=" . $self->vdomCurrent . " (nothing means global)" if $self->debug ;

   # Init scope pointer depending on who we are
   if (ref($self) eq "cfg_global") {
      warn "$obj:$subn init for global" if $self->debug ;
      $self->{SCOPE}[0] = undef ;
      $self->{SCOPE}[1] = undef ;    # means scope on all config
      }

   elsif (ref($self) eq "cfg_vdoms") {
      my $vdom = $self->vdomCurrent ;
      warn "$obj:$subn init for vdom=$vdom" if $self->debug ;

      # sanity
      die "undefined vdom in vdom processing" if (not(defined($vdom))) ;

      # Get vdom boundaries (defined in cfg_vdoms
      my $startIndex = $self->cfg->vdom_index(action => 'get', vdom => $vdom, type => 'startindex') ;
      my $endIndex   = $self->cfg->vdom_index(action => 'get', vdom => $vdom, type => 'endindex') ;
      warn "$obj:$subn init scope for vdom=$vdom => startIndex=$startIndex endIndex=$endIndex" if $self->debug ;
      $self->{SCOPE}[0] = $startIndex ;
      $self->{SCOPE}[1] = $endIndex ;
      }

   else {
      die "$obj:$subn unexpected object" ;
      }

   }

# --

sub resetScopeSets {
   my $subn = "resetScopeSets" ;

   # Resets all recorded scope sets
   # It is important to reset them before processing a new vdom or a scop recall from previous vdom
   # could be used in new vdom and cause unexpected results in case of mistakes in rules definitions
   # This gave me a hard time in Nov 2017...

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;
   $self->{SCOPE_MEMORY} = {} ;
   }

# ---

sub dataDefined {
   my $subn = "dataDefined" ;

   # Check if rule is defined (if no key is given)
   # Check if key on rule is defined if both ruleId and key are defined
   # This is generic function for global and vdoms.
   # If vdom is not defined, it is considered global

   my $self    = shift ;
   my %options = @_ ;
   my $vdom    = $options{'vdom'} ;
   my $ruleId  = $options{'ruleId'} ;
   my $key     = $options{'key'} ;
   my $value   = undef ;

   warn "\n* Entering $obj:$subn with vdom=$vdom ruleId=$ruleId key=$key" if $self->debug ;

   # Sanity
   die "ruleId is required" if (not(defined($ruleId))) ;

   # GLobal
   if (not(defined($vdom))) {
      warn "$obj:$subn global - ruleId=$ruleId Key=$key" if $self->debug ;

      if (defined($key)) {
         if ($self->{RULEDB_GLOBAL}->{$ruleId}->{$key}) {
            return 1 ;
            }
         else {
            return 0 ;
            }
         }
      else {
         if ($self->{RULEDB_GLOBAL}->{$ruleId}) {
            return 1 ;
            }
         else {
            return 0 ;
            }
         }
      }

   else {
      warn "$obj:$subn: vdom=$vdom - ruleId=$ruleId key=$key" if $self->debug ;

      if (defined($key)) {
         if ($self->{RULEDB_VD}->{$vdom}->{$ruleId}->{$key}) {
            return 1 ;
            }
         else {
            return 0 ;
            }
         }
      else {
         if ($self->{RULEDB_VD}->{$vdom}->{$ruleId}) {
            return 1 ;
            }
         else {
            return 0 ;
            }
         }
      }
   }

# ---

sub dataGet {
   my $subn = "dataGet" ;

   # Get data into rule DB
   # This is generic function for global and vdoms.
   # If vdom is not defined, it is considered global

   my $self    = shift ;
   my %options = @_ ;
   my $vdom    = $options{'vdom'} ;
   my $ruleId  = $options{'ruleId'} ;
   my $key     = $options{'key'} ;
   my $value   = undef ;

   warn "\n* Entering $obj:$subn with vdom=$vdom ruleId=$ruleId key=$key" if $self->debug ;

   # Sanity
   die "ruleId is required" if (not(defined($ruleId))) ;
   die "key is required"    if (not(defined($key))) ;

   # GLobal
   if (ref($self) eq 'cfg_global') {
      $value = $self->{RULEDB_GLOBAL}->{$ruleId}->{$key} ;
      warn "$obj:$subn global - ruleId=$ruleId Key=$key, get value=$value" if $self->debug ;
      $value = "" if (not(defined($value))) ;
      return $value ;
      }

   elsif (ref($self) eq 'cfg_vdoms') {
      die "vdom required" if (not(defined($vdom))) ;
      $value = $self->{RULEDB_VD}->{$vdom}->{$ruleId}->{$key} ;
      warn "$obj:$subn: vdom=$vdom - ruleId=$ruleId key=$key, get value=$value" if $self->debug ;
      $value = "" if (not(defined($value))) ;
      return $value ;
      }
   else {
      die "called from non expected object" ;
      }

   }

# ---

sub dataSet {
   my $subn = "dataSet" ;

   # Set data into rule DB
   # Rhis is generic function for global and vdoms.
   # If vdom is not defined, it is considered global

   my $self    = shift ;
   my %options = @_ ;
   my $vdom    = $options{'vdom'} ;
   my $ruleId  = $options{'ruleId'} ;
   my $key     = $options{'key'} ;
   my $value   = $options{'value'} ;

   warn "\n* Entering $obj:$subn with vdom=$vdom ruleId=$ruleId key=$key value=$value" if $self->debug ;

   # Sanity
   die "ruleId is required" if (not(defined($ruleId))) ;
   die "key is required"    if (not(defined($key))) ;

   # Global
   if (not(defined($vdom))) {
      warn "$obj:$subn global: ruleId=$ruleId  Key=$key, Set value=$value" if $self->debug ;
      $self->{RULEDB_GLOBAL}->{$ruleId}->{$key} = $value ;
      }

   # vdom
   else {
      warn "$obj:$subn: vdom=$vdom : ruleId=$ruleId - key=$key, Set value=$value" if $self->debug ;
      $self->{RULEDB_VD}->{$vdom}->{$ruleId}->{$key} = $value ;
      }
   }

# ---

sub warnAdd {
   my $subn = "warnAdd" ;

   # Adds a new warning for both global and vdom

   my $self      = shift ;
   my %options   = @_ ;
   my $warn      = $options{'warn'} ;
   my $toolTip   = $options{'toolTip'} ;
   my $severity  = defined($options{'severity'}) ? $options{'severity'} : 'medium' ;
   my $base      = undef ;
   my $baseDebug = undef ;

   my $vdom = defined($self->vdomCurrent) ? $self->vdomCurrent : 'global' ;
   warn "\* Entering $obj:$subn warn=$warn severity=$severity toolTip=$toolTip (rule=" . $self->{RULE_ID} . " vdom=$vdom)" if $self->debug ;

   # Sanity
   die "severity can only be low medium or high" if ($severity !~ /low|medium|high/) ;
   die "warn is require" if (not(defined($warn))) ;

   # Set base warn hash_ref
   if (ref($self) eq 'cfg_global') {
      $base      = $self->{WARN_GLOBAL} ;
      $baseDebug = "global" ;
      }

   elsif (ref($self) eq 'cfg_vdoms') {

      if (defined($vdom) and ($vdom ne "")) {

         # Must create the reference before getting it !
         $self->{WARN_VD}->{$vdom} = {} if (not($self->{WARN_VD}->{$vdom})) ;
         $base                     = $self->{WARN_VD}->{$vdom} ;
         $baseDebug                = "vdom=$vdom" ;
         }

      else {
         die "no vdom defined, don't know on which vdom we are" ;
         }

      }
   else {
      die "Call from unexpected object" ;
      }

   # Don't do anything if warning is already set
   if ($base->{$warn}) {
      warn "$obj:$subn warning warn=$warn is already in our list, skeeping" if $self->debug ;
      return ;
      }

   # Add new warn
   warn "$obj:$subn Adding warn on baseDebug=\"$baseDebug\" warn=$warn vdom=$vdom" if $self->debug ;
   $base->{$warn}->{'toolTip'}  = $toolTip ;
   $base->{$warn}->{'severity'} = $severity ;
   }

# ---

sub warnTable {
   my $subn = "warnTable" ;

   # Retrun a hash table either global, either per vdom
   # if no vdom is provided, global is asked
   # if no warning for a vdom, undef is returned

   my $self    = shift ;
   my %options = @_ ;
   my $vdom    = $options{'vdom'} ;

   warn "\* Entering $obj:$subn with vdom=$vdom" if $self->debug ;

   if (ref($self) eq 'cfg_global') {
      warn "$obj:$subn returning global vdom warn table" if $self->debug ;
      return $self->{WARN_GLOBAL} ;
      }

   elsif (ref($self) eq 'cfg_vdoms') {
      die "vdom missing" if (not(defined($vdom))) ;

      if ($self->{WARN_VD}->{$vdom}) {
         warn "$obj:$subn returning vdom=$vdom warn table" if $self->debug ;
         return $self->{WARN_VD}->{$vdom} ;
         }

      else {
         warn "$obj:$subn no warnings for vdom=$vdom" if $self->debug ;
         return ;
         }
      }
   else {
      die "Call from unexpected object" ;
      }
   }

# ---

sub processRules {
   my $subn = "processRules" ;

   # Start rules processing for both global and vdoms
   # if not defined ($self->vdomCurrent) then this is for global

   my $self = shift ;

   warn "\n* Entering $obj:$subn (vdomCurrent=" . $self->vdomCurrent . ")" if $self->debug ;

   # Init global vdom warnings
   $self->{WARN_GLOBAL} = {} ;

   # do not init $self->{WARN_VD} ! or it is cleared for all vdom
   # each time a new vdom is processed.

   # Start processing our groups
   $self->{GRP_NAME} = undef ;
   $self->{GRP_DESC} = "" ;
   $self->{GRP_NODE} = undef ;
   $self->_process_groups() ;

   # For debuging after all rules processing print the $self->{RULE} hash table
   if ($self->debug) {
      if (not(defined($self->vdomCurrent))) {
         warn "Global DB" ;
         warn "RuleTable: " . Dumper $self->{RULEDB_GLOBAL} ;
         warn "Warnings : " . Dumper $self->{WARN_GLOBAL} ;
         }

      else {
         warn "VDOM DB vdom=" . $self->vdomCurrent ;
         warn "RuleTable (" . $self->vdomCurrent . "): " . Dumper $self->{RULEDB_VD}->{$self->vdomCurrent} ;
         warn "Warnings (" . $self->vdomCurrent . "): " . Dumper $self->{WARN_VD}->{$self->vdomCurrent} ;
         }
      }
   }

# ---

sub hasMatched {
   my $subn = "hasMatched" ;

   # Returns 1 if the rule has matched or 0 if not
   # function for both global and vdom

   my $self    = shift ;
   my %options = @_ ;

   my $ruleId = $options{'ruleId'} ;
   my $vdom   = $options{'vdom'} ;     # if not provided, we rely on $self->vdomCurrent

   $vdom = defined($vdom) ? $vdom : $self->vdomCurrent ;
   warn "\n* Entering $obj:$subn with ruleId=$ruleId vdom=$vdom" if $self->debug ;

   # Sanity
   die "-ruleId is required" if (not(defined($ruleId))) ;
   die "unknow rule id=$ruleId" if (not($self->dataDefined(vdom => $vdom, ruleId => $ruleId))) ;

   # not necessary if no match on the rule
   return 0 if (not($self->dataDefined(vdom => $vdom, ruleId => $ruleId, key => 'hasMatched'))) ;

   if ($self->dataGet(vdom => $vdom, ruleId => $ruleId, key => 'hasMatched')) {
      return 1 ;
      }
   else {
      return 0 ;
      }
   }

# ---

sub expandVariables {
   my $subn = "expandVariables" ;

   # replace the variables inside the message with their values
   # takes a string reference as input and modifies the string

   my $self        = shift ;
   my %options     = @_ ;
   my $ref_message = $options{'messageRef'} ;
   my $round       = $options{'round'} ? $options{'round'} : 0 ;
   my ($myrule, $myvar, $value) = undef ;

   warn "\n* Entering $obj:$subn with message=" . $$ref_message . " round=$round" if $self->debug ;

   my $variable = undef ;
   if (($variable) = $$ref_message =~ /(?:\$)(\S+?)(?:\$)/) {    # Note \S+? where ? is the necessary non-greedy modifier
      warn "$obj:$subn rule=" . $self->{'RULE_ID'} . " found variable $variable" if $self->debug ;

      # looking for variable in the same rule (variable name is related to rule)
      if ($self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{'RULE_ID'}, key => $variable)) {
         warn "$obj:$subn variable relative to rule exists value="
           . $self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{'RULE_ID'}, key => $variable)
           if $self->debug ;
         $value = $self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{'RULE_ID'}, key => $variable) ;

         # replacing
         $$ref_message =~ s/\$$variable\$/$value/ ;
         }

      # see if the variable has absolute name (including rule id)
      # in case variable comes from another rule
      if (($myrule, $myvar) = $variable =~ /(\S+)\.(\S+)/) {    # Here we use greedy modifier, the rule is more likely to have . in its name
         warn "$obj:$subn check if variable has an absolute name rule=$myrule var=$myvar" if $self->debug ;
         if ($self->dataGet(vdom => $self->vdomCurrent, ruleId => $myrule, key => $myvar)) {
            warn "$obj:$subn found variable with obsolute name in format <rule>.<var> rule=$myrule var=$myvar with value="
              . $self->dataGet(vdom => $self->vdomCurent, ruleId => $myrule, key => $myvar)
              if $self->debug ;
            $value = $self->dataGet(vdom => $self->vdomCurrent, ruleId => $myrule, key => $myvar) ;

            # replacing
            $$ref_message =~ s/\$$variable\$/$value/ ;
            }
         else {
            warn "$obj:$subn can't find absolute name variable $variable with rule=$myrule variable=$myvar in the rule file" if $self->debug ;
            }
         }
      else {
         warn "$obj:$subn variable $variable could not be found in the rule file" if $self->debug ;
         }
      }

   warn "$obj:$subn processed message=$$ref_message" if $self->debug ;

   # If more processing is needed, go for another iteration
   # We need to limit the number of loops in case no resolution is done
   if ($round <= 3) {
      if ($$ref_message =~ /\$\S+\$/) {
         warn "$obj:$subn round=$round : more variables to process, go for another iteration" if $self->debug ;
         $round++ ;
         $self->expandVariables(messageRef => $ref_message, round => $round) if (defined($ref_message) and ($ref_message =~ /\$/)) ;
         }
      }
   else {
      warn "$obj:$subn ruleId="
        . $self->{'RULE_ID'}
        . " message=$$ref_message - some variable resolution still not done after 3 rounds. cancel resoltion"
        if $self->debug ;
      }
   }

# ---

sub expandLoopVariables {
   my $subn = "expandLoopVariables" ;

   # replace the variables inside the message with their values
   # takes a string reference as input and modifies the string

   my $self        = shift ;
   my %options     = @_ ;
   my $ref_message = $options{'messageRef'} ;

   warn "\n* Entering $obj:$subn with message=" . $$ref_message if $self->debug ;

   return if (not(defined($$ref_message))) ;

   # Nothing to do if no variables are set
   return if (not(defined($self->{VARIABLES}))) ;

   # We do have variables, look for $1, $2 ... and expand with variable index (remove 1 because table starts at 0)
   while ($$ref_message =~ /\$(\d+)/g) {
      my $tabIndex = $1 - 1 ;
      warn "$obj:$subn index=$1 found,  expanding message=$$ref_message with " . @{$self->{VARIABLES}}[$tabIndex] if $self->debug ;
      $$ref_message =~ s/\$$1/@{$self->{VARIABLES}}[$tabIndex]/g ;
      warn "$obj:$subn expanded string=$$ref_message" if $self->debug ;
      }

   }

# ---

sub _process_groups {
   my $subn = "_process_groups" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "XML doc not loaded" if (not(defined($self->{XMLDOC}))) ;

   my $XQuery  = "/groups/group" ;
   my $nodeSet = $self->{XMLDOC}->find($XQuery) ;

   foreach my $node ($nodeSet->get_nodelist()) {
      $self->{GRP_NAME} = $node->getAttribute('name') ;
      $self->{GRP_DESC} = $node->getAttribute('description') ;
      $self->{GRP_NODE} = $node ;                                # Recording group node for further processing

      warn "$obj:$subn found group name=" . $self->{GRP_NAME} . " with description=" . $self->{GRP_DESC} if $self->debug ;

      # Reset rules pointers
      $self->{RULE_NODE} = undef ;

      # Process all loop statements if any in the group first
      my $saveNode = $node ;
      $self->_process_loop() ;

      # Restore the groupe node at that top of the group
      # and then process rules (not in loop) if any restart
      $self->{GRP_NODE} = $saveNode ;
      $self->_process_rules() ;
      }

   }

# ---

sub _process_loop {
   my $subn = "_process_loop" ;

   # Process all loops from the group

   my $self = shift ;
   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "XML doc not loaded" if (not(defined($self->{XMLDOC}))) ;

   my $XQuery  = "./loop" ;
   my $nodeSet = $self->{GRP_NODE}->find($XQuery) ;

   foreach my $node ($nodeSet->get_nodelist()) {
      warn "$obj:$subn found a loop statement, extracting elements" if $self->debug ;
      my $elements = $node->getAttribute('elements') ;
      warn "$obj:$subn elements=$elements" if $self->debug ;

      # Extract elements in a non greedy way
      while ($elements =~ /(\[\S+?\])/g) {
         my $element = $1 ;
         warn "$obj:$subn element=$element" if $self->debug ;

         # process_rules using the extracted variables
         # Give the loop node as the group node
         # Original group node will be later restored when processing the rules from the group that are not part of a loop
         $self->{GRP_NODE} = $node ;
         $self->_process_rules(variables => $element) ;
         }
      }
   }

# ---

sub _process_rules {
   my $subn = "_process_rules" ;

   # We are in a group and going through rules one by one

   my $self    = shift ;
   my %options = @_ ;

   my $variables = defined($options{'variables'}) ? $options{'variables'} : "" ;

   warn "\n* Entering $obj:$subn (vdomCurrent=" . $self->vdomCurrent . " group=" . $self->{GRP_NAME} if $self->debug ;

   # Sanity
   die "no group node" if (not(defined($self->{GRP_NODE}))) ;

   # loop statement : get variables if any and record variables in global variable for the duration of the rule processing
   my @vars ;
   if ($variables ne "") {
      while ($variables =~ /(\d+|\w+),?/g) {
         warn "$obj:$subn variables $1 " if $self->debug ;
         push @vars, $1 ;
         }

      #foreach my $var (@vars) {
      #   print "var=$var " ;
      #   }
      #print "\n" ;

      # Store variables
      $self->{VARIABLES} = \@vars ;
      }

   else {
      $self->{VARIABLES} = undef ;
      }

   # processing rules
   my $XQuery  = "./rule" ;
   my $nodeSet = $self->{GRP_NODE}->find($XQuery) ;
   foreach my $node ($nodeSet->get_nodelist()) {

      # Set all pointers needed when processing a new rule
      $self->{RULE_ID} = $node->getAttribute('id') ;
      if ($self->{RULE_ID} =~ /\$\d/) {
         $self->expandLoopVariables(messageRef => \$self->{RULE_ID}) ;
         }
      $self->{RULE_DESC} = $node->getAttribute('description') ;
      if (defined($self->{RULE_DESC}) and ($self->{RULE_DESC} =~ /\$\d/)) {
         $self->expandLoopVariables(messageRef => \$self->{RULE_DESC}) ;
         }
      $self->{RULE_DEBUG} = $node->getAttribute('debug') ;
      $self->{RULE_NODE}  = $node ;

      # init non explicit value
      $self->{RULE_DEBUG} = 'disable' if ((not(defined($self->{RULE_DEBUG}))) or ($self->{RULE_DEBUG} ne 'enable')) ;
      warn "$obj:$subn found rule=" . $self->{RULE_ID} . " with description=" . $self->{RULE_DESC} . " debug=" . $self->{RULE_DEBUG} if $self->debug ;

      # Reset all rules flags
      $self->{RULE_FLAG_MATCHED} = 0 ;    # The rule has not matched

      # Go through all processing of the found rule
      $self->_process_this_rule() ;
      }
   }

# ---

sub _process_this_rule {
   my $subn = "_process_this_rule" ;

   my $self = shift ;

   warn "\n* Entering $obj:$subn (group=" . $self->{GRP_NAME} . " rule=" . $self->{RULE_ID} if $self->debug ;

   # Sanity
   die "no rule node" if (not(defined($self->{RULE_NODE}))) ;

   # Turn rule debugging on if asked by -ruledebug <rule_id>
   my $rd = $self->ruledebug() ;
   if (defined($rd)) {
      if ($rd eq $self->{RULE_ID}) {
         warn "$obj:$subn - Turning debug on for rule=" . $self->{RULE_ID} . " as per -ruledebug" ;
         $self->debug(255) ;
         }
      else {
         $self->debug(0) ;
         }
      }

   # Turn rule debugging on if debug='enable' set in rule file
   if ($self->{RULE_DEBUG} eq 'enable') {
      warn "$obj:$subn rule debug set by rule config for rule id=" . $self->{RULE_ID} ;
      $self->debug(255) ;
      }
   else {
      $self->debug(0) ;
      }

   # Init flags
   $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '0') ;

   # Init scope for the new rule
   $self->initScope() ;

   # Process match blocks
   $self->_process_match_blocks() ;

   # Process rules statements
   $self->_process_rules_statements(node => $self->{RULE_NODE}) ;
   }

# ---

sub _process_match_blocks {
   my $subn = "_process_match_blocks" ;

   # Go through the sequences of <match> blocks with a stop on match logic
   # So if a match block condition is ok, procesing of next block depends on 'logic' and if the rule has matched
   # A match block without any condition set is a catchall
   # If no match block are defined, there is no pre-condition so go to <scope> processing

   my $self = shift ;

   warn "\n* Entering $obj:$subn (group=" . $self->{GRP_NAME} . " rule=" . $self->{RULE_ID} if $self->debug ;

   my $XQuery  = "./match" ;
   my $nodeSet = $self->{RULE_NODE}->find($XQuery) ;

   foreach my $node ($nodeSet->get_nodelist()) {
      my $MatchRelease  = $node->getAttribute('release') ;
      my $MatchBuildMin = $node->getAttribute('buildMin') ;
      my $MatchBuildMax = $node->getAttribute('buildMax') ;
      my $MatchTag      = $node->getAttribute('tag') ;
      my $MatchNoTag    = $node->getAttribute('noTag') ;
      my $MatchRules    = $node->getAttribute('rules') ;
      my $MatchLogic    = $node->getAttribute('logic') ;

      # Default and Sanity
      $MatchLogic = 'stopOnMatch' if (not(defined($MatchLogic))) ;
      die "MatchLogic can only be stopOnMatch*|nextIfRuleNoMatch for rule" . $self->{RULE_ID}
        if ($MatchLogic !~ /stopOnMatch|nextIfRuleNoMatch/) ;

      warn
"$obj:$subn found <match> with MatchRelease=$MatchRelease MatchBuildMin=$MatchBuildMin MatchBuildMax=$MatchBuildMax MatchTag=$MatchTag MatchNoTag=$MatchNoTag MatchRules=$MatchRules MatchLogic=$MatchLogic"
        if $self->debug ;

      my $hasMatched = $self->_process_this_match(
         node          => $node,
         MatchRelease  => $MatchRelease,
         MatchBuildMin => $MatchBuildMin,
         MatchBuildMax => $MatchBuildMax,
         MatchTag      => $MatchTag,
         MatchNoTag    => $MatchNoTag,
         MatchRules    => $MatchRules
      ) ;

      if ($hasMatched) {

         # if (stopOnMatch), we stop here whatever the status of the rule
         # Stop further match processing as one has already matched
         my $ruleStatus = $self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched') ;

         if ($MatchLogic eq 'stopOnMatch') {
            last ;
            warn "$obj:$subn: MatchLogic=$MatchLogic : match block has matched, stop here (rule status=$ruleStatus)" if $self->debug ;
            }

         elsif ($MatchLogic eq 'nextIfRuleNoMatch') {

            if ($ruleStatus) {
               last ;
               warn "$obj:$subn: MatchLogic=$MatchLogic : match block has matched, rule has matched, stop here" if $self->debug ;
               }

            else {
               warn "$obj:$subn: MatchLogic=$MatchLogic : match block has matched, rule has NOT matched, continue next block" if $self->debug ;
               }

            }
         }
      }
   }

# ---

sub _process_this_match {
   my $subn = "_process_this_match" ;

   # Eval the match condition one by one with AND logic
   # Return 1 if all the condition given match otherwise 0

   my $self          = shift ;
   my %options       = @_ ;
   my $node          = $options{'node'} ;
   my $MatchRelease  = $options{'MatchRelease'} ;
   my $MatchBuildMin = $options{'MatchBuildMin'} ;
   my $MatchBuildMax = $options{'MatchBuildMax'} ;
   my $MatchTag      = $options{'MatchTag'} ;
   my $MatchNoTag    = $options{'MatchNoTag'} ;
   my $MatchRules    = $options{'MatchRules'} ;

   # Default return is 1 but will be set to 0 if a match condition fails
   my $return = 1 ;

   warn
"\n* Entering $obj:$subn with MatchRelease=$MatchRelease MatchBuildMin=$MatchBuildMin MatchBuildMax=$MatchBuildMax MatchTag=$MatchTag MatchNoTag=$MatchNoTag MatchRules=$MatchRules"
     if $self->debug ;

   # Sanity
   die "node is required" if not(defined($node)) ;

   # Checking release condition
   if (defined($MatchRelease)) {
      my $cfg_version = $self->cfg->config_version() ;
      warn "$obj:$subn verifying match release condition cfg_version=$cfg_version against given MatchRelease=$MatchRelease" if $self->debug ;
      if ($cfg_version =~ /$MatchRelease/) {
         warn "$obj:$subn pass release test $MatchRelease" if $self->debug ;
         }
      else {
         warn "$obj:$subn failed release test. Stopping here" if $self->debug ;
         return (0) ;
         }
      }

   # Checking mininum build condition
   if (defined($MatchBuildMin)) {
      warn "$obj:$subn verifying match minimum build condition cfg_build=" . $self->cfg->build() . " against given MatchBuildMin=$MatchBuildMin"
        if $self->debug ;
      if ($self->cfg->build() >= $MatchBuildMin) {
         warn "$obj:$subn pass minimum build test" if $self->debug ;
         }
      else {
         warn "$obj:$subn failed minimum build test. Stopping here" if $self->debug ;
         return (0) ;
         }
      }

   # Checking maximum build condition
   if (defined($MatchBuildMax)) {
      warn "$obj:$subn verifying match maximum build condition cfg_build=" . $self->cfg->build() . " against given MatchBuildMax=$MatchBuildMax"
        if $self->debug ;
      if ($self->cfg->build() <= $MatchBuildMax) {
         warn "$obj:$subn pass maximum build test" if $self->debug ;
         }
      else {
         warn "$obj:$subn failed maximum build test. Stopping here" if $self->debug ;
         return (0) ;
         }
      }

   # Checking if the given rule test logic matches
   if (defined($MatchRules)) {
      warn "$obj:$subn evaluating matching for rules binary logic with MatchRules=$MatchRules" if $self->debug ;
      if ($self->_match_rules_check_pass(MatchRules => $MatchRules)) {
         warn "$obj:$subn pass match rules test" if $self->debug ;

         # report the policy has matched
         warn "$obj:$subn rule=" . $self->{RULE_ID} . " match rule check statement has matched" if $self->debug ;
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;
         }

      else {
         warn "$obj:$subn failed match rules test" if $self->debug ;
         return (0) ;
         }
      }

   # Init TAGS for vdom
   my $vdom = defined($self->vdomCurrent) ? $self->vdomCurrent : 'global' ;
   $self->{TAGS}->{$vdom} = "" if (not(defined($self->{TAGS}->{$vdom}))) ;

   # Checking if the given tag is in our list of tags (allow loop variable expansion)
   if (defined($MatchTag)) {
      $self->expandLoopVariables(messageRef => \$MatchTag) ;

      warn "$obj:$subn verifying match MatchTag against vdom=$vdom given MatchTag=$MatchTag against TAGS list=" . $self->{TAGS}->{$vdom}
        if $self->debug ;
      if ($self->{TAGS}->{$vdom} =~ /$MatchTag/) {
         warn "$obj:$subn vdom=$vdom pass match tag $MatchTag" if $self->debug ;
         }
      else {
         warn "$obj:$subn vdom=$vdom failed match tag $MatchTag" if $self->debug ;
         return (0) ;
         }
      }

   # Checking if the given tag is not in our list of tags
   if (defined($MatchNoTag)) {
      $self->expandLoopVariables(messageRef => \$MatchTag) ;

      warn "$obj:$subn verifying match MatchTag against vdom=$vdom given MatchTag=$MatchTag" if $self->debug ;
      if ($MatchNoTag !~ /$self->{TAGS}->{$vdom}/) {
         warn "$obj:$subn vdom=$vdom pass match noTag $MatchNoTag" if $self->debug ;
         }
      else {
         warn "$obj:$subn vdom=$vdom failed match noTag $MatchNoTag" if $self->debug ;
         return (0) ;
         }
      }

   # At this point, if we have failed one of the match statement, we would have returned already
   # Go through rules statements within the <match> block
   $self->_process_rules_statements(node => $node) ;

   # report if the block has matched
   return ($return) ;
   }

# ---

sub _match_rules_check_pass {
   my $subn = "_match_rules_check_pass" ;

   # Parse the <matche rules=''> expression, extract rules and see if they match
   # combine with OR/AND logical operators with rules ID and eval the resulting expression

   my $self       = shift ;
   my %options    = @_ ;
   my $MatchRules = $options{'MatchRules'} ;

   my ($ruleId, $ruleMatch) ;
   my ($result, $op) ;          # must be undef to start

   warn "\n * Entering $obj:$subn with MatchRules=$MatchRules" if $self->debug ;

   # Extract tokens
   my @tokens ;
   if (
      (@tokens) =
      $MatchRules =~ /(\$\S+\$)  # rule : 2 possible format with or wihout group : $group.rule$ or $rule$
	                           (?:\s*)    # ignore spaces
	   			   (OR|AND)?  # op
				   (?:\s*)    # ignore spaces
	                          /gx
     )
   {

      warn "$obj:$subn some tokens were extracted" if $self->debug ;

      # Process each tokens
      foreach my $token (@tokens) {
         next if (not(defined($token))) ;
         warn "$obj:$subn current result=$result, new token=$token" if $self->debug ;

         # the token is a rule
         if (($ruleId) = $token =~ /\$(\S+)\$/) {
            die "rule=" . $self->{RULE_ID} . "rules statement references an undefined rule id" if (not(defined($ruleId))) ;

            $ruleMatch = $self->hasMatched(vdom => $self->vdomCurrent, ruleId => $ruleId) ;
            warn "$obj:$subn token is a valid rule reference ruleId=$ruleId with ruleMatch=$ruleMatch" if $self->debug ;

            # This is the initial result if no operator has been seen yet
            if (not(defined($result)) and (not(defined($op)))) {
               warn "$obj:$subn initial result set with $ruleMatch" if $self->debug ;
               $result = $ruleMatch ;
               }

            # compute result from the last seen operator
            elsif ((defined($result)) and (defined($op))) {
               my $logic ;
               $logic = '|' if ($op eq 'OR') ;
               $logic = '&' if ($op eq 'AND') ;
               die "undefined logic" if (not(defined($logic))) ;
               my $evalString = $result . ' ' . $logic . ' ' . $ruleMatch ;
               $result = eval($evalString) ;
               warn "$obj:$subn evalString=$evalString => eval result=$result" if $self->debug ;
               die "incorrect rule format for ruleid=" . $self->{RULE_ID} if (not(defined($result))) ;
               }

            # incorrect logic format
            else {
               die "rule " . $self->{RULE_ID} . " format is wrong" ;
               }

            }

         # Token is an operator
         elsif (($op) = $token =~ /(AND|OR)/) {
            warn "$obj:$subn token is an operator $op" if $self->debug ;
            }

         }
      }

   # Could not see one token from the rules
   else {
      die "Failed to extract <match rules=>tokens for rule=" . $self->{RULE_ID} ;
      }

   # return the last state or computed result
   warn "$obj:$subn overall expression result=$result" if $self->debug ;
   return ($result) ;
   }

# ---

sub _process_rules_statements {
   my $subn = "_process_rules_statements" ;

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "no node given" if not(defined($node)) ;

   # Process <scope> statements
   $self->_process_scopes(node => $node) ;

   # Process <comparison> statements
   $self->_process_comparisons(node => $node) ;

   # Process <do> statements
   $self->_process_all_do(node => $node) ;
   }

# ---

sub _process_scopes {
   my $subn = "_process_scopes" ;

   # Start at provided XML node and go through the sequence of <scope> statements and process them all in the given order
   # At first, the rule is set to not have matched

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn (group=" . $self->{GRP_NAME} . " rule=" . $self->{RULE_ID} if $self->debug ;

   # Sanity
   die "no node given" if not(defined($node)) ;

   # search for scope path list
   my $XQuery  = "./scope" ;
   my $nodeSet = $node->find($XQuery) ;

   # Init rule hasMatched to 0 per default
   $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '0')
     if (not($self->dataDefined(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched'))) ;

   foreach my $node ($nodeSet->get_nodelist()) {
      my $isLastScope = $self->_process_this_scope(node => $node) ;
      if (defined($isLastScope) and ($isLastScope eq 'last_scope')) {
         warn "$obj:$subn last <scope> statement tells to stop here, this is a no match for the rule" if $self->debug ;
         last ;
         }
      else {
         warn "$obj:$subn last <scope> statement has matched, move on to the next one" if $self->debug ;
         }
      }
   }

# ---

sub _process_this_scope {
   my $subn = "_process_this_scope" ;

   # See what type of scope statement we have and call the appropriate one
   # There are :
   # <scope recall=""> : to recall a previously recorded scope with scopeSet
   # <scope path=""> : for config blocks
   # <scope edit=""> : for edit blocks

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "node required" if (not(defined($node))) ;

   # scope recall
   my $recall = $node->getAttribute('recall') ;
   if ((defined($recall) and $self->_scope_recall(recall => $recall))) {
      warn "$obj:$subn recalled offsets, no path rule required, condider a path hit if the recall exists" if $self->debug ;
      $self->{RULE_SCOPE_HIT} = 1 ;
      }

   # get all attributes and expand variables
   my $path = $node->getAttribute('path') ;
   $self->expandLoopVariables(messageRef => \$path) if (defined($path)) ;

   my $nested = (defined($node->getAttribute('nested')) and ($node->getAttribute('nested') eq 'yes')) ? 1 : 0 ;

   my $default = $node->getAttribute('default') ;
   $self->expandLoopVariables(messageRef => \$default) if (defined($default)) ;

   my $forceMatchOnFail = (defined($node->getAttribute('forceMatchOnFail')) and ($node->getAttribute('forceMatchOnFail') eq 'yes')) ? 1 : 0 ;

   my $edit = $node->getAttribute('edit') ;
   $self->expandLoopVariables(messageRef => \$edit) if (defined($edit)) ;

   my $loopOnEdit = (defined($node->getAttribute('loopOnEdit')) and ($node->getAttribute('loopOnEdit') eq 'yes')) ? 1 : 0 ;
   my $ignoreEdit = $node->getAttribute('ignoreEdit') ;
   $ignoreEdit = "" if (not(defined($ignoreEdit))) ;
   $self->expandLoopVariables(messageRef => \$ignoreEdit) ;

   # Initialise RULE_SCOPE_HIT
   $self->{RULE_SCOPE_HIT} = 0 if (not(defined($self->{RULE_SCOPE_HIT}))) ;

   # If path is provided, scope the path
   if (defined($path) and not($recall)) {
      warn "$obj:$subn <scope path=$path>" if $self->debug ;

      # Initialise flag telling if there was a SCOPE HIT
      $self->{RULE_SCOPE_HIT} = 0 ;
      $self->_scope_path(
         path             => $path,
         loopOnEdit       => $loopOnEdit,
         ignoreEdit       => $ignoreEdit,
         nested           => $nested,
         default          => $default,
         forceMatchOnFail => $forceMatchOnFail
      ) ;
      }

   # In case of scope failure (no match)
   if ($self->{RULE_SCOPE_HIT} eq '0') {

      if ($forceMatchOnFail) {
         warn "$obj:$subn path statement was not found but forceMatchOnFail triggers the match" if $self->debug ;
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;

         # Note : we still will process the search statement and check against default values if not found
         # Since the scope was not restricted, anything could match in the condif so we force empty boundaries for the futur
         # search (so the defaut setting comparison would apply)
         warn "$obj:$subn forcing a closed SCOPE [0-0] to restrict searches because config statement was not found" if $self->debug ;
         $self->{SCOPE}[0] = 0 ;
         $self->{SCOPE}[1] = 0 ;
         }

      else {
         # There was no match so we don't carry on with further scope, the rule has no match. end.
         warn "$obj:$subn rule=" . $self->{RULE_ID} . " path=$path not found. match fail. Don't proceed with further <scope>" if $self->debug ;
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '0') ;
         return ("last_scope") ;
         }
      }

   # if loopOnEdit , go through all edit statements for key search
   if ($loopOnEdit) {
      die "can't have <scope loopOnEdit> with <scope edit>" if ($loopOnEdit and defined($edit)) ;
      $self->_loop_edit(node => $node, ignoreEdit => $ignoreEdit, forceMatchOnFail => $forceMatchOnFail) ;
      }

   # scope on given edit
   elsif (defined($edit) and ($edit ne '')) {

      # scope edit
      warn "$obj:$subn <scope edit=$edit>" if $self->debug ;
      $self->_scope_edit(
         edit             => $edit,
         forceMatchOnFail => $forceMatchOnFail,
         nested           => $nested,
      ) ;
      $self->_search_all_keys(node => $node->parentNode()) ;
      }

   # Search for key without scoping
   else {
      warn "$obj:$subn no <scope path= loopEdit=> nor <scope edit>" if $self->debug ;

      # Search keys starting from the parent node
      $self->_search_all_keys(node => $node->parentNode()) ;
      }
   }

# ---

sub _process_comparisons {
   my $subn = "_process_comparisons" ;

   # Process the optional <comparison> section
   # All provide comparisons are treated as logical OR
   # the rule hasMatched flag is reset to 0 before processing the first one

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn (group=" . $self->{GRP_NAME} . " rule=" . $self->{RULE_ID} if $self->debug ;

   # Sanity
   die "no node given" if not(defined($node)) ;

   # search for comparison list
   my $XQuery  = "./comparison" ;
   my $nodeSet = $node->find($XQuery) ;

   # Reset the rule hasMatch during the first comparison
   # All comparisons from the list may generate a match (OR logic)
   my $count = 1 ;
   foreach my $node ($nodeSet->get_nodelist()) {

      if ($count == 1) {

         # Reset the rule hasMatched flag
         warn "$obj:$subn 1st comparison line, resetting hasMatched to 0" if $self->debug ;
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '0') ;
         }

      $self->_process_this_comparison(node => $node) ;
      $count++ ;
      }

   }

# ---

sub _process_this_comparison {
   my $subn = "_process_this_comparison" ;

   # Process with the comparison.
   # make the rules match if both values are equal
   # optionaly, negate=no can reverse the logic
   # Upon a match, the following <do> statements will be applied

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "node required" if (not(defined($node))) ;

   # Get values
   my $value1 = defined($node->getAttribute('value1')) ? $node->getAttribute('value1') : "" ;
   my $value2 = defined($node->getAttribute('value2')) ? $node->getAttribute('value2') : "" ;
   my $negate = (defined($node->getAttribute('negate')) and ($node->getAttribute('negate') eq 'yes')) ? '1' : '0' ;

   warn "$obj:$subn found <comparison> with value1=$value1 value2=$value2 negate=$negate" if $self->debug ;

   # Expand values variables
   if (defined($value1) and ($value1 =~ /\$/)) {
      $self->expandVariables(messageRef => \$value1) ;
      $self->expandLoopVariables(messageRef => \$value1) ;
      }

   if (defined($value2) and ($value2 =~ /\$/)) {
      $self->expandVariables(messageRef => \$value2) ;
      $self->expandLoopVariables(messageRef => \$value2) ;
      }

   warn "$obj:$subn after variable expansions we have value1=$value1 value2=$value2" if $self->debug ;

   # Ignore the comparison statement if some variables failed to expand
   # This may happen if the required config statement is not present in the config file (old version)
   if (($value1 =~ /\$/) or ($value2 =~ /\$/)) {
      warn "$obj:$subn remaining non expanded variables, cancelling comparison to avoid false positives" if $self->debug ;
      return ;
      }

   my $hasMatched = 0 ;
   if ($value1 eq $value2) {

      if (not($negate)) {
         $hasMatched = 1 ;
         }
      else {
         $hasMatched = 0 ;
         }
      }
   else {

      if (not($negate)) {
         $hasMatched = 0 ;
         }
      else {
         $hasMatched = 1 ;
         }

      }

   # Proceed
   if ($hasMatched) {

      # report the policy has matched
      warn "$obj:$subn rule=" . $self->{RULE_ID} . " comparison statement has matched" if $self->debug ;
      $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;
      }
   }

# ---

sub _process_all_do {
   my $subn = "_process_all_do" ;

   # if we had a match for the rule from either a matchgroup or not, from a search or
   # even a forceMatch, all <do> statement from the rule should be processed
   # if called from a <match> group :
   #   - we only process the <do> statement of the group
   #   - later, we will process with the <do> statements outside of the <match>

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn with (vdom=" . $self->vdomCurrent . " group=" . $self->{GRP_NAME} . " rule=" . $self->{RULE_ID} if $self->debug ;

   # Sanity
   die "no node given" if not(defined($node)) ;

   my $hasMatched = $self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched') ;

   if (not($hasMatched)) {
      warn "$obj:$subn vdom=" . $self->vdomCurrent . " rule=" . $self->{RULE_ID} . " has not matched. no <do> processing" if $self->debug ;
      return ;
      }
   else {
      warn "$obj:$subn vdom=" . $self->vdomCurrent . " rule=" . $self->{RULE_ID} . " has matched" if $self->debug ;
      }

   # search for scope path list
   my $XQuery  = "./do" ;
   my $nodeSet = $node->find($XQuery) ;

   foreach my $node ($nodeSet->get_nodelist()) {
      $self->_process_this_do(node => $node) ;
      }
   }

# ---

sub _process_this_do {

   my $subn = "_process_this_do" ;

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "node required" if (not(defined($node))) ;

   # Get attributes

   # tagSet : Sets a tag that may be later checked as <tagTest> on rules
   my $tagSet = $node->getAttribute('tagSet') ;
   $self->expandLoopVariables(messageRef => \$tagSet) if (defined($tagSet)) ;
   $self->_do_tagSet(tagSet => $tagSet) if (defined($tagSet)) ;

   # scopeSet
   my $scopeSet = $node->getAttribute('scopeSet') ;
   $self->_do_scopeSet(scopeSet => $scopeSet) if (defined($scopeSet)) ;

   # getKeyValue
   my $getKeyValue = $node->getAttribute('getKeyValue') ;
   $self->expandLoopVariables(messageRef => \$getKeyValue) ;

   # default
   my $default = $node->getAttribute('default') ;
   $self->expandLoopVariables(messageRef => \$default) if (defined($default)) ;

   # format
   my $format = $node->getAttribute('format') ;

   # Alias
   my $alias = $node->getAttribute('alias') ;
   $self->expandLoopVariables(messageRef => \$alias) if (defined($alias)) ;

   # Nested
   my $nested = $node->getAttribute('nested') ;

   $self->_do_getKeyValue(
      getKeyValue => $getKeyValue,
      default     => $default,
      format      => $format,
      alias       => $alias,
      nested      => $nested
   ) if (defined($getKeyValue)) ;

   # warn
   my $warn = $node->getAttribute('warn') ;
   $self->expandLoopVariables(messageRef => \$warn) ;

   my $toolTip = $node->getAttribute('toolTip') ;
   $self->expandLoopVariables(messageRef => \$toolTip) ;

   my $severity = $node->getAttribute('severity') ;

   $self->_do_warn(
      warn     => $warn,
      toolTip  => $toolTip,
      severity => $severity
   ) if (defined($warn)) ;

   # setKeyValue
   my $setKeyValue = $node->getAttribute('setKeyValue') ;
   $self->_do_setKeyValue(setKeyValue => $setKeyValue) if (defined($setKeyValue)) ;
   }

# ---

sub _do_setKeyValue {
   my $subn = "_do_setKeyValue" ;

   my $self        = shift ;
   my %options     = @_ ;
   my $setKeyValue = $options{'setKeyValue'} ;

   my ($myKey, $myValue) = undef ;

   warn "\n* Entering $obj:$subn with setKeyValue=$setKeyValue" if $self->debug ;

   # split key and value
   if (($myKey, $myValue) = $setKeyValue =~ /([A-Za-z0-1\._-]+)(?:\s*=>\s*)([A-Za-z0-1\$\._-]+)/) {
      warn "$obj:$subn split : myKey=$myKey myValue=$myValue" if $self->debug ;
      }

   else {
      die "Failed to extract key and value from <do setKeyValue with setKeyValue=$setKeyValue" ;
      }

   # Expends variables in value if needed
   if (defined($myValue) and ($myValue =~ /\$/)) {
      $self->expandVariables(messageRef => \$myValue) ;
      $self->expandLoopVariables(messageRef => \$myValue) ;
      }

   if (defined($myKey)) {
      warn "$obj:$subn writting key=$myKey value=$myValue" if $self->debug ;
      $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => $myKey, value => $myValue) ;
      }

   else {
      die "undefined key in setKeyValue" ;
      }
   }

# ---

sub _do_warn {
   my $subn = "_do_warn" ;

   # Sets warning message
   # warning message may contain a variable defined with a $<key> sign.
   # in this case, the variable should be replaced with its value in the warn message
   # ex :
   #<rule id='vdLimit.SSLVPN'>
   #   ...
   #   <getKeyValue='sslvpn' >
   #   <do warn='SSLPVN_LIMIT_$sslvpn$'>

   my $self     = shift ;
   my %options  = @_ ;
   my $warn     = $options{'warn'} ;
   my $toolTip  = defined($options{'toolTip'}) ? $options{'toolTip'} : "" ;
   my $severity = defined($options{'severity'}) ? $options{'severity'} : 'medium' ;

   warn "\n* Entering $obj:$subn with warn=$warn toolTip=$toolTip severity=$severity" if $self->debug ;

   # sanity
   die "severity can only be high, medium or low" if ($severity !~ /high|medium|low/) ;

   # replace variables with their values in the message if any
   if (defined($warn) and ($warn =~ /\$/)) {
      $self->expandVariables(messageRef => \$warn) ;
      $self->expandLoopVariables(messageRef => \$warn) ;
      }

   if (defined($toolTip) and ($toolTip =~ /\$/)) {
      $self->expandVariables(messageRef => \$toolTip) ;
      $self->expandLoopVariables(messageRef => \$toolTip) ;
      }

   # Add warn
   $self->warnAdd(warn => $warn, toolTip => $toolTip, severity => $severity) ;
   }

# ---

sub _do_getKeyValue {
   my $subn = "_do_getKeyValue" ;

   # Get the value from the provided key within the current scope

   my $self        = shift ;
   my %options     = @_ ;
   my $getKeyValue = $options{'getKeyValue'} ;
   my $default     = $options{'default'} ;
   my $format      = $options{'format'} ;
   my $alias       = $options{'alias'} ;
   my $nested      = $options{'nested'} ;

   warn "\n* Entering $obj:$subn with getKeyValue=$getKeyValue alias=$alias" if $self->debug ;

   my $keyValue = $self->cfg->get_key($self->{SCOPE}, $getKeyValue, $nested, $default) ;

   my $result      = undef ;
   my $flag_record = 0 ;

   # The value we will record at the end
   my $record = $getKeyValue ;

   if (defined($keyValue)) {

      # we have a keyValue returned
      warn "$obj:$subn getKeyValue=$getKeyValue found keyValue=$keyValue" if $self->debug ;
      $result      = $keyValue ;
      $flag_record = 1 ;
      }

   else {
      # no key was found
      if (defined($default)) {

         # use default value if given
         warn "$obj:$subn keyValue not found but we have a default=$default given" if $self->debug ;
         $result      = $default ;
         $flag_record = 1 ;
         }
      }

   # use alias if given instead of using getKeyValue as reference
   if (defined($alias)) {
      warn "$obj:$subn using alias=$alias" if $self->debug ;
      $record = $alias ;
      }

   # format value with RE if asked
   if (defined($format) and $flag_record) {
      warn "$obj:$subn processing returned value=$result with format RE=$format" if $self->debug ;
      my $value = undef ;
      if (($value) = $result =~ /$format/) {
         $result = $value ;
         warn "$obj:$subn format RE processing has matched result=$result" if $self->debug ;
         }
      else {
         warn "$obj:$subn format RE processing has not matched" if $self->debug ;
         }
      }

   # recording of value
   if ($flag_record) {
      $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => $record, value => $result) ;
      }
   }

# --

sub _do_tagSet {
   my $subn = "_do_tagSet" ;

   my $self    = shift ;
   my %options = @_ ;
   my $tagSet  = $options{'tagSet'} ;

   warn "\n* Entering $obj:$subn with tagSet=$tagSet" if $self->debug ;

   # Init TAGS for vdom
   my $vdom = defined($self->vdomCurrent) ? $self->vdomCurrent : 'global' ;
   $self->{TAGS}->{$vdom} = "" if (not(defined($self->{TAGS}->{$vdom}))) ;

   $self->{TAGS}->{$vdom} .= "|$tagSet" ;
   warn "$obj:$subn vdom=$vdom TAGS in list are :" . $self->{TAGS}->{$vdom} if $self->debug ;
   }

# ---

sub _do_scopeSet {
   my $subn = "_do_scopeSet" ;

   my $self     = shift ;
   my %options  = @_ ;
   my $scopeSet = $options{'scopeSet'} ;

   warn "\n* Entering $obj:$subn with scopeSet=$scopeSet" if $self->debug ;
   $self->{SCOPE_MEMORY}->{$scopeSet}[0] = $self->{SCOPE}[0] ;
   $self->{SCOPE_MEMORY}->{$scopeSet}[1] = $self->{SCOPE}[1] ;

   warn "$obj:$subn memorized scopeSet=$scopeSet with boundaries low=" . $self->{SCOPE}[0] . " high=" . $self->{SCOPE}[1] if $self->debug ;
   }

# ---

sub _scope_recall {
   my $subn = "_scope_recall" ;

   # recalls scope previously memorized with scopeSet

   my $self    = shift ;
   my %options = @_ ;
   my $return  = 0 ;

   my $recall = $options{'recall'} ;

   warn "\n* Entering $obj:$subn with recall=$recall - rule=" . $self->{RULE_ID} if $self->debug ;

   # sanity
   die "undefined recall in scope recall" if (not(defined($recall))) ;

   if (not($self->{SCOPE_MEMORY}->{$recall})) {
      warn "$obj:$subn the recalled name=$recall has not been previously set at rule=" . $self->{RULE_ID} . " ignore rule" if $self->debug ;
      return 0 ;
      }

   if (not($self->{SCOPE_MEMORY}->{$recall}[0]) or not($self->{SCOPE_MEMORY}->{$recall}[1])) {
      die "Rules error : recalled scope=$recall has undefined boundaries low="
        . $self->{SCOPE_MEMORY}->{$recall}[0]
        . " high="
        . $self->{SCOPE_MEMORY}->{$recall}[1]
        . " at rule="
        . $self->{RULE_ID} ;
      }

   else {

      # Apply recalled boundaries to scope
      warn "$obj:$subn setting scope to [" . $self->{SCOPE_MEMORY}->{$recall}[0] . "," . $self->{SCOPE_MEMORY}->{$recall}[1] . "]" if $self->debug ;
      $self->{SCOPE}[0] = $self->{SCOPE_MEMORY}->{$recall}[0] ;
      $self->{SCOPE}[1] = $self->{SCOPE_MEMORY}->{$recall}[1] ;
      return 1 ;
      }
   }

# ---

sub _scope_path {
   my $subn = "_scope_path" ;

   # Reduce current scope with the given filter (if exists)
   # Sets flags for future keysearch (nested, loopOnEdit, ignoreEdit)

   my $self    = shift ;
   my %options = @_ ;

   my $path             = $options{'path'} ;
   my $loopOnEdit       = $options{'loopOnEdit'} ;
   my $ignoreEdit       = $options{'ignoreEdit'} ;
   my $nested           = $options{'nested'} ;
   my $forceMatchOnFail = $options{'forceMatchOnFail'} ;

   warn
"\n* Entering $obj:$subn with path=$path , loopOnEdit=$loopOnEdit , ignoreEdit=$ignoreEdit , nested=$nested , forceMatchOnFail=$forceMatchOnFail - rule="
     . $self->{RULE_ID}
     if $self->debug ;

   # Adjust scope with the provided path statment
   # if path statement is not found and scope default is given, return default (undef otherwise)

   my $ok = $self->cfg->scope_config(\@{$self->{SCOPE}}, $path) ;
   if ($ok) {
      warn "$obj:$subn found path=$path, scope restricted with boundaries low=" . $self->{SCOPE}[0] . " high=" . $self->{SCOPE}[1] if $self->debug ;
      $self->{RULE_SCOPE_HIT} = 1 ;
      return ;
      }

   else {
      warn "$obj:$subn: path $path was not found" if $self->debug ;
      if ($forceMatchOnFail) {
         warn "$obj:$subn forceMatchOnFail" if $self->debug ;
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;
         }
      }
   }

# ---

sub _loop_edit {
   my $subn = "_loop_edit" ;

   # Go through all edit statement until we find one that has the searched key.
   # if the key is found, record edit statement where is was found
   # If ignoreEdit statement, verify if the edit statement is acceptable
   # if not, skip it

   my $self             = shift ;
   my %options          = @_ ;
   my $node             = $options{'node'} ;
   my $ignoreEdit       = $options{'ignoreEdit'} ;
   my $forceMatchOnFail = $options{'forceMatchOnFail'} ;

   my ($id, $value) = undef ;

   warn "\n* Entering $obj:$subn with ignoreEdit=$ignoreEdit , forceMatchOnFail=$forceMatchOnFail" if $self->debug ;

   # Sanity
   die "node is required" if (not(defined($node))) ;

   # Record current path end
   my $pathEnd = @{$self->{SCOPE}}[1] ;

   # Set initial scope
   my @edit_scope = (undef, undef) ;
   $edit_scope[0] = @{$self->{SCOPE}}[0] ;
   $edit_scope[1] = @{$self->{SCOPE}}[1] ;

   while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
      warn "$obj:$subn rule=" . $self->{RULE_ID} . " scoped with start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug ;

      # Note : exit condition is the failure to scope_edit

      # If ignoreEdit statement, verify if the edit statement is acceptable. Skip it if not.
      if (defined($ignoreEdit) and ($ignoreEdit ne "")) {
         if ($id =~ /$ignoreEdit/) {
            warn "$subn: rule_id=" . $self->{RULE_ID} . " edit=$id matches ignoreEdit regexp=$ignoreEdit => edit statement is ignored"
              if $self->debug ;

            # set scope for next round
            $edit_scope[0] = $edit_scope[1] ;
            $edit_scope[1] = $pathEnd ;
            next ;
            }
         }

      # Set search scope and search key and see if it matches the
      @{$self->{SCOPE}}[0] = $edit_scope[0] ;
      @{$self->{SCOPE}}[1] = $edit_scope[1] ;
      $self->_search_all_keys(node => $node->parentNode()) ;

      # If there was a match stop here, if not moved to next position
      if ($self->hasMatched(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID})) {
         warn "$obj:$subn found the key with a match in loop_edit. Stop loop processing" if $self->debug ;
         return ;
         }

      else {
         warn "$obj:$subn no match for this edit, moving scope to next one" if $self->debug ;
         $edit_scope[0] = @{$self->{SCOPE}}[1] ;
         $edit_scope[1] = $pathEnd ;
         }

      }

   # In case of match failure, see forceMatchOnFail
   if (($forceMatchOnFail) and ($self->dataGet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched') eq '0')) {
      warn "$obj:$subn the searched key was not found while looping edit statements but forceMatchOnFail triggers the match" if $self->debug ;
      $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;
      }
   }

# ---

sub _scope_edit {
   my $subn = "_scope_edit" ;

   my $self    = shift ;
   my %options = @_ ;

   my $edit             = $options{'edit'} ;
   my $nested           = $options{'nested'} ;
   my $forceMatchOnFail = $options{'forceMatchOnFail'} ;

   warn "\n* Entering $obj:$subn with edit=$edit , nested=$nested , forceMatchOnFail=$forceMatchOnFail - rule=" . $self->{RULE_ID} if $self->debug ;

   # Set initial scope
   my @edit_scope = (undef, undef) ;
   $edit_scope[0] = @{$self->{SCOPE}}[0] ;
   $edit_scope[1] = @{$self->{SCOPE}}[1] ;

   my $id = undef ;
   while ($self->cfg->scope_edit(\@edit_scope, 'edit', \$id)) {
      warn "$obj:$subn rule=" . $self->{RULE_ID} . " within scope start=" . $edit_scope[0] . " end=" . $edit_scope[1] if $self->debug ;

      if ($id !~ /$edit/) {
         warn "$subn: edit statement $id does not matches edit regexp $edit => edit statement is skipped" if $self->debug ;

         # set scope for next round
         $edit_scope[0] = $edit_scope[1] ;
         $edit_scope[1] = @{$self->{SCOPE}}[1] ;
         next ;
         }

      else {
         $self->{SCOPE}[0] = $edit_scope[0] ;
         $self->{SCOPE}[1] = $edit_scope[1] ;
         warn "$obj:$subn found edit=$edit, scope restricted with boundaries low=" . $self->{SCOPE}[0] . " high=" . $self->{SCOPE}[1]
           if $self->debug ;
         last ;
         }
      }
   }

# ---

sub _search_all_keys {
   my $subn = "_search_all_keys" ;

   # Go through the sequences of <search key=>
   # for each one, see if the key exists, otherwise use default value
   # compare the key value with the expected one if given
   # flag the match and record the value

   my $self    = shift ;
   my %options = @_ ;
   my $node    = $options{'node'} ;

   my $ruleMatch = 0 ;    # default rule match result is 0
   my $searchMatch ;

   warn "\n* Entering $obj:$subn" if $self->debug ;

   # Sanity
   die "node is required" if (not(defined($node))) ;

   my $XQuery  = "./search" ;
   my $nodeSet = $node->find($XQuery) ;

   my $hasSearchKey = 0 ;

   foreach my $node ($nodeSet->get_nodelist()) {
      $hasSearchKey = 1 ;
      my $key     = $node->getAttribute('key') ;
      my $match   = $node->getAttribute('match') ;
      my $default = $node->getAttribute('default') ;
      my $nested  = $node->getAttribute('nested') ;
      my $logic   = defined($node->getAttribute('logic')) ? $node->getAttribute('logic') : 'or' ;    # default logic is OR

      die "logic can only be or|and (default or)" if ($logic !~ /^(or|and)$/) ;

      my $negate = (defined($node->getAttribute('negate')) and ($node->getAttribute('negate') eq 'yes')) ? '1' : '0' ;

      warn "$obj:$subn found <search> with key=$key match=$match default=$default nested=$nested negate=$negate" if $self->debug ;
      $searchMatch = $self->_search_this_key(key => $key, match => $match, default => $default, negate => $negate, nested => $nested) ;

      # Applies the match logic for this search with the match status of the rule
      warn "$obj:$subn <search> with key=$key returned searchMatch=$searchMatch (ruleMatch=$ruleMatch logic=$logic )..." if $self->debug ;
      if ($logic eq 'and') {
         $ruleMatch = $ruleMatch & $searchMatch ;
         }
      elsif ($logic eq 'or') {
         $ruleMatch = $ruleMatch | $searchMatch ;
         }
      warn "$obj:$subn <search> with key=$key (AND) => new ruleMatch=$ruleMatch" if $self->debug ;
      }

   # If no search key is given, this is considered as an implicit match (having the scope path present is enough)
   if (not($hasSearchKey)) {
      warn "$obj:$subn no search key provided, this is an implicit match" if $self->debug ;
      $ruleMatch = 1 ;
      }

   # reports the overall match for the rule based on the different search logics
   $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => $ruleMatch) ;

   # debug
   if ($self->debug) {
      if (ref($self) eq 'cfg_global') {
         warn "$obj:$subn <search> summary for global rule=" . $self->{RULE_ID} . " :\n" . Dumper $self->{RULEDB_GLOBAL}->{$self->{RULE_ID}}
           if $self->debug ;
         }
      else {
         warn "$obj:$subn <search> summary for vdom="
           . $self->vdomCurrent
           . " rule="
           . $self->{RULE_ID} . " :\n"
           . Dumper $self->{RULEDB_VD}->{$self->vdomCurrent}->{$self->{RULE_ID}}
           if $self->debug ;
         }
      }
   }

# ---

sub _search_this_key {
   my $subn = "_search_this_key" ;

   my $self    = shift ;
   my %options = @_ ;
   my $key     = $options{'key'} ;
   my $match   = $options{'match'} ;
   my $default = $options{'default'} ;
   my $negate  = $options{'negate'} ;
   my $nested  = $options{'nested'} ;

   my $has_matched = 0 ;

   warn "\n* Entering $obj:$subn with key=$key match=$match default=$default negate=$negate nested=$nested" if $self->debug ;

   # Sanity
   die "a key is required in <search>" if (not(defined($key))) ;

   # Expands match variables to allow a match from another key or loop element

   # key
   if ($key =~ /\$/) {
      $self->expandVariables(messageRef => \$key) ;
      $self->expandLoopVariables(messageRef => \$key) ;
      }

   # match
   if (defined($match) and ($match =~ /\$/)) {
      $self->expandVariables(messageRef => \$match) ;
      $self->expandLoopVariables(messageRef => \$match) ;
      }

   # default
   if (defined($default) and ($default =~ /\$/)) {
      $self->expandVariables(messageRef => \$default) ;
      $self->expandLoopVariables(messageRef => \$default) ;
      }

   my $keyValue = $self->cfg->get_key($self->{SCOPE}, $key, $nested, $default) ;
   warn "$obj:$subn key=$key found keyValue=$keyValue start=$self->{SCOPE}[0] stop=$self->{SCOPE}[1]" if $self->debug ;

   if (defined($keyValue)) {

      # Testing match

      if (
         (
            # there is a match condition defined and it matches the returned key
            # or we don't expect anything in particular, only presence of the key (or ok with its default value)
            not($negate) and ((defined($match) and ($keyValue =~ /$match/))
               or (not(defined($match))))
         )

         # negative logic, a match is defined but is not the returned key
         or (($negate) and (defined($match)) and ($keyValue !~ /$match/))
        )
      {
         # The keyValue is inline with our match regexp (also considering the negate logic)

         warn "$obj:$subn keyValue=$keyValue, match=$match, negate=$negate => Match found" if $self->debug ;

         # Store key value with value found
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => $key, value => $keyValue) ;

         # A match was found for the rule
         $has_matched = 1 ;

        # (changed with addition of logic) $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => '1') ;
         }

      # There is a match defined but the return value does not match
      elsif (not($negate) and (defined($match)) and ($keyValue !~ /$match/)) {

         warn "$obj:$subn keyValue=$keyValue, match=$match, negate=$negate => no match" if $self->debug ;

         # Store key value with value found and that's it
         $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => $key, value => $keyValue) ;
         }

      }

   else {
      # no keyValue defined. So key was not found at all
      if ($negate) {
         warn "$obj:$subn negate=1 and no keyValue defined => match=1" if $self->debug ;

         # (changed with addition of logic) $self->dataSet(vdom => $self->vdomCurrent, ruleId => $self->{RULE_ID}, key => 'hasMatched', value => 1) ;
         $has_matched = 1 ;
         }
      }

   # Returns the match status of the rule
   return ($has_matched) ;
   }

# ---

sub _load_XML_rules {
   my $subn = "_load_XML_rules" ;

   # Load the rule files according do what we are (cfg_global or cfg_vdoms)
   # looking for 'rules' dir from a sequence of possible path :
   # current dir, /usr/local/share/fgtconfig/rules, /usr/share/fgtconfig/rules

   my $self = shift ;
   my $path ;

   warn "\n* Entering $obj:$subn with obj ref=" . ref($self) if $self->debug ;

   # Search for rules dir
   for my $p ('./rules/', '/usr/local/share/fgtconfig/rules/', '/usr/share/fgtconfig/rules/', '/etc/fgtconfig/rules/') {
	  if (-d $p) {
		 $path = $p ;
		 warn "$obj:$subn found rules dir path=$p" if $self->debug ;
		 last ;
	     }
      }

   if (ref($self) eq 'cfg_global') {
      $self->{XMLDOC} = XML::LibXML->load_xml(location => $path."rules_global.xml")
        or die "Cannot open XML rule file rules_global.xml" ;
      }
   elsif (ref($self) eq 'cfg_vdoms') {
      $self->{XMLDOC} = XML::LibXML->load_xml(location => $path."rules_vdom.xml")
        or die "Cannot open XML rule file rules_vdom.xml" ;
      }
   else {
      die "$obj:$subn unexpected object reference " . ref($self) ;
      }
   }

# ---

# ___END_OF_OBJECT___
__PACKAGE__->meta->make_immutable ;
1 ;
