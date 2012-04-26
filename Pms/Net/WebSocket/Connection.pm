#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Net::WebSocket::Connection
  
  Description:
  
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
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
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
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
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
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _onHandshakeFinished{
  my $self = shift or die "Need Ref";
  return sub{
    if($Debug){
      warn "Handshake is done";
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
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _onErrorCallback{
  my $self = shift or die "Need Ref";
  
  return sub{
    warn "Websocket Error Closing Connection: $_[2]";
    $self->emitSignal('error');
    
    $self->emitSignal('disconnect');
    $_[0]->destroy;
  }
}

=begin nd
  Function: _onEofCallback
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _onEofCallback{
  my $self = shift or die "Need Ref";
  return sub {
    $_[0]->destroy; # destroy handle
    warn "Other Side disconnected.";
    $self->emitSignal('disconnect');
  }
}

=begin nd
  Function: _readyRead
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _readyRead{
  my $self = shift or die "Need Ref";
  
  my ($hdl, $line) = @_;
  warn "Data: ".$line;
  push(@{ $self->{m_buffer} },$line);
  
  $self->emitSignal('dataAvailable');
  
}

=begin nd
  Function: postMessage
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub postMessage{
  my $self = shift or die "Need Ref";
  my $message = shift;
  
  $self->{m_handle}->push_write(websock_pms => $message);
}

=begin nd
  Function: sendMessage
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub sendMessage{
  my $self = shift or die "Need Ref";
  my $message = shift;
  
  my $frame  = Protocol::WebSocket::Frame->new(Pms::Prot::WebSocket::Protocol::_netstringify( $message ));
  syswrite($self->{m_handle}->fh,$frame);
}

=begin nd
  Function: close
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub close{
  my $self = shift or die "Need Ref";
  $self->{m_handle}->push_shutdown();
}

=begin nd
  Function: identifier
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub identifier{
  my $self = shift or die "We need a Reference";
  
  #for now we just use the filehandle
  return $self->{m_handle}->fh;
}

1;