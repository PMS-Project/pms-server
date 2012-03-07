#!/usr/bin/perl -w 
package Pms::Core::Connection;

use Object::Event;
use AnyEvent::Handle;
use strict;

our @ISA = qw(Object::Event);

our @PmsEvents = qw(dataAvailable disconnect error);

sub new (){
  my $class = shift;
  my $self  = {};
  bless($self,$class);
  
  $self->{m_fh}     = shift or die "Connection needs a Socket Handle";
  $self->{m_host}   = shift or die "Connection needs a Host Value";
  $self->{m_port}   = shift or die "Connection needs a Port Value";
  $self->{m_user}   = undef;
  $self->{m_buffer} = (); #internal read buffer
  $self->{m_handle} = undef;
  
  return $self;
}


=begin nd
 Function: identifier
 
 Returns: 
 a unique identifier for the connection Object.
 Can be used in Hashes.
 
=cut
sub identifier(){
  my $self = shift or die "We need a Reference";
  
  #for now we just use the filehandle
  return $self->{m_handle}->fh;
}

sub messagesAvailable(){
  my $self = shift or die "Need Ref";
  
  #return the number of messages
  my $count = @{ $self->{m_buffer} };
  return $count;
}

sub nextMessage(){
  my $self = shift or die "Need Ref";
  
  my $message = shift(@{ $self->{m_buffer} });
  return $message;
}

sub sendMessage(){
  die "This function is virtual, it needs to be implemented in the subclass";
}

sub postMessage(){
  die "This function is virtual, it needs to be implemented in the subclass";
}


