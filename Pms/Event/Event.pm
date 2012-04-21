#!/usr/bin/perl -w

package Pms::Event::Event;
use strict;
use utf8;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self,$class);
  
  $self->{m_rejected} = 0; #event wasn't rejected
  $self->{m_reason}   = undef; #string that should be set when event is rejected
  return $self;
}

sub reject{
  my $self = shift;
  $self->{m_rejected} = 1;
  $self->{m_reason} = shift;
}

sub wasRejected{
  my $self = shift;
  return $self->{m_rejected};
}

sub reason{
  my $self = shift;
  return $self->{m_reason};
}

1;