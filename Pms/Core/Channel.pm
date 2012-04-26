#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Core::Channel
  
  Description:
  
=cut

package Pms::Core::Channel;
use strict;
use utf8;

use Pms::Prot::Messages;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new {
  my $class = shift;
  my $self  = {};
  bless($self,$class);
  
  $self->{m_parent} = shift or die "Channel needs a Parent";
  $self->{m_name}   = shift or die "Channel needs a Name";
  $self->{m_topic}  = "Welcome to the ".$self->{m_name}." Channel";
  $self->{m_connections} = {}; #all connections that joined the channel
  $self->{m_persistent}  = 0; #will the channel stay open after the last user has disconnected?
  
  return $self;
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
sub channelName {
  my $self = shift or die "Need Ref";
  return $self->{m_name};
}

=begin nd
  Function: _connectionForIdent
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _connectionForIdent{
  my $self = shift or die "Need Ref";
  my $key  = shift or die "Need Key";
  
  return $self->{m_connections}->{$key}->{"object"};
}

=begin nd
  Function: sendMessage
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub sendMessage{
  my $self = shift or die "Need Ref";
  my $who  = shift or die "Need a username";
  my $when = shift or die "Need a when";
  my $message = shift; #don't die here, might be a empty message
  
  
  my $keys = keys %{ $self->{m_connections} };
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}->{$k})){
       $self->_connectionForIdent($k)->postMessage(Pms::Prot::Messages::chatMessage($self->{m_name},$who,$when,$message));
    }
  } 
}

=begin nd
  Function: hasConnection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub hasConnection{
  my $self = shift or die "Need Ref";  
  my $connId = shift or die "Need ConnectionId";
  
  return (defined $self->{m_connections}->{$connId});
}

=begin nd
  Function: sendChannelMessage
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub sendChannelMessage{
  my $self = shift or die "Need Ref";  
  my $message = shift or die "Need Message";
  
  my $keys = keys %{ $self->{m_connections} };
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}->{$k})){
       $self->_connectionForIdent($k)->postMessage($message);
    }
  } 
}

=begin nd
  Function: addConnection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub addConnection {
  my $self = shift;
  my $connection = shift;
  
  #we are already in the channel
  if(defined $self->{m_connections}->{$connection->identifier()}){
    return;
  }
  
  my $stuff= { "eventguard" => $connection->connect("disconnect" => $self->_disconnectCallback()),
               "object"     => $connection
  };
  
  $self->{m_connections}->{$connection->identifier()} = $stuff;
  $connection->postMessage(Pms::Prot::Messages::openWindowMessage($self->{m_name}));
  $connection->postMessage(Pms::Prot::Messages::topicMessage($self->{m_name},$self->{m_topic}));
  $connection->postMessage(Pms::Prot::Messages::userListMessage($self));
  $self->sendChannelMessage(Pms::Prot::Messages::joinedMessage($connection,$self));
}

=begin nd
  Function: _disconnectCallback
    <function_description>
  
  Access:
    Private
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub _disconnectCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    $self->removeConnection($connection);
  }
}

=begin nd
  Function: removeConnection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub removeConnection {
  my $self = shift;
  my $connection = shift;
  
  my $ident = $connection->identifier();
  
  #we are not in the channel
  if(!defined $self->{m_connections}->{$ident}){
    return;
  }
  
  $connection->disconnect($self->{m_connections}->{$ident}->{"eventguard"});
  
  delete $self->{m_connections}->{$connection->identifier()};
  
  #TODO check if connection is still open
  $connection->postMessage(Pms::Prot::Messages::closeWindowMessage($self->{m_name}));
  $self->sendChannelMessage(Pms::Prot::Messages::leftMessage($connection,$self));
}

=begin nd
  Function: userList
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub userList {
  my $self = shift or die "Need Ref";
  my @list;
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}->{$k})){
       push(@list,$self->_connectionForIdent($k)->username());
    }    
  }
  
  return @list;
}

=begin nd
  Function: setTopic
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub setTopic{
  my $self = shift or die "Need Ref";
  my $topic = shift or die "Need New Topic";
  
  $self->{m_topic} = $topic;
  $self->sendChannelMessage(Pms::Prot::Messages::topicMessage($self->{m_name},$self->{m_topic}));
}

=begin nd
  Function: topic
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub topic {
  return $_[0]->{m_topic};
}
1;