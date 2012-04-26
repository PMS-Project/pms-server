#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Message
  
  Description:
  
=cut

package Pms::Event::Message;

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
  $self->{m_message}    = shift;
  $self->{m_when}       = shift;
  return $self;
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
  Function: message
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub message{
  return $_[0]->{m_message};
}

=begin nd
  Function: when
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub when{
  return $_[0]->{m_when};
}
1;