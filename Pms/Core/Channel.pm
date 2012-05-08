#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Core::Channel
  
  Description:
  Represents a Channel in the Server
  
=cut

package Pms::Core::Channel;
use strict;
use utf8;

use Pms::Prot::Messages;

=begin nd
  Constructor: new
    Initializes the Object
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
    Returns the channel name
  
  Access:
    Public
    
  Returns:
    string - the channel name
=cut
sub channelName {
  my $self = shift or die "Need Ref";
  return $self->{m_name};
}

=begin nd
  Function: _connectionForIdent
    Searches for a connection identifier, and returns
    the connection if it can find one
  
  Access:
    Private
    
  Parameters:
    $ident - the Connection identifier
    
  Returns:
    <Pms::Core::Connection> - The Connection Object or
    undef - if nothing was found
=cut
sub _connectionForIdent{
  my $self = shift or die "Need Ref";
  my $key  = shift or die "Need Key";
  
  return $self->{m_connections}->{$key}->{"object"};
}

=begin nd
  Function: sendMessage
    sends a Message to all users in the channel
  
  Access:
    Public
    
  Parameters:
    $who - The user 
    $when - The time of the message
    $message - The message itself
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
    Checks if a given connection id is in the channel
  
  Access:
    Public
    
  Parameters:
    $connId - The connectionId we are looking for
    
  Returns:
    1 - for true
    0 - for false
=cut
sub hasConnection{
  my $self = shift or die "Need Ref";  
  my $connId = shift or die "Need ConnectionId";
  
  return (defined $self->{m_connections}->{$connId});
}

=begin nd
  Function: sendChannelMessage
    Sends any Message to all users in the channel
  
  Access:
    Public
    
  Parameters:
    $message - the message to be sent (already in protocol format)
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
    Adds a <Pms::Core::Connection> object to the channel
  
  Access:
    Public
    
  Parameters:
    $connection the <Pms::Core::Connection> object to be added
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
  Creates the callback that is executed, when a client disconnects from the server
  
  Access:
    Private
    
  Returns:
    callback - the callback function
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
    Removes a connection the channel
  
  Access:
    Public
    
  Parameters:
    $connection - The <Pms::Core::Connection> object to be removed
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
    Creates a userlist of all Users in the channel
  
  Access:
    Public
    
  Returns:
    array - all usernames in the channel
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
    Changes the topic of the channel and sends a topic-change event to the clients
  
  Access:
    Public
    
  Parameters:
    $topic - the new topic
=cut
sub setTopic{
  my $self = shift or die "Need Ref";
  my $topic = shift or die "Need New Topic";
  
  $self->{m_topic} = $topic;
  $self->sendChannelMessage(Pms::Prot::Messages::topicMessage($self->{m_name},$self->{m_topic}));
}

=begin nd
  Function: topic
    Reads the current channel topic
  
  Access:
    Public
    
  Returns:
    string - the current channel topic
=cut
sub topic {
  return $_[0]->{m_topic};
}
1;