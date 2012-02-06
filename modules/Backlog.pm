#!/usr/bin/perl -w

package Backlog;

use strict;

sub new (){
  my $class = shift;
  my $self  = {};

  $self->{m_parent} = shift;
  $self->{m_eventGuard} = ();

  bless ($self, $class);
}

sub intialize (){
  $self->{m_parent}->connect( client_connected => sub{ warn "Hello from Module"; } );
}

sub shutdown (){
  
}

1;