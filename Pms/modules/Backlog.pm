#!/usr/bin/perl -w

package Backlog;

use strict;

sub new (){
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_eventGuard} = ();
  $self->initialize();
  
  warn "Backlog Module created";
  return $self;
}

sub DESTROY(){
  my $self = shift;
  $self->shutdown();
}

sub initialize (){
  my $self = shift;
  warn "Registering Events";  
  $self->{m_eventGuard} = 
  $self->{m_parent}->connectEvent( 
  client_connected => sub{
    my $eventChain = shift;
    my $eventType  = shift;
    warn "Hello from Module";
    
    #$eventType->reject("Connection Rejected because you suck\n");
    #$eventChain->stop_event;
    
  }
  , client_connected => sub 
  { 
    warn "We received a new Connection"; 
    
  });
}

sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnectEvent($self->{m_eventGuard});
}

1;