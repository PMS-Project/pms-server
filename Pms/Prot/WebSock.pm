#!/usr/bin/perl -w 

package Pms::Prot::WebSock;

use strict;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use AnyEvent::Handle;

AnyEvent::Handle::register_read_type websock_pms => sub{
  my $hdl = shift;
  my $cb  = shift;
  
  sub{
    
    my $chunk = $hdl->{rbuf};
    if(!defined $chunk){
      return;
    }
    
    $hdl->{rbuf} = undef;
    my $hs    = $hdl->{pmsWebSockSrv};
    my $frame = $hdl->{pmsWebSockFrame};
    if(!defined $hs){
      $hdl->{pmsWebSockSrv} = $hs = Protocol::WebSocket::Handshake::Server->new();
      $hdl->{pmsWebSockFrame} = $frame = Protocol::WebSocket::Frame->new();
    }
  
    if (!$hs->is_done) {
      #this will append to its internal buffer until handshake is done
      $hs->parse($chunk);
    
      if ($hs->is_done) {
        $hdl->push_write($hs->to_string);
      }
      return;
    }
    
    #If we enter this Path the handshake is done and we can read the Frame
    $frame->append($chunk);
    my $has_read_data = 0;
    while (my $message = $frame->next) {
      $cb->($hdl,$message);
      $has_read_data = 1;
    }
    return $has_read_data;
  }
};

AnyEvent::Handle::register_write_type websock_pms => sub {
  warn "Writing Websocket";
  my $handle = shift;
  my $frame  = Protocol::WebSocket::Frame->new(shift);
  $handle->push_write($frame->to_bytes);
};

1;