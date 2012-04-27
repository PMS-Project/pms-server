#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Motd
  
  Description:
    The Motd module is a example implementation of 
    a module. It just sends a welcome message to every new 
    user who connects to the server.
=cut

package Pms::Modules::Motd;

use strict;
use utf8;
use Pms::Event::Connect;
use Pms::Prot::Messages;
use Data::Dumper;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    parent - the <Pms::Application> object
    config - the module config hash
=cut
sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  if(!defined $self->{m_config}){
    die "Need a line to print";
  }
  
  warn "Motd Module created";
  return $self;
}

=begin nd
  Destructor: DESTROY
    destoys the Object and cleans up its ressources
    
  Parameters:
=cut
sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

=begin nd
  Function: initialize
    Called by the constructor, initializes the module
    and connects to all the required signals and events
  
  Access:
    Public
=cut
sub initialize{
  my $self = shift;
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    client_connect_success => sub{
      my $eventChain = shift;
      my $eventType  = shift;
      
      $eventType->connection()->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_config}));
    }
  );
}

=begin nd
  Function: shutdown
    Cleans up the modules resources.
    Is automatically called by the destructor
  
  Access:
    Public
=cut
sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

1;