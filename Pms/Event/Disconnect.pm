#!/usr/bin/perl -w
package Pms::Event::Disconnect;
use strict;
use Pms::Event::Event;


our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = undef;
  return $self;
}

sub connection{
  return $_[0]->{m_connection};
}
1;