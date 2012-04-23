#!/usr/bin/perl -w

package Pms::Modules::Motd;

use strict;
use utf8;
use Pms::Event::Connect;
use Pms::Prot::Messages;
use Data::Dumper;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  if(!defined $self->{m_config}){
    die "Need a line to print";
  }
  
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
      
      $eventType->connection()->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_config}));
    }
  );
}

sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;