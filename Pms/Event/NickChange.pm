#!/usr/bin/perl -w

package Pms::Event::NickChange;

use strict;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_oldname}    = shift;
  $self->{m_newname}    = shift;
  return $self;
}

sub newName{
  my $self = shift or die "Need Ref";
  return $self->{m_newname};
}

sub oldName{
  my $self = shift or die "Need Ref";
  return $self->{m_oldname};
}

sub connection{
  my $self = shift or die "Need Ref";
  return $self->{m_connection};
}
1;