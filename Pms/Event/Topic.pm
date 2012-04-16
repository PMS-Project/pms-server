#!/usr/bin/perl -w
package Pms::Event::Topic;

use strict;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_channel} = shift or die "Need the Channel Ref";
  $self->{m_topic}   = shift or die "Need the new Topic";
  return $self;
}

1;