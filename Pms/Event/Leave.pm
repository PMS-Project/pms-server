#!/usr/bin/perl -w

package Pms::Event::Leave;

use strict;
use utf8;
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

sub channel{
  return $_[0]->{m_channel};
}
# 
sub channelName{
  return $_[0]->{m_channel}->channelName();
}

sub connection{
  return $_[0]->{m_connection};
}
1;