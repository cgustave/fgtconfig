# fgtconfig  and  translate

## fgtconfig

##### Disclaimer :
This is not a Fortinet official product. It is provided as-is without official support.  
I have made this tool for my own use. It can be used at your own risk.  

##### Author :
Cedric GUSTAVE

##### Install :
- use **'release'** branch from github  
  The 'master' branch is mainly used for development and may not be always working.  
  `git clone -b release git://github.com/cgustave/fgtconfig.git`

- vim integration : map a command `:Fgtconfig` to open the config summary:  
  In the ~/.vimrc:  
  ~~~
  :function! Func_fgtconfig()
  :       let mycmd = "w! /tmp/fgtconfig.txt"
  :       execute mycmd
  :       ! (clear && cd ~/github/perl/fgtconfig && ./fgtconfig.pl -config /tmp/fgtconfig.txt -routing -ipsec -stat -color)
  :endfunction
  :command -nargs=0 Fgtconfig call Func_fgtconfig()
  ~~~

#### Description : 

fgtconfig.pl is a command line tool taking a FortiGate configuration file as input and produces a configuration summary dashboard.
It also warns on potential unusual, non-expected, potentially harmful or simply important characteristics of the configuration.
The dashboard output detail can be changed based on given options. Display may be adjusted to fit with XTERM colours. An HTMLizer allows HTML based coloring.
The option -splitconfig is used to split a multi-vdom configuration into separated vdom files (and the summary)
Additional statistics on configuration objects can be extracted with option -stat
To ease configuration comparison between two version (config check after upgrade for instance), a full report for all vdoms (sorted) can be done between the 2 configuration files. Use diff to highlight the differences.

#### Usage :

~~~
# perl fgtconfig.pl -config <filename> [ Operation selection options ]

Description: FortiGate configuration file summary, analysis, statistics and vdom-splitting tool

Input: FortiGate configuration file

Selection options:

[ Operation selection ]

   -splitconfig              : split config in multiple vdom config archive with summary file
   -fullstats                : create report for each vdom objects for build comparison


Display options:
    -stat                    : display some statistics (suggest. yes)
    -color                   : ascii colors
    -html                    : HTML output
    -debug                   : debug mode
    -ruledebug               : rule parsing debug
~~~

#### Rules

The analysis of the configuration file is based on rules. Rules are defined in an xml format, stored in a directory name 'rules'  
Rules are organized in different files. 'global' are rules for global objects while 'vdom' are rules applied to each vdoms.  
Rules 'warnings' are rules to raise user attention with some warning messages.  
Rules 'features' are used to identify when some features are used, they are used to display the summary report.  

~~~
drwxrwxr-x 2 cgustave cgustave  4096 Apr 30 22:03 .
drwxrwxr-x 7 cgustave cgustave  4096 Apr 30 21:58 ..
-rw-rw-r-- 1 cgustave cgustave   440 Apr 30 21:11 rules_global_debug.xml
-rw-rw-r-- 1 cgustave cgustave  3485 Apr 30 21:11 rules_global_features.xml
-rw-rw-r-- 1 cgustave cgustave 19483 Apr 30 21:11 rules_global_warnings.xml
-rw-rw-r-- 1 cgustave cgustave   335 Apr 30 21:11 rules_global.xml
-rw-rw-r-- 1 cgustave cgustave   118 Apr 30 21:11 rules_vdom_debug.xml
-rw-rw-r-- 1 cgustave cgustave  9025 Apr 30 21:11 rules_vdom_features.xml
-rw-rw-r-- 1 cgustave cgustave 12980 Apr 30 21:11 rules_vdom_warnings.xml
-rw-rw-r-- 1 cgustave cgustave   850 Apr 30 21:11 rules_vdom.xml
~~~

##### Rules syntax

###### Groups
Rules are organised in groups. Groups don't change the rule reference, it is only used to organize the rule file for better formating

```xml
<group name='tunnels' description='All rules related to tunneling technologies'>
    <rule id='ipsec' description='has ipsec tunnels defined'>
    ...
    </rule>
    <rule id='sslvpn' description='has sslvpn tunnels defined' >
    ...
    </rule>
    <rule id='gre' description='has gre tunnels defined' >
    ...
    </rules>
    ...
</group> 
```


###### Rules syntax

**Part 1 : looping statement:**  
`<loop  elements="['aaa','bbb','ccc']['ddd','eee','ffff']..." )`

