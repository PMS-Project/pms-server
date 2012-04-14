#!/usr/bin/perl -w

package Pms::Modules::Database;

use strict;
use AnyEvent::DBI;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  warn "Motd Module created";
  return $self;
}

sub createHandle{
  my $self = shift or exit "Need Ref";
  return new AnyEvent::DBI('DBI:mysql:pms', 'pms', 'secret');
}

sub closeHandle{
  my $self = shift or exit "Need Ref";
  my $hdl  = shift or exit "Need Handle to close it";
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

sub initialize{
  my $self = shift;

}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;