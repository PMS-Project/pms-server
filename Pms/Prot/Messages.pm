#!/usr/bin/perl -w 

=begin nd

  Package: Pms::Prot::Messages
  
  Description:
  
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub openWindowMessage {
  my $windowname = shift;
  $windowname = escapeString($windowname);
  return "/openwindow $windowname";
}

=begin nd
  Function: closeWindowMessage
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub closeWindowMessage {
  my $windowname = shift;
  $windowname = escapeString($windowname);
  return "/closewindow $windowname";
}

1;