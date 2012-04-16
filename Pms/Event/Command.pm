#!/usr/bin/perl -w
package Pms::Event::Command;

use strict;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
 
  $self->{m_name} = shift;
  $self->{m_args} = shift;
  
  return $self;
}

1;