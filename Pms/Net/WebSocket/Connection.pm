#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Net::WebSocket::Connection
  
  Description:
    This is the implementation of the Websocket based connection-object
    
  
=cut

package Pms::Net::WebSocket::Connection;

use Pms::Core::Connection;
use Pms::Net::WebSocket::Backend;
use strict;
use utf8;

our $Debug = $ENV{'PMS_DEBUG'};
our @ISA = qw(Pms::Core::Connection);
our %PmsEvents = ('handshake_done' => 1);

=begin nd
  Signal: handshake_done
  
  Description:
    is emitted when the websocket handshake is finished
    
=cut

=begin nd
  Constructor: new
    Initializes the Object
=cut
sub new{
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  bless($self,$class);
  
  $self->{m_handle} = undef;
  $self->_initializeHandle();
  
  return $self;         
}

=begin nd
  Function: _initializeHandle
    Initializes the internal AnyEvent Handle
  
  Access:
    Private
=cut
sub _initializeHandle{
  my $self = shift;
  
  $self->{m_handle} =   new AnyEvent::Handle(
                            fh       => $self->{m_fh},
                            on_error => $self->_onErrorCallback(),
                            on_eof   => $self->_onEofCallback());
  
  #initialize the websocket handshake
  warn "Starting Handshake" if($Debug);
  $self->{m_handle}->push_read(websock_handshake => $self->_onHandshakeFinished());
}

=begin nd
  Function: _onHandshakeFinished
    Callback function that is automatically called when the 
    websocket handshake is done.
  
  Access:
    Private
=cut
sub _onHandshakeFinished{
  my $self = shift or die "Need Ref";
  return sub{
    if($Debug){
      warn "PMS-Core> ". "Handshake is done";
    }
    
    #start the automatic reading
    my @start_request; @start_request = (websock_pms => sub{
      my ($handle) = @_;
      $self->_readyRead(@_);
      
      # push next request read
      warn "Pushing new Read Request" if($Debug);
      $handle->push_read(@start_request);
    }); 
    $self->{m_handle}->push_read(@start_request);
    $self->emitSignal('handshake_done');
  }
}

=begin nd
  Function: _onErrorCallback
    Creates a callback that handles socket errors
  
  Access:
    Private
=cut
sub _onErrorCallback{
  my $self = shift or die "Need Ref";
  
  return sub{
    warn "PMS-Core> ". "Websocket Error Closing Connection: $_[2]";
    $self->emitSignal('error');
    
    $self->emitSignal('disconnect');
    $_[0]->destroy;
  }
}

=begin nd
  Function: _onEofCallback
    creates a callback that handles the closing of the socket
  
  Access:
    Private
=cut
sub _onEofCallback{
  my $self = shift or die "Need Ref";
  return sub {
    $_[0]->destroy; # destroy handle
    warn "PMS-Core> ". "Other Side disconnected.";
    $self->emitSignal('disconnect');
  }
}

=begin nd
  Function: _readyRead
    This function is called, when there 
    is new data available. It emits 
    the dataAvailable signal.
  
  Access:
    Private
    
  Parameters:
    $hdl  - the socket handle
    $line - the chunk of data that was received
=cut
sub _readyRead{
  my $self = shift or die "Need Ref";
  
  my ($hdl, $line) = @_;
  warn "PMS-Core> ". "IN>>>: ".$line;
  push(@{ $self->{m_buffer} },$line);
  
  $self->emitSignal('dataAvailable');
  
}

=begin nd
  Function: postMessage
  
  Reimplemented:
  See <Pms::Core::Connection::postMessage>
=cut
sub postMessage{
  my $self = shift or die "Need Ref";
  my $message = shift;
  warn "PMS-Core> ". "<<<OUT: ".$message;
  $self->{m_handle}->push_write(websock_pms => $message);
}

=begin nd
  Function: sendMessage
  
  Reimplemented:
  See <Pms::Core::Connection::sendMessage>
=cut
sub sendMessage{
  my $self = shift or die "Need Ref";
  my $message = shift;
  warn "PMS-Core> ". "<<<OUT: ".$message;
  my $frame  = Protocol::WebSocket::Frame->new(Pms::Prot::WebSocket::Protocol::_netstringify( $message ));
  syswrite($self->{m_handle}->fh,$frame);
}

=begin nd
  Function: close
  
  Reimplemented:
  See <Pms::Core::Connection::close>
=cut
sub close{
  my $self = shift or die "Need Ref";
  $self->{m_handle}->push_shutdown();
}

=begin nd
  Function: identifier
  
  Reimplemented:
  See <Pms::Core::Connection::identifier>
=cut
sub identifier{
  my $self = shift or die "We need a Reference";
  
  #for now we just use the filehandle
  return $self->{m_handle}->fh;
}

1;