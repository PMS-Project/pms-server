#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Event
  
  Description:
    This is the base class for all events fired in the PMS application.
    
    A receiver can stop lots of the events, but if doing so you have to set a message containing the 
    reason with the <reject> member function. 
    
    Otherwise the <Pms::Application> object will not recognize that the event
    was rejected.
=cut

package Pms::Event::Event;
use strict;
use utf8;

=begin nd
  Constructor: new
    Initializes the Object
=cut
sub new{
  my $class = shift;
  my $self  = {};
  bless ($self,$class);
  
  $self->{m_rejected} = 0; #event wasn't rejected
  $self->{m_reason}   = undef; #string that should be set when event is rejected
  return $self;
}

=begin nd
  Function: reject
    Sets the reject flag to true, and assigns a error message
  
  Access:
    Public
    
  Parameters:
    reason - a string describing the reason of the reject
=cut
sub reject{
  my $self = shift;
  $self->{m_rejected} = 1;
  $self->{m_reason} = shift;
}

=begin nd
  Function: wasRejected
    Reads the rejected flag
  
  Access:
    Public
    
  Returns:
    0 - if the event was not rejected
    1 - if it was rejected
=cut
sub wasRejected{
  my $self = shift;
  return $self->{m_rejected};
}

=begin nd
  Function: reason
    Reads the reject reason
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    *undef* - if the events wasn't rejected
    *string* - containing the reason if it was
=cut
sub reason{
  my $self = shift;
  return $self->{m_reason};
}

1;