#!/usr/bin/perl -w

package Pms::Modules::Backlog;

use strict;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  warn "Backlog Module created";
  return $self;
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

sub initialize{
  my $self = shift;
  warn "Registering Events";  
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    client_connect_request => sub{
      my $eventChain = shift;
      my $eventType  = shift;
      warn "Hello from Module";
      
      #$eventType->reject("Connection Rejected because you suck\n");
      #$eventChain->stop_event;
      
    }, client_connect_success => sub 
    { 
      warn "We received a new Connection";
    }
  );
}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;