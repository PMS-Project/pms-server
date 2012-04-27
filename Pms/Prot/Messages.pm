#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Prot::Messages
  
  Description:
    This module contains all messages that the server can send to the client.
    This makes it easy to change the message on one point in the application.
=cut

package Pms::Prot::Messages;

use strict;
use utf8;
use Pms::Application;
use Pms::Core::Connection;
use Pms::Core::Channel;

our $Debug = $ENV{'PMS_DEBUG'};

=begin nd
  Function: escapeString
    Escapes quotes and escape characters
    in a string and surrounds it with quotes.
  
  Access:
    Public
    
  Parameters:
    $string - the string that needs escaping
    
  Returns:
   string - the escaped and quoted string
=cut
sub escapeString {
  my $string = shift;
  
  $string =~ s/\\/\\\\/g; # Escape backslash
  $string =~ s/\"/\\"/g;
  
  warn "Escaped String: ".$string if($Debug);
  
  return '"'.$string.'"';
}

=begin nd
  Function: chatMessage
    Creates the text representation of a chatmessage
  
  Access:
    Public
    
  Parameters:
    $to - the receivers name
    $who - the senders name
    $when - the unix timetamp of the message
    $message - the message itself
    
  Returns:
    string - the message
=cut
sub chatMessage {
  my $to   = shift or die "Need a receiver";
  my $who  = shift or die "Need a username";
  my $when = shift or die "Need a when";
  my $message = shift; #don't die here might be a empty message or 0
  
  $to      = escapeString($to);
  $who     = escapeString($who);
  $message = escapeString($message);
  
  return "/message $to $who $when $message ";
}

=begin nd
  Function: joinedMessage
    Creates the text representation of a joined message
  
  Access:
    Public
    
  Parameters:
    $connection - the <Pms::Core::Connection> object that joined a channel
    $channel    - the <Pms::Core::Channel> object
    
  Returns:
    string - the message
=cut
sub joinedMessage {
  my $connection = shift;
  my $channel    = shift;
  
  my $chnl = escapeString($channel->channelName());
  my $usr  = escapeString($connection->username());
  
  my $msg = "/joined $chnl $usr";
  
  return $msg; 
}

=begin nd
  Function: leftMessage
    Creates the text representation of a left message
  
  Access:
    Public
    
  Parameters:
    $connection - the <Pms::Core::Connection> object that left a channel
    $channel    - the <Pms::Core::Channel> object
    
  Returns:
    string - the message
=cut
sub leftMessage {
  my $connection = shift;
  my $channel    = shift;
  
  my $chnl = escapeString($channel->channelName());
  my $usr  = escapeString($connection->username());
  my $msg = "/left $chnl $usr";
  
  return $msg;
}

=begin nd
  Function: nickChangeMessage
    Creates the text representation of a nickChangeMessage message
  
  Access:
    Public
    
  Parameters:
    $oldnick - the users old nickname
    $newnick - the users new nickname
    
  Returns:
    string - the message
=cut
sub nickChangeMessage {
  my $oldnick = shift;
  my $newnick = shift;
  
  $oldnick = escapeString($oldnick);
  $newnick = escapeString($newnick);
  
  my $msg = "/nickchange $oldnick $newnick";
}

=begin nd
  Function: userListMessage
    Creates the text representation of a userListMessage message
  
  Access:
    Public
    
  Parameters:
    $channel - the <Pms::Core::Channel> object we want to create the userlist from
    
  Returns:
    string - the message
=cut
sub userListMessage {
  my $channel    = shift;
  
  my @users = $channel->userList();
  my $chnl  = escapeString($channel->channelName());
  my $msg = "/userlist $chnl ";
  
  foreach my $curr (@users){
    $msg .= " ".escapeString($curr);
  }
  
  return $msg;
}

=begin nd
  Function: channelListMessage
    Creates the text representation of a channelListMessage message
  
  Access:
    Public
    
  Parameters:
    $server - the <Pms::Application> object
    
  Returns:
    string - the message
=cut
sub channelListMessage {
  my $server = shift;
  
  
  my @channels = $server->channels();
  my $msg = "/channellist ";
  
  foreach my $curr (@channels){
    $msg .= " ".escapeString($curr);
  }
  
  return $msg;
}

=begin nd
  Function: serverMessage
    Creates the text representation of a serverMessage message
  
  Access:
    Public
    
  Parameters:
    $toChannel - the receiver channel name
    $message   - the message to be sent
    
  Returns:
    string - the message
=cut
sub serverMessage  {
  my $toChannel = shift;
  my $message   = shift;
  
  $toChannel = escapeString($toChannel);
  $message   = escapeString($message);
  
  return "/serverMessage $toChannel $message";
}

=begin nd
  Function: topicMessage
    Creates the text representation of a topicMessage message
  
  Access:
    Public
    
  Parameters:
    $channel - the channel name
    $topic   - the new topic of the channel
    
  Returns:
    string - the message
=cut
sub topicMessage {
  my $channel = shift;
  my $topic   = shift;
  
  $channel = escapeString($channel);
  $topic   = escapeString($topic);
  
  return "/channeltopic $channel $topic";
}

=begin nd
  Function: openWindowMessage
    Creates the text representation of a openWindowMessage message
  
  Access:
    Public
    
  Parameters:
    $windowname - the id of the window, the client application should create
    
  Returns:
    string - the message
=cut
sub openWindowMessage {
  my $windowname = shift;
  $windowname = escapeString($windowname);
  return "/openwindow $windowname";
}

=begin nd
  Function: closeWindowMessage
    Creates the text representation of a closeWindowMessage message
  
  Access:
    Public
    
  Parameters:
    $windowname - the id of the window, the client application should delete
    
  Returns:
    string - the message
=cut
sub closeWindowMessage {
  my $windowname = shift;
  $windowname = escapeString($windowname);
  return "/closewindow $windowname";
}

1;