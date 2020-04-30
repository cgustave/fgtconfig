# Defining package

package configstats ;

use Moose ;
extends('cfg_fgtconfig') ;

use strict ;
use warnings ;
use Data::Dumper ;
use lib "." ;

has 'stat'  => (isa => 'cfg_statistics', is => 'rw') ;

# ---

sub start {
 
   my $self = shift ;

   # Parsing configuration using cfg_dissector
   $self->parse() ;

   my @vdoms = $self->cfg->get_vdom_list();
   foreach my $vd (@vdoms) {
      warn "Processing vd=$vd" if $self->debug ;
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
1 ;
