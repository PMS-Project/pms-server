#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Event
  
  Description:
  
=cut

package Pms::Event::Event;
use strict;
use utf8;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub reject{
  my $self = shift;
  $self->{m_rejected} = 1;
  $self->{m_reason} = shift;
}

=begin nd
  Function: wasRejected
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub wasRejected{
  my $self = shift;
  return $self->{m_rejected};
}

=begin nd
  Function: reason
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub reason{
  my $self = shift;
  return $self->{m_reason};
}

1;