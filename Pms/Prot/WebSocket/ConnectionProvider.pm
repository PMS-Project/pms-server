#!/usr/bin/perl -w 

package Pms::Prot::WebSocket::ConnectionProvider;

use strict;
use Pms::Core::ConnectionProvider;
use Pms::Prot::WebSocket::Connection;
use Pms::Event::Connect;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

our @ISA = qw(Pms::Core::ConnectionProvider);

sub new(){
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  bless($self,$class);
  
  #TODO make possible to change from the settings file
  $self->{m_listeningSocket} =  tcp_server(undef, 8888, $self->_newConnectionCallback());
  
  return $self;         
}

sub _newConnectionCallback(){
  my $self = shift;

  return sub{
    my ($fh, $host, $port) = @_;
    
    my $connection = Pms::Prot::WebSocket::Connection->new($fh,$host,$port);

    warn "Incoming Connection";
    my $event = Pms::Event::Connect->new();
    $self->{m_parent}->{m_events}->event('client_connected' => $event);
    if($event->wasRejected()){
      warn "Event was rejected, reason: ".$event->reason();
      $connection->sendMessage($event->reason());
      close($fh);
      return;
    }
    
    warn "Connection got through";
    
    push(@{ $self->{m_connectionQueue} },$connection);
    $self->event('connectionAvailable');
  }
}

1;