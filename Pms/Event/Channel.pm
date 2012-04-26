#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Channel
  
  Description:
  
=cut

package Pms::Event::Channel;

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
  
  $self->{m_connection}  = shift;
  $self->{m_channel} = shift;
  $self->{m_closing} = 0; #set this to true to indicate the channel is closing
  
  return $self;
}

=begin nd
  Function: setClosing
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub setClosing{
  $_[0]->{m_closing} = $_[1];
}

=begin nd
  Function: isClosing
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub isClosing{
  return $_[0]->{m_closing};
}

=begin nd
  Function: channelName
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub channelName{
  return $_[0]->{m_channel};
}

=begin nd
  Function: connection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub connection{
  return $_[0]->{m_connection};
}

1;