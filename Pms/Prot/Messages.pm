#!/usr/bin/perl -w 

package Pms::Prot::Messages;

use strict;
use Pms::Application;
use Pms::Core::Connection;
use Pms::Core::Channel;

sub chatMessage {
  my $to   = shift or die "Need a receiver";
  my $who  = shift or die "Need a username";
  my $when = shift or die "Need a when";
  my $message = shift or die "Need Message";
  
  return "/message '$to' '$who' '$when' '$message' ";
}

sub joinedMessage {
  my $connection = shift;
  my $channel    = shift;
  
  my $msg = "/joined '$channel->channelName()' '$connection->username()'";
  
  return $msg; 
}

sub leftMessage {
  my $connection = shift;
  my $channel    = shift;
  
  my $msg = "/left '$channel->channelName()' '$connection->username()'";
  
  return $msg;
}

sub userListMessage {
  my $connection = shift;
  my $channel    = shift;
  
  my @users = $channel->userList();
  my $msg = "/userlist '$channel->channelName()' ";
  
  foreach my $curr (@users){
    $msg .= " '$curr'";
  }
  
  return $msg;
}

sub channelListMessage {
  my $server = shift;
  
  
  my @channels = $server->channels();
  my $msg = "/channellist ";
  
  foreach my $curr (@channels){
    $msg .= " '$curr' ";
  }
  
  return $msg;
}

sub serverMessage  {
  my $toChannel = shift;
  my $message   = shift;
  
  return "/serverMessage '$toChannel' '$message'";
}

sub openWindowMessage {
  my $windowname = shift;
  return "/openwindow '$windowname'";
}

sub closeWindowMessage {
  my $windowname = shift;
  return "/closewindow '$windowname'";
}

1;