- Encloses multiple rules
- Allows the use of set of variables for each loop **$1, $2, $3** that can be used within the enclosed rules definitions in order to factorize them.  
  Useful if rules definition are more or less the same like for logging (config log syslog1, syslog2, fortianalyzer...)  

```xml
<loop elements="['fortianalyzer','fortinet']['fortianalyzer2','fortinet']['fortianalyzer3','fortinet']['syslogd','third-party']['syslogd2','third-party']['syslogd3','third-party']">
   <rule id='$1'>
    ... write rule definition using $1 and $2
  </rule>
</loop>
```

Example : this loop will go through 6 iterations where $1 and $2 would be replaced with the following values:
```
   1 :    $1='fortianalyzer'  ;   $2='fortinet'
   2 :    $1='fortianalyzer2' ;   $2='fortinet'  
   3 :    $1='fortianalyzer3' ;   $2='fortinet'
   4 :    $1='syslogd'        ;   $2='third-party'
   5 :    $1='syslogd2'       ;   $2='third-party'
   6 :    $1='syslogd3'       ;   $2='third-party'
```

------

**Part 2 : Definition:**  
`<rule id='my_id' description='my_description' [ comment='my_comment' debug=disable*|enable] >)`

- Encloses the full rule definition
- **id='my_id'** : used as unique reference for the rule (and as search element for result feedback) - mandatory
    Should be unique even amongst all the rule groups
- **description='my_description'** : A 'human' description of what this rule is catching - mandatory
- **comment='my_comment'** : Optional. Provides more references, for instance bug #. multiple comment lines should be allowed.
- **debug=[disable\*|enable]** : for debuging purpose, debug can be activated for this rule from the rules file

------

**Part 3 : Pre-matching filters:**  
`<match [tag='my_tag1' noTag='my_tag' rules='xxxxx' release='my_release_re'  buildMin='min' buildMax='max' logic='stopOnMatch*|nextIfRuleNoMatch' ] >`

- Encloses part4 (scoping statements), part5 (condition statement) and optionally part6 items
  Allows to apply a different rules based on different pre-match filters such as release.
  Multiple <match> are allowed with a 'stop-on-match' behavior
  Eventually, a <match> without other attribute can used as a last 'catch-all'
  Pre-matching attributes can be combined in one single match statement. If so, all must be true to match (AND)

- **Matching attributes** are : 
  - **tag='my_tag1'** : Required match tag (optional). For now, a single tag is allowed 
  - **Tag='my_tag'** : Reversed logic - (optional). For now, a single tag is allowed
  - **rules='$ruleX$(binary logic)$ruleY$(binary logic)$ruleZ$...**  
	   where $ruleX$, $ruleY$... will be evaluated with rule match result (0 or 1)
	   (logic) are binary logical operator 'AND','OR' to apply between rule matches

	   Example: `$ipsec-policy-based$ OR $ipsec-interface-based$`
	   would match if one of the two rules 'ipsec-policy-based','ipsec-interface-based' has matched. Expression is evaluated from left to right (so : 1 OR 0 AND 1 => 1 ; 1 AND 0 OR 1 => 1)
	   If the final result is true, the rule is declared to have matched (like a positive search statement)

  - **release='my_release_re'**     : Regexp compared to config release in dotted format  (ex: "^5\."  to match 5.0, 5.2, 5.4) - (optional) 
  - **buildMin='min_build_number'** : Everything strictly less would be ignored  (optional)
  - **buildMax='max_build_number'** : Everything strictly above would be ignored (optional) 
  - **logic='stopOnMatch\*|nextIfRuleNoMatch'** : Defines the behavior if a match is found but the search associated to the match fails. The default behavior is to stop on a match and not process further match statement, even if the search result is a fail (stopOnMatch). With 'nextIfRuleNoMatch', the next match statement will be considered in case the rule has not matches (like scope/search did not catched anything). 

------

**Part 4 : Scoping statements** :  
`<scope>` 
- List of selection statements applied successively in the given order to define/refine the scoping in the config file.
   Note : global or vdom scope : not needed as the rules are split in 2 files (global_rules.xml, vdom_rules.xml)
