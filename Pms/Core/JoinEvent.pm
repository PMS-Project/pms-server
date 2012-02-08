#!/usr/bin/perl -w
package Pms::Core::JoinEvent;

use strict;
use Pms::Core::Event;

our @ISA = ("Pms::Core::Event");

sub new(){
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = undef;
  $self->{m_channel}    = undef;
  return $self;
}
1;