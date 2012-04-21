#!/usr/bin/perl -w
package Pms::Event::Channel;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection}  = shift;
  $self->{m_channel} = shift;
  $self->{m_closing} = 0; #set this to true to indicate the channel is closing
  
  return $self;
}

sub setClosing{
  $_[0]->{m_closing} = $_[1];
}

sub isClosing{
  return $_[0]->{m_closing};
}

sub channelName{
  return $_[0]->{m_channel};
}

sub connection{
  return $_[0]->{m_connection};
}

1;