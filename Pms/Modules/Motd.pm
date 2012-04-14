#!/usr/bin/perl -w

package Pms::Modules::Motd;

use strict;
use Pms::Event::Connect;

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

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

sub initialize{
  my $self = shift;
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    client_connect_success => sub{
      my $eventChain = shift;
      my $eventType  = shift;
      
      $eventType->connection()->postMessage("/serverMessage \"default\" \"----- Welcome to the concrete Muhlaserver -----\"");
      $eventType->connection()->postMessage("/serverMessage \"default\" \"           Please Respect our Rules\"");
      $eventType->connection()->postMessage("/serverMessage \"default\" \"    If not, the bad Muhlaman will catch you\"");
      $eventType->connection()->postMessage("/serverMessage \"default\" \"            And Muhla your head off\"");
    }
  );
}

sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;