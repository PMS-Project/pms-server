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
      $self->dataAvailable(@_);
      
      # push next request read
      warn "Pushing new Read Request";
      $self->{m_handle}->push_read(@start_request);
  }); 
  $self->{m_handle}->push_read(@start_request);
}

sub _onErrorCallback(){
  my $self = shift;
  
  return sub{
    warn "EEEET EEEET error $_[2]";
    $_[0]->destroy;
    $self->event('error');
  }
}
sub _onEofCallback(){
  my $self = shift;
  return sub {
    $_[0]->destroy; # destroy handle
    warn "Other Side disconnected.";
    $self->event('disconnect');
  }
}
sub dataAvailable(){
  my $self = shift;
  
  my ($hdl, $line) = @_;
  push(@{ $self->{m_buffer} },$line);
  $self->event('dataAvailable');
  
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