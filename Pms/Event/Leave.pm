#!/usr/bin/perl -w

package Pms::Event::Leave;

use strict;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_channel}    = shift;
  return $self;
}
1;