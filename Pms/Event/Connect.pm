#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Connect
  
  Description:
  
=cut

package Pms::Event::Connect;

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
  $self->{m_ip} = undef;
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
  my $self = shift;
  return $self->{m_connection};
}
1;