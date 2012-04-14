#!/usr/bin/perl -w
package Pms::Event::Channel;

use strict;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_channel} = undef;
  $self->{m_closing} = 0; #set this to true to indicate the channel is closing
  return $self;
}

sub setClosing{
  $_[0]->{m_closing} = $_[1];
}

sub isClosing{
  return $_[0]->{m_closing};
}

sub channel{
  return $_[0]->{m_channel};
}

1;