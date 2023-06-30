#! /usr/bin/perl -w
use strict ;
use warnings ;
use Getopt::Long ;

use cfg_fgtconfig ;
use cfg_configstats ;

use vars qw ($debug $config $routing $ipsec $splitconfig $color $html $stats $fullstats $ruledebug $nouuid $help) ;
use lib "." ;

GetOptions(
   "debug=s"       => \$debug,
   "ruledebug=s"   => \$ruledebug,
   "config=s"      => \$config,
   "routing"       => \$routing,
   "splitconfig=s" => \$splitconfig,
   "ipsec"         => \$ipsec,
   "color"         => \$color,
   "html"          => \$html,
   "stats"         => \$stats,
   "fullstats"     => \$fullstats,
   "nouuid"        => \$nouuid,
   "help"          => \$help
) ;


# Init
$help 	    = 0 if (not(defined($help))) ;
$debug      = 0 if (not(defined($debug))) ;
$stats      = defined($stats)     ? 1 : 0 ;
$fullstats  = defined($fullstats) ? 1 : 0 ;
$routing    = defined($routing)   ? 1 : 0 ;
$ipsec      = defined($ipsec)     ? 1 : 0 ;
$nouuid     = defined($nouuid)      ? 1 : 0 ;

if ($help) {
   print_help();
   exit ; 
   }

# Sanity
die "-config is required" if (not(defined($config))) ;

# If fullstat is asked, only do some statisctics counting per vdom

if ($fullstats) {

   my $cst = configstats->new(configfile => $config, debug_level => $debug) ;
   $cst->start() ;
   exit;
   }
 
my $fgtconfig = cfg_fgtconfig->new(configfile => $config, debug_level => $debug) ;

# Set display flags
$fgtconfig->dis->stats_flag('1')   if $stats ;
$fgtconfig->dis->routing_flag('1') if $routing ;
$fgtconfig->dis->ipsec_flag('1')   if $ipsec ;
$fgtconfig->dis->color_flag('1')   if $color ;
$fgtconfig->debug($debug)  if (defined($debug)) ;
$fgtconfig->ruledebug($ruledebug) if (defined($ruledebug)) ;

# load the config and start analysis
$fgtconfig->parse() ;
$fgtconfig->analyse() ;

#$fgtconfig->dump() ;
if (defined($splitconfig)) {

   # Default to current dir if not directory specified
   $splitconfig = "." if $splitconfig eq "" ;

   $fgtconfig->splitconfigdir($splitconfig) ;

   # Pre-split processing
   $fgtconfig->pre_split_processing(nouuid => $nouuid) ;

   # Creates one file per vdom and FGTconfig file
   $fgtconfig->splitconfig($config) ;
   }
else {
   $fgtconfig->color(1) if (defined($color)) ;
   $fgtconfig->dis->display() ;
   }

# ---

sub print_help {

print "\nusage: fgtconfig.pl -config <filename> [ Operation selection options ]\n";

print <<EOT;

Description: FortiGate configuration file summary, analysis, statistics and vdom-splitting tool

Input: FortiGate configuration file

Selection options:

[ Operation selection ]

   -fullstats                                                   : create report for each vdom objects for build comparison

   -splitconfig                                                 : split config in multiple vdom config archive with summary file
   -nouuid                                                      : split config option to remove all uuid keys (suggest. no)


Display options:
    -routing                                                    : display routing information section if relevant (suggest. yes)
    -ipsec                                                      : display ipsec information sections if relevant (suggest. yes)
    -stat                                                       : display some statistics (suggest. yes)
    -color                                                      : ascii colors
    -html                                                       : HTML output

    -debug                                                      : debug mode
    -ruledebug                                                  : rule parsing debug

EOT
   }
