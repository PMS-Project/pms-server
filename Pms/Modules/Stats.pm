#!/usr/bin/perl -w

package Pms::Modules::Stats;

use strict;
use utf8;
use AnyEvent::DBI;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  warn "Stats Module created";
  return $self;
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

sub initialize{
  my $self = shift;
  
  #$self->{m_parent}->connect( 
  #  client_connect_success => $self->_clientConnectedCallback(),
   # client_disconnect_success => $self->_disconnectCallback(),
   # message_send_success  => $self->_messageSendSuccessCallback(),
   # join_channel_success  => $self->_joinChannelSuccessCallback(),
   # leave_channel_success => $self->_leaveChannelSuccessCallback()
  #);    
}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;