- Scope attributes may be used in conjunction
- Scope attributes are : 
  - **recall='name'** : Position the scope to the given recorded scope name (optional). If asked and the recalled name was not previously set, the rule is ignored. 
  - **path='config path'** : Refines the current scope to the given path block defined with the given config statement (can be repeated multiple times).
      A path is a 'config' block. For instance :
      `<scope path='config system interface'>` will restrict the scope to every config lines from config system interface to the corresponding 'end' statement. 
  - **edit='my_wanted_edit_key'** : refines the scope with the given config 'edit' id. Need to be used after a 'path' rule
  - **loopOnEdit=yes|no\*** : Apply the condition statements through all edits in the path block statement or not (optional)
  - **ignoreEdit='my_exlusion_pattern'** : optional, requires loopEdit. Ignore edit key if matching (ex : config user local need to ignore guest)
  - **forceMatchOnFail=yes|no\*** : If the scoping failed because the given attribute could not be found we would ignore all further scope statement and apply the <do> actions.
	  Note that any further <search> will be done within an empty scope. Thanks to this, the searches will only be compared to default values (because they won't exist anyway). 

------

**Part 5 : search statements**:  
`<search key='key' [ match='regexp_of_value_to_match'  default='default_value' negate=yes|no* nested=yes|no* logic=or*|and ]>`

-  List of required conditions for a match in the given scope.
- The binary logic between the different search statement depends on the 'logic' option, 'OR' per default :
	The rule result is an 'OR' with the previous rule match status OR this search status. 
- Search attributes are :
  - **match='my_re'** : if value is found, check if the returned value matches with the given regexp (optional)
  - **default='use_this_if_not_found'** : if no key is found, use the given default value (optional)
  - **negate=yes|no\***  : reverses the search logic (optional)
  - **nested=yes|no\***  : search the key in nested path blocks or not , default is 'no' 
  - **logic=or\*|and**   : defines the logic to apply when multiple search statements are defined in a rule.
    - logic='or'  : apply a <rule_match_status_before> OR <match_result_for_this_rule> , so the rule matches even if the previous search didn't
	- logic='and' : apply a <rule_match_status_before>  AND <match_result_for_this_rule>, so the rule match if the previous status is already a match and this search is also a match.
- List of multiple key search are allowed. In this case the return value should be based on the 'id' + 'key' like 'id.key1', 'id.key2' 
- Comment : it does not make sens to have a list of <search> with the first one having a "logic=and" statement because the rule would never match (0 (initial statement) and 1 = 0) 

------

**Part 6 : comparison statement**:  
`<compare>`

- compare 2 values : 'value1' and 'value2'. Both values can use variables. If matching, the rules has matches and the following <do> statements will be applied.  
  Note : this overrides all previous potential rule matches from the above "scope or search" statements. 

  - <compare value1='myValue1' value2='myValue2' [negate=yes|no*] />
    - **value1='myValue1'** : first value to compare, ex: value1='$offload-ipsec-host$'
	- **value2='myValue2'** : second value to compare ex: '$enc-offload-antireplay$'
	- **negate=yes|no\***   : reverses the search logic (optional)

  - multiple comparison lines may exists. In this case, the rule 'hasMatched' is reset before dealing with the first one.
	Any comparison statement match may generate a hasMatch (OR logic between the lines) 

------

**Part 7 : Action list** :  
`<do>`

- List of all actions required when a rule has matched 
- Possible allowed action are :
  - **tagSet='my_tag_to_set'**   : Sets a tag that may be later checked as <tagTest> on rules further down
  - **scopeSet='my_scope_name'** : Records the current scope (to be reused in other rules)
  - **getKeyValue='keyId' [ alias='key_alias' format='regular_expression' default='default_value' nested=yes|no\* ] >**
	  Return a key value optionally processed by a regexp, if not found, use a default value.  
	  Additional attributes are : 
	  - **alias='my_alias'** : Sets the identifier that will be used to return the asked value (see FMG case later).
		  If not specified, the identifier will be the key name itself (most of the time)
	  - **format='my_format'** : Formats the returned value with the provided Regex (optional) 
  - **warn='MY_WARNING_FLAG'** : Sets the warning flag. Optionally a Tool Tip (**toolTip='message'**) could be given to user to provide more details why a warning flag is raised in this case. A severity could also be provided (**severity='low|medium\*|high** with low (yellow), medium( orange/default), high (red) ) which could be used to set different colors to the warnings. Default would be medium.  
	ex :  `<do warn "MY_WARN_FLAG" toolTip='This is dangerous because blabla' severity='high'>`  
	Variable substitution ($variable$) is allowed in 'warn' and 'toolTip' attributes (see 'replacing variables with their values' below)

  - **setKeyValue='my_key=>my_value'** : Sets the given key/value pair my_key=my_value. Allows variable expansion in my_value (see "Replacing variables with their values" ).
	  For instance if the rule id is "myRuleId", we could ask for myRuleId.my_key and get 'my_value'.
	  This could be useful in conjunction with <scope 'forceMatchOnFail'>. It could also be useful to force the implicit ruleId.hasMatched to 1|0* 

------

**Feedback :**

- Feedback from the match is given by updating the hash table 'global' or 'vdom' table
- Upon a match at the last <scope> state in the rule list, the implicit rule_id.hasMatched is set to 1 (see also setKeyValue='hasMatched,false') otherwise 0.
  This is use to test a feature with a if ($self->{'VDOM'}->{$vdom}->{'ruleId.hasMatched'}) ;

**Order :**
- Rules must be processed in the given order to allow <tag> and <tagSet> mechanism 


**Replacing variables with their values** :
- It is allowed to use variables inside the rules. 
- A variable is written $key$ and key should be matching a value previously set either in the same rule definition or from a previous rule definition.
- When using a variable in the same rule, variable name is just the key. An variable 'absolute' name composed of <rule_name>.<variable> is also allowed.  
  Example :

  ```xml
  <rule id='system.global' description='Global system table' >
      <scope path='config system interface' />
      <scope edit='mgmt1' />
      <search key='type' />
      <do getKeyValue='alias' alias='plouf' format="(?:.*_)(\S*)"/>
      <do warn='WAHOU_$plouf$_$system.global.type$' />
  </rule>
  ```

  With the config:
   ```
	config system interface
		edit "mgmt1"
			set vdom "root"
			set allowaccess ping https ssh
			set type physical
			set alias "FortiManager_P1"
		next
   ```

In this example the warn message has 2 variables: **plouf**, local to the rule (related variable) and **system.global.type**, expressed with and absolute name rule_id='system.global' and variable='type'. 

- In this case, warn message after processing is : WAHOU_P1_physical
- Alias "FortiManager_P1" is changed to P1 because of the formatting regexp "(?:.*_)(\S*)" given. 


**Samples for global rules**:

- Return multiple keys from the same config statement. All keys accessible by rule 'id.key'

```xml
<rule id='system.global' description='Global system table' >
   <scope path='config system global' / >
   <search key='hostname' />
   <search key='management-vdom' default='root'/>
   <search key='optimize' default='antivirus  '/>  
   <search key='conn-tracking' default='enable  '/>  
    ...
</rule>
```
  No specific action is specified. Once processed, accessing hostname will be done with 'system.global.hostname'

- Check if one of the interfaces is declared as type 'wireless'. Set the warn flag "FORTIWIFI" if so:
```xml
<rule id='wifi' description='FortiWifi unit' >
     <scope path='config system interface'  loopOnEdit='yes' />
     <search key='type' value='wireless'/>
     <do warn='FORTIWIFI' />
</rule>
```

- Check if FortiManager Central management is used by checking key 'central-management'.  
  By default there is no such key (mean disabled). If enabled, warn and retrieve the FMG ip.
  There 2 different syntaxes depending on versions : v3.00 and v4.00/v5.00.

```xml
<rule id='centralFMG' description='FortiManager IP address when using central-management' >
   <match release=''^3\.0">
      <scope path='config system fortimanager'  />
	  <search key='central-management' value='enable' default='disable' />
      <do getKeyValue='ip' />
   </match>
   <match>
      <scope path='config system central-management'  />
      <search key='type' value='fortimanager' default='fortimanager' />
      <do getKeyValue='fmg'  alias='ip' />
   </match>
   <do warn='CENTRAL_MGMT_FMG' />
</rule>
```
Notes:
  - FMG IP is accessible through centralFMG.ip regardless the version that matched (thanks to 'alias')
  - If the catchall last match block is used, the returned key would be alias 'ip' however the search will be made with 'fmg' key.
  - If either match block match, action 'warn' would be done.
  - It would also be possible to have an action 'warn' within the match block.

	
- Check potentially dangerous 5.0 network visibility feature. It is enabled by default so if there is no 'config system network-visibility' in the config it IS enabled.

```xml
<rule id='networkVisibility.dst' description='Destination network visibility' >
   <comment='May cause high CPU (Mantis #227304)' />
   <match release='^5\.0">
      <scope path='config system network-visibility'forceMatchOnFail='yes' />
      <search key='destination-visibility' value='enable' default='enable' />
      <do warn='DST_VISIBILITY' />
   </match>
```

- Examples with sub rules for device logging:  

```xml
<rule id='logDev' description='Check use of log device' forEach$1='fortianalyzer,fortianalyzer2,fortianalyzer3,syslogd,syslogd2,syslogd3'' >
   <scope path='config system $1' />
   <search key='status' value='enable' default='disable' />
   <do getKeyValue='server' />
</rule>
```
Notes:
  - To test feature syslogd : logDev.syslogd.match
  - To get syslog server ip : logDev.syslogd.server


- Example with <comparison> : extract 2 values from the config system npu and raise a warning if they are different :  

```xml
  <rule id='warn-npu-mismatch' description='warn if offload and host ipsec encryption mismatch in NPU setting' >
     <scope path='config system npu'  />
     <search key='offload-ipsec-host' default='disable' />
     <search key='enc-offload-antireplay' default='disable' />
     <comparison value1='$offload-ipsec-host$' value2='$enc-offload-antireplay$' negate='yes' />
     <do warn ="NPU_ENC_MISMATCH" toolTip="enc-offload-antireplay and offload-ipsec-host should have the same setting" />
  </rule>
```

**Samples for vdom rules:**

- Syntax is the same as for global

- Check if enabled local users are refined ('guest' should be ignored as it is always there)

```xml
<rule id='local.user' description='Enabled local users defined ' />
     <comment>guest user should be ignored</comment>
     <comment>check if user is not disabled</comment>
     <scope path='config user local'  loopOnEdit='yes'  ignoreEdit='^guest$'/>
     <search key='status' value='enable' default='enable'>
</rule>
```

- Check if BGP is used:
	- double config scope needed
	- we only check the existence of a neighbor with a defined remote-as

```xml
<rule id='bgp' description='check if BGP is used' />
     <scope path='config router bgp'  />
     <scope path='config neighbor'  loopOnEdit='yes' />
     <search key='remote-as'>
</rule>
```

- Check if OSPF  is used:
  - double config scope needed
  - if a 'config area' it is enough

```xml
<rule id='ospf' description='check if OSPF is  used' />
     <scope path='config router ospf'  />
     <scope path='config area'  />
</rule>
```


- Check if identity based route exist (use of 'nested' to find a defined gateway)

```xml
<rule id='identity.based.route' description='check if ID based route exist' />
     <comment>nested search</comment>
     <scope path='config firewall identity-based-route' />
     <scope path='config rules' nested='yes' />
     <search key='gateway' />
</rule>

- Checks if the 'always' schedule was altered :
  - uses 'negate'
  - uses 'scope edit'

```xml
<rule id='modified.schedule.always' description='check if default always schedule was modified' />
     <scope path='config firewall schedule recurring' />
     <scope edit='always'  />
     <search key='day'
              value='sunday monday tuesday wednesday thursday friday saturday'
              default='sunday monday tuesday wednesday thursday friday saturday'
              negate='yes'
      / >
     <do warn='MOD_ALWAYS_SCHEDULE' severity='high'
            toolTip='The default Always schedule has been altered probably by mistake. This will cause long outages during some days of the week.' />
     </rule>
```

-  VDOM limit type of rule where the retrieved limit value is part of the warn flag returned :

```xml
<rule id='vdLimit' forEach$1='session,dialup-tunnel,sslvpn' >
   <scope path='config system vdom-property' />
   <scope edit='$1' />
   <do getKeyValue='$1'  alias='value' />
   <do warn='VDLIMIT_$1_$value' />
</rule>
```

- Example with 2 possible config statement for the same feature (fsae or fsso) using match logic 'nextIdRuleNoMatch' :

```xml
<rule id='feature.fsso' description='fsso is defined' debug='disable'>
   <match logic='nextIfRuleNoMatch' >
      <scope path='config user fsae' loopOnEdit='yes' />
      <search key='server' />
   </match>
   <match>
      <scope path='config user fsso' />
      <search key='server' />
   </match>
</rule>
```

## translate

##### Disclaimer :
This is not a Fortinet official product. It is provided as-is without official support.  
I have made this tool for my own use. It can be used at your own risk.  

##### Author :
Cedric GUSTAVE

##### Install:
- Use **'release'** branch.  
  The 'master' branch is mainly used for development and may be not always working.  
  `git clone -b release git://github.com/cgustave/fgtconfig.git`

#### Description :

translate.pl is a command line tool to process a defined list of configuration changes on a fortigate configuration file.
In Tecnical Support, replication of customer's environment in FortiPoC requires a significant work for preparing the configuration for FortiPoc. Each time a new problem is reported, a minimum of 3 Fortigate configurations need to be processed to inserted to POC with a high potential of human errors. 

#### Usage :

`translate.pl -config <fgt_config.conf> -transform <transform_file.xml> [ -debug <level>]`

Takes the given fortigate source file 'fgt_config.conf' as source and apply the transformation rules defined in the xml transform file 'transform_file.xml'

```xml
options :
    - config <fgt_config.conf >       : FortiGate source configuration file (.conf) 
	- transform <transform_file.xml>  : Transform file is an xml file containing the transform rules
    - debug <level>                   : (optional) for troubleshooting purpose
```

#### Transform file:

The transform file is an xml file organized in sections where it transform is defined as an xml leaf.  

Sections are :
- **options**   : Options for processions, for instance to only extract some vdoms from the original file.  
- **global**    : Transformations applied at the global level of a fortigate configuation.  
- **all_vdoms** : Transformations at vdom level, on all vdoms.  
- **vdoms**     : Transformations at vdom level, only on the given vdom.  

Below is a sample of an empty transform file showing the sections  
It can be used as a template.  

```xml
<?xml-stylesheet type="text/xsl" href="translate.xsl"?>

<transform>

   <!-- General option for configuration file processing -->
   <options>
   </options>

<!-- Transforms at the global level-->
   <global>
   </global>

   <!-- Transforms at the the vdom level, applied to all vdoms-->
   <all_vdoms>
   </all_vdoms>

   <!-- Transforms at the the vdom level, applied only to selected vdoms-->
   <vdoms>
      <vdom name='root'>
      </vdom>
   </vdoms>
</transform>
```


#### Supported transform operations:

##### Systematic transforms

- **changing config header :**  This is the first line of fortigate configuration, need to change model, type and admin user (with admin). KVM type is automatically set.  
   Example:  
  `#config-version=FG100E-6.2.3-FW-build1066-191218:opmode=0:vdom=0:user=robert`  
  is automatically changed to:  
  `#config-version=FGVMK6-6.2.3-FW-build1066-191218:opmode=0:vdom=0:user=admin`

- **remove non physical ha heartbeat interfaces** : After transforms are applied, some ha heartbeat interfaces may have turned to non-physical devices (like loopback). In this case, the heart-beat interface is removed.

##### Options section transforms

- **selective vdom extraction**: Only selects and extracts the vdoms provided in the list from the original configuration.  
   Useful if only a few vdoms are revelevants from a many-vdom orginal configuration.
   ```xml
   <vdom_filter list="vdom1|vdom2|...|vdomn" />
   ```

##### Global section tranforms


- **config global** : admintimeout, alias, gui-theme (green*|neutrino|blue|melongene|mariner), admin ports, timezone code.  
   ```xml
   <system_global admintimeout="475" alias="HUB2" gui-theme="neutrino" admin-port="80" admin-sport="443" admin-ssh-port="22" timezone="28" /> 
   ```
- **admins profile** : set/uset password, set/unset trustedhosts.  
   ```xml
   <system_admin password="unset" trusted_host="unset" />
   ```

- **system dns** : change primary and secondary dns server, set/unset the source-ip.  
   ```xml
   <system_dns primary="192.168.0.253" secondary="192.168.0.254" source-ip="unset" />
   ```

- **physical switch** : Removes the complete `config system physical-switch` block.  
   ```xml
   <system_physical-switch action="remove"/>
   ```

- **virtual switch** : Removes the complete `config system virtual-switch` block.  
   ```xml
   <system_physical-switch action="remove"/>
   ```

- **system ha** : set/unset password,  set group-id, set/unset monitor.  
	```xml
	<system_ha password="unset" group-id="1" monitor="unset"/>
	```

- **system central-management** : set/unset type (none|fortiguard|fortimanager|unset), set/unset soure-ip.  
   ```xml
   <system_central-management type="none" fmg-source-ip="unset" />
   ```

- **log fortianalyzer settings** : set/unset status (enable|disable|unset), set/unser server. set/unset source-ip.   
	```xml
	<log_fortianalyzer_setting status="enable" source-ip="unset" server="192.168.0.252"/>

	```

- **system ntp**: set/unset ntpsync (unset|enable|disable), set server, unset source-ip.  
	```xml
	<system_ntp ntpsync="enable" source-ip="unset" server='"ntp.pool.org"'/>
	```

- **system netflow**: set collector-ip, set/unset source-ip.  
	```xml
	<system_netflow collector-ip="192.168.0.254" source-ip="unset" />
	```

###### Interfaces processing

Processing changes on the interfaces. All interfaces processing are groupd in a global subsection 'system_interfaces':
```xml
<global>
   <system_interfaces ignored_physical_action="translate_to_loopback">
      <port action="<action>" name="<port_name>" />
      <port action="<action>" name="<port_name>" />

</global>
```

* Different 'actions' can be defined (see below)
  - **translate** : changes the name or the type of interface. The 'speed' statement is also automatically removed. 
  - **configure** : add, remove or modify configuration statements from the interface.
  - **keep**      : no translation applied for this interface.

* A default behaviour can be selected for all the interfaces that were not concerned by translation/configurations.  
  If action="keep" is specified for a particular interface, no default behavior would be applied to it.  

  **"ignored_physical_action"** :  
    - **none**                  : Default. Nothing is done.
    - **ignore**                : Interface is renamed with a specific 'ignore pattern' __IGNORE__<interface>_ in the configuration.  
	                              Upon loading the configuration, config statements containing the ignore interface would be deleted.  
	                              Warning : This could cause a cascade of config statement deletion.  
    - **translate_to_loopback** : Untouched interfaces are translated to loopback.  
	                              Warning : This may still lead to config losses. For instance, a loopback cannot be member of a zone, so if the origin interface is part of a zone, the zone object would be lost and all the cascade of config statements using this zone.  
								
    - **translate_to_vdlink**   : Untouched interfaces are translated to dummy inter-vdom-link named 'ign_interface'.  
	                            This should avoid any configuration loss.  
* **tunnel_status**: (disable|enable)
Optional. If the configuration has a lot of ipsec tunnels and you only need couple in the test, it is a good idea to bring all IPsec tunnel down in the first place, then use`<'action='configure' status='up' />`  to change the status for the ones you need.



* **action='translate'** : Translates interface name and some of interfaces attributes:  

  - **name**        : Original interface name (mandatory)
  - **type**        : Original interface type ('physical' by default)
  - **dst_name**    : Desired replacement name (not mandatory)
  - **dst_type**    : Desired replacement interface type (default 'physical'). It the chosen destination type is a vdom-link, it is also created.
  - **description** : Set interface description attribut. This is usefull to keep the name of the former interface for instance)
  - **alias**       : Set interface alias. Another handy way to keep track of role or previous interface name


* **action='keep'** : Consider the interface 'touched' so the ignore_physical_action is not applied:

  - **name**        : Original interface name (mandatory)
  - **description** : Set interface description attribut. This is usefull to keep the name of the former interface for instance)
  - **alias**       : Set interface alias. Another handy way to keep track of role or previous interface name


