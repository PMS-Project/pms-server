#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Command
  
  Description:
  
=cut

package Pms::Event::Command;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
 
  $self->{m_name} = shift;
  $self->{m_args} = shift;
  
  return $self;
}

1;