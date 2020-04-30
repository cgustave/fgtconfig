#!/usr/bin/perl -w
use strict ;
use warnings ;
use Getopt::Long ;

use cfg_translate ;

use vars qw ($debug $config $transform $help) ;
use lib "." ;

GetOptions(
   "debug=s"     => \$debug,
   "config=s"    => \$config,
   "transform=s" => \$transform,
   "help"        => \$help,
) ;

$help = 0 if (not(defined($help))) ;

if ($help) {
   print_help() ;
   exit ;
   }

# Sanity
die "-config is required" if (not(defined($config))) ;
die "-transform is required" if (not(defined($transform))) ;

# Init
$debug = 0 if (not(defined($debug))) ;

my $trsl = cfg_translate->new(configfile => $config, transform => $transform, debug_level => $debug) ;
$trsl->start() ;

# ---

sub print_help {
   print <<EOT;

   usage : translate.pl -config <FGT_config> -transform <transform.xml> [-debug <level> ]

EOT
   }