* **action='configure'** : Add, remore or update interface properties:

  - **name**        : Original interface name (mandatory). If not found, a new physical interface with this name is created.
  - **status**      : Set status (up|down) 
  - **description** : Set description
  - **alias**       : Set alias
  - **ip**          : Set ip 
  - **vlanid**      : Set vlanid
  - **allowaccess** : Set allowaccess
  - **vdom**        : Set vdom 
 
  LACP specific:
  - **member**      : Set member (ports list)
  - **lacp-mode**   : Set lacp-mode (static|active|passive)
  - **min-links**   : Set min-links (1-31)


**Examples of system_interface transforms** :

```xml
 <system_interfaces ignored_physical_action="translate_to_loopback" >
         <port action="keep" name="port10"/>
         <port action="translate" name="port19" dst_name="port2" description="former port19"  />
         <port action="translate" name="port22"  dst_name="LB_HC_VPN" dst_type="loopback" description="former port22"/>
         <port action="translate" name="port23"  dst_name="port7" description="former port23"  />
         <port action="translate" name="port25"  dst_name="port5" description="former port25"  />
         <port action="translate" name="port26"  dst_name="port6" description="former port26"  />
         <port action="translate" name="port28"  dst_name="port3" description="former port28"  />
         <port action="translate" name="port29"  dst_name="port1" description="former port29"  />
         <port action="translate" name="port30"  dst_name="port8" description="former port30"  />
         <port action="translate" name="port31"  dst_name="port9" description="former port31"  />

         <port action="translate" name="npu0_vlink0" type="npu"  dst_name="vlink0_0" dst_type="vdom-link"  description="former npu0_vlink0" />
         <port action="translate" name="npu0_vlink1" type="npu"  dst_name="vlink0_1" dst_type="vdom-link"  description="former npu0_vlink1" />
         <port action="translate" name="npu1_vlink0" type="npu"  dst_name="vlink1_0" dst_type="vdom-link"  description="former npu1_vlink0" />
         <port action="translate" name="npu1_vlink1" type="npu"  dst_name="vlink1_1" dst_type="vdom-link"  description="former npu1_vlink1" />

		 <port action="configure" name="LAG"    lacp-mode="static" min-links="1" member="port1">
         <port action="configure" name="port10" alias="FPOC"  ip="192.168.0.4 255.255.255.0"  allowaccess="https ping ssh" description="FPOC OOB"/>
      </system_interfaces>

```


