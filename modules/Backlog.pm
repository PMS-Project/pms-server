#!/usr/bin/perl -w

package Backlog;

use strict;

sub new (){
  my $class = shift;
  my $self  = {};

  $self->{m_parent} = shift;
  $self->{m_eventGuard} = ();
  
  warn "Backlog Module created";

  bless ($self, $class);
}

sub intialize (){
  my $self = shift;
    
  $self->{m_eventGuard} = 
  $self->{m_parent}->connectEvent( client_connected => sub{ warn "Hello from Module"; }
                              , new_message      => sub { warn "We received a new Message"; });
}

sub shutdown (){
  my $self = shift;
  $self->{m_parent}->disconnectEvent($self->{m_eventGuard});
}

1;