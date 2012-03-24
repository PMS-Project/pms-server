#!/usr/bin/perl -w 
package Pms::Prot::WebSocket::Connection;

use Pms::Core::Connection;
use Pms::Prot::WebSocket::Protocol;
use strict;

our @ISA = qw(Pms::Core::Connection);

sub new(){
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  bless($self,$class);
  
  $self->_initializeHandle();
  
  return $self;         
}


=begin nd
  Function: _initializeHandle
  
  Initializes the internal Handle and Event Handling of the Object
  
  Access:
  Private
  
  Returns:
  nothing
  
=cut
sub _initializeHandle(){
  my $self = shift;
  
  $self->{m_handle} =   new AnyEvent::Handle(
                            fh       => $self->{m_fh},
                            on_error => $self->_onErrorCallback(),
                            on_eof   => $self->_onEofCallback());
  
  my @start_request; @start_request = (websock_pms => sub{
      my ($handle) = @_;
      $self->_readyRead(@_);
      
      # push next request read
      warn "Pushing new Read Request";
      $handle->push_read(@start_request);
  }); 
  $self->{m_handle}->push_read(@start_request);
}

sub _onErrorCallback(){
  my $self = shift;
  
  return sub{
    warn "EEEET EEEET error $_[2]";
    $self->emitSignal('error');
    
    $_[0]->destroy;
    $self->emitSignal('disconnect');
  }
}
sub _onEofCallback(){
  my $self = shift;
  return sub {
    $_[0]->destroy; # destroy handle
    warn "Other Side disconnected.";
    $self->emitSignal('disconnect');
  }
}
sub _readyRead(){
  my $self = shift;
  
  my ($hdl, $line) = @_;
  warn "Data: ".$line;
  push(@{ $self->{m_buffer} },$line);
  
  $self->emitSignal('dataAvailable');
  
}

sub postMessage(){
  my $self = shift or die "Need Ref";
  my $message = shift;
  
  $self->{m_handle}->push_write(websock_pms => $message);
}

sub sendMessage(){
  my $self = shift or die "Need Ref";
  my $message = shift;
  
  my $frame  = Protocol::WebSocket::Frame->new(Pms::Prot::WebSocket::Protocol::_netstringify( $message ));
  syswrite($self->{m_handle}->fh,$frame);
}

sub close(){
  my $self = shift or die "Need Ref";
  $self->{m_handle}->push_shutdown();
}

1;