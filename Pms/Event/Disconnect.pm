#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Disconnect
  
  Description:
  
=cut

package Pms::Event::Disconnect;
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
  
  $self->{m_connection} = shift or die "Need Connection";
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
1;