#! /usr/bin/perl -w

# Author Cedric GUSTAVE

use strict ;
use Getopt::Long ;
use FileHandle ;
use Data::Dumper ;

use vars qw ($debug $file) ;
$| = 1 ;    # no buffer

my $fh_in             = new FileHandle ;
my $input             = 'STDIN' ;          # STDIN is the default input
my $line              = undef ;

my $line_count = 0 ;

# Control command line options
GetOptions(
   "debug"    => \$debug,
   "file=s"   => \$file,
) ;

# Initialisations

$debug  = 0        if not(defined($debug)) ;
if (defined($file)) {
   $input = 'fh_in' ;
   open(fh_in, '<', $file) or die "Cannot open file " . $file . " for reading\n" ;
   }

# Main loop
   
html_head() ;

LINE: while (<$input>) {

   $line_count++ ;
   $line = $_ ;
   print "[" . $line_count . "]" . $line . "\n" if $debug ;

   color_features(\$line) ;
   color_warnings(\$line) ;
   color_vdom(\$line) ;

   print $line ;

 }    # end while loop

html_foot();

close(fh_in) ;

# ---

sub color_features {

   my $aref_line = shift ;

   # 'no' in green
   $$aref_line =~ s/=no/=<span style=\"color:#11AF26\">no<\/span>/g; 

   # 'YES' in bold red
   $$aref_line =~ s/=YES/=<span style=\"color:#FF0000\"><b>YES<\/b><\/span>/g;  

   }

# ---

sub color_warnings {

   my $aref_line = shift ;

   my $color_flag = 0 ;

   ($$aref_line =~ s/warn:([^\|]*)/warn:<span style=\"color:#F2C600\"><b>$1<\/b><\/span>/ ) ;

   }

# ---

sub color_vdom {

   my $aref_line = shift ;

   if ($$aref_line =~ /^\|\svdom:\s\[\s/) {
      # This is a root vdom (with [ ]), color in red
            
      $$aref_line =~ s/vdom: \[ (\S*) \]/vdom: <span style=\"color:#FF0000"><b>\[ $1 \]<\/b><\/span>/
      }
     else {
      $$aref_line =~ s/vdom: (\S*)/vdom: <span style=\"color:#0000FF"><b>$1<\/b><\/span>/ ;
      }

   }

# ---

sub html_head {

print <<EOT;

<html>
<head>
<title>Configuration summary</title>
<style type="text/css">
<!--
body {
	display: inline;
	font-size: 12px;
	font-family: Terminal, "Courier New", Courier, monospace;
	white-space: pre;
}
-->
</style></head>

<body>

EOT

   }

# ---

sub html_foot {

print <<EOT;

</body>
</html>
EOT

}

