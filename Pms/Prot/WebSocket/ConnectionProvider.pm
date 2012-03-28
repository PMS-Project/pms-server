#!/usr/bin/perl -w 

package Pms::Prot::WebSocket::ConnectionProvider;

use strict;
use Pms::Core::ConnectionProvider;
use Pms::Prot::WebSocket::Connection;

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
  
  #connections that wait for the handshake
  $self->{m_pendingConnections} = {};
  
  return $self;         
}

sub _newConnectionCallback(){
  my $self = shift;

  return sub{
    my ($fh, $host, $port) = @_;
    
    my $connection = Pms::Prot::WebSocket::Connection->new($fh,$host,$port);
    
    my $hash = {
      connectionObject => $connection,
      eventGuard       => $connection->connect('handshake_done' => $self->_handshakeDoneCallback())
    };
    
    $self->{m_pendingConnections}->{$connection->identifier()} = $hash;
    
  }
}

sub _handshakeDoneCallback(){
  my $self = shift;
  
  return sub{
    my $connection = shift;
    my $ident = $connection->identifier();
    if(!defined $self->{m_pendingConnections}->{$ident}){
      die "Connection not known in pending Connections";
    }
   
    $connection->disconnect($self->{m_pendingConnections}->{$ident}->{eventGuard});
    delete $self->{m_pendingConnections}->{$ident};
    
    push(@{ $self->{m_connectionQueue} },$connection);
    $self->emitSignal('connectionAvailable');
    
  }
}

1;