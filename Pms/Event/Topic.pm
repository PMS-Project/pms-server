#!/usr/bin/perl -w
package Pms::Event::Topic;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift or die "Need Connection Ref";
  $self->{m_channel} = shift or die "Need the Channel Ref";
  $self->{m_topic}   = shift or die "Need the new Topic";
  return $self;
}

sub connection{
  return $_[0]->{m_connection};
}

sub channel{
  return $_[0]->{m_channel};
}

sub channelName{
  return $_[0]->{m_channel}->channelName();
}

sub topic{
  return $_[0]->{m_topic};
}

1;