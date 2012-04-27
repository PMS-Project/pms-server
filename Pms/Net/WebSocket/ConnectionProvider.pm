#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Net::WebSocket::ConnectionProvider
  
  Description:
  
=cut

package Pms::Net::WebSocket::ConnectionProvider;

use strict;
use utf8; 
use Pms::Core::ConnectionProvider;
use Pms::Net::WebSocket::Connection;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

our @ISA = qw(Pms::Core::ConnectionProvider);

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    parent - the <Pms::Application> object
    config - the module config hash   
=cut
sub new{
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  bless($self,$class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;

  my $port = 8888;
  if(defined $self->{m_config} && defined $self->{m_config}->{port}){
    $port = $self->{m_config}->{port};
  }
  
  $self->{m_listeningSocket} =  tcp_server(undef, $port, $self->_newConnectionCallback());
  
  #connections that wait for the handshake
  $self->{m_pendingConnections} = {};
  
  return $self;         
}

=begin nd
  Function: _newConnectionCallback
    Creates a callback, that handles every incoming connection and enqueues it
    in the internal connection list.
  
  Access:
    Private
=cut
sub _newConnectionCallback{
  my $self = shift;

  return sub{
    my ($fh, $host, $port) = @_;
    
    my $connection = Pms::Net::WebSocket::Connection->new($fh,$host,$port);
    
    my $hash = {
      connectionObject => $connection,
      eventGuard       => $connection->connect(
        'handshake_done' => $self->_handshakeDoneCallback(),
        'disconnect'     => $self->_disconnectWhileHandshake()                                      
      )
    };
    
    $self->{m_pendingConnections}->{$connection->identifier()} = $hash;
    
  }
}

=begin nd
  Function: _handshakeDoneCallback
    Creates a callback that is called when a pending handle has finished its
    handshake. Only handles that finished the websocket handshake will be shown
    as available.
  
  Access:
    Private
=cut
sub _handshakeDoneCallback{
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

=begin nd
  Function: _disconnectWhileHandshake
    Creates a callback that is executed when a handle 
    disconnects in between the handshake, this will cleanup the 
    ressources
  Access:
    Private
=cut
sub _disconnectWhileHandshake{
 my $self = shift;
  
  return sub{
    my $connection = shift;
    my $ident = $connection->identifier();
    
    warn "Connection closed while Handshake still in progress";
    
    if(!defined $self->{m_pendingConnections}->{$ident}){
      die "Connection not known in pending Connections";
    }
   
    $connection->disconnect($self->{m_pendingConnections}->{$ident}->{eventGuard});
    delete $self->{m_pendingConnections}->{$ident};
  }  
}

1;