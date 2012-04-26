#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Join
  
  Description:
  
=cut

package Pms::Event::Join;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_channel}    = shift;
  return $self;
}

=begin nd
  Function: channel
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub channel{
  return $_[0]->{m_channel};
}

=begin nd
  Function: channelName
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub channelName{
  return $_[0]->{m_channel}->channelName();
}

=begin nd
  Function: connection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub connection{
  return $_[0]->{m_connection};
}
1;