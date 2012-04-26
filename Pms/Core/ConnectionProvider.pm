#!/usr/bin/perl -w

=begin nd

  Package: Pms::Core::ConnectionProvider
  
  Description:
  
=cut

package Pms::Core::ConnectionProvider;

use strict;
use utf8;
use Pms::Core::Object;

our @ISA = qw(Pms::Core::Object);
our %PmsEvents = ('connectionAvailable' => 1);

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  
  bless($self,$class);
  
  $self->{m_parent} = shift or die "needs a reference to parent";
  $self->{m_connectionQueue} = [];
  
  return $self;
  
}

=begin nd
  Function: nextConnection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub nextConnection{
  my $self = shift or die "No Ref";
  
  my $connection = shift(@{ $self->{m_connectionQueue} });
  return $connection;
}

=begin nd
  Function: connectionAvailable
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub connectionsAvailable{
  my $self = shift or die "No Ref";
  my $count = @{ $self->{m_connectionQueue} };
  return $count;
}

1;