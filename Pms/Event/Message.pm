#!/usr/bin/perl -w

package Pms::Event::Message;

use strict;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_channel}    = shift;
  $self->{m_message}    = shift;
  return $self;
}

sub connection{
  return $_[0]->{m_connection};
}

sub channel{
  return $_[0]->{m_channel};
}

sub message{
  return $_[0]->{m_message};
}
1;