##### all_vdoms section tranforms

Applies transforms on all vdoms

- **firewall policy** : remove 'auto-asic-offload' statements on all policies
```xml
<firewall_policy auto-asic-offload="unset" /> 
```

- **vpn ipsec phase1-interface** : set 'psksecret' on all vdoms phase1s
```xml
<vpn_ipsec_phase1-interface psksecret="fortinet" />
```

- **firewall address group** :  limits the number of element in all firewall address groups. This may be needed if the source file is  from a unit  allowing more members in its table-size compared to the VM
```xml
<firewall_addrgrp max_size="255" />
```
 


##### vdoms section tranforms

Applies transforms on specific vdoms

So far, no transforms have been implemented on this section.



##### Example of a complete transform file

```xml
<?xml-stylesheet type="text/xsl" href="translate.xsl"?>
<transform>

   <options>
   </options>

   <global>
      <system_global admintimeout="475" />
      <system_admin password="unset" />
      <system_ha password="unset" group-id="1" monitor="unset" />
      <system_dns primary="8.8.8.8" source-ip="unset" />
      <system_central-management type="none" fmg-source-ip="unset" />
      <log_fortianalyzer_setting status="enable" source-ip="unset" />
      <system_ntp ntpsync="enable" source-ip="unset" server='"ntp.pool.org"'/>
      <system_netflow collector-ip="192.168.0.254" source-ip="unset" />
      <system_interfaces ignored_physical_action="translate_to_vdlink" tunnel_status="disable" >
         <port action="keep" name="port10"/>
         <port action="translate" name="port17"  dst_name="port4" description="former port17"  />
         <port action="translate" name="port19"  dst_name="port2" description="former port19"  />
         <port action="translate" name="port22"  dst_name="ADMIN" dst_type="loopback" description="former port22"/>
         <port action="translate" name="port23"  dst_name="port7" description="former port23"  />
         <port action="translate" name="port25"  dst_name="port5" description="former port25"  />
         <port action="translate" name="port26"  dst_name="port6" description="former port26"  />
         <port action="translate" name="port28"  dst_name="port3" description="former port28"  />
         <port action="translate" name="port29"  dst_name="port1" description="former port29"  />
         <port action="translate" name="port30"  dst_name="port8" description="former port30"  />
         <port action="translate" name="port31"  dst_name="port9" description="former port31"  />

         <port action="translate" name="npu0_vlink0" type="npu"  dst_name="vlink0_0" dst_type="vdom-link"  description="former npu0_vlink0" />
         <port action="translate" name="npu0_vlink1" type="npu"  dst_name="vlink0_1" dst_type="vdom-link"  description="former npu0_vlink1" />
         <port action="translate" name="npu1_vlink0" type="npu"  dst_name="vlink1_0" dst_type="vdom-link"  description="former npu1_vlink0" />
         <port action="translate" name="npu1_vlink1" type="npu"  dst_name="vlink1_1" dst_type="vdom-link"  description="former npu1_vlink1" />

         <port action="configure" name="TUNNEL1"     status="up" />
         <port action="configure" name="TUNNEL2"    status="up" />
         <port action="configure" name="port10" alias="FPOC"  ip="192.168.0.1 255.255.255.0"  allowaccess="https ping ssh" description="FPOC OOB"/>
      </system_interfaces>
   </global>

   <all_vdoms>
      <firewall_policy auto-asic-offload="unset" />
   </all_vdoms>

   <vdoms>
   </vdoms>

</transform>

```
