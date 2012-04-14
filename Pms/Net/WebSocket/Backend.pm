#!/usr/bin/perl -w 

=begin nd
  Package: Pms::Net::WebSocket::Backend
  
  To use the code in the Package it just has to be imported. It will automatically
  register read and write functions to AnyEvent::Handle so we don't have to care
  about how the Handles internally read the Packages from the Socket.
  That makes it easy to plug in another Protocol easily.
=cut

package Pms::Net::WebSocket::Backend;

use strict;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use AnyEvent::Handle;
use Pms::Prot::Netstring;

our $Debug = $ENV{'PMS_DEBUG'};



AnyEvent::Handle::register_read_type websock_handshake => sub{
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

    $hdl->{pmsReadError} = undef; #remove last error

    if (!$hs->is_done) {
      #this will append to its internal buffer until handshake is done
      $hs->parse($chunk);

      if ($hs->is_done) {
        #warn "Handshake done";
        $hdl->push_write($hs->to_string);
        $cb->($hdl,undef);
        return 1;
      }
      return undef;
    }
  }
};

AnyEvent::Handle::register_read_type websock_pms => sub{
  my $hdl = shift;
  my $cb  = shift;
  
  sub{
    
    my $chunk = $hdl->{rbuf};
    if(!defined $chunk){
      return;
    }
    
    #warn "Message";
    
    $hdl->{rbuf} = undef;
    my $hs    = $hdl->{pmsWebSockSrv};
    my $frame = $hdl->{pmsWebSockFrame};
    if(!defined $hs || !$hs->is_done){
         $hdl->{pmsReadError} = "Handshake is not done";
         $_[0]->_error (Errno::EBADMSG);
         return;
    }
    
    $hdl->{pmsReadError} = undef; #remove last error
    
    #If we enter this Path the handshake is done and we can read the Frame
    $frame->append($chunk);
    my $has_read_data = 0;
    while (my $message = $frame->next) {
      $hdl->{pmsReadBuf} .= $message;
      $has_read_data = 1;
    }
    
    if(!$has_read_data){
      return;
    }
    
    #warn "Frames found";
    
    my $value = Pms::Prot::Netstring::parse($hdl,\$hdl->{pmsReadBuf});
    if(defined $value){
      #warn "Callback";
      $cb->($hdl,$value);
      return 1; #tell the AnyEvent::Handle code that we finally have read data
    }else{
      if(defined $Pms::Prot::Netstring::lastError){
         warn "Error in Websocket Read ".$Pms::Prot::Netstring::lastError;
         $_[0]->_error (Errno::EBADMSG);
      }
    }
  }
};

AnyEvent::Handle::register_write_type websock_pms => sub {
  if($Debug){
    warn "Writing Websocket";
  }
  my $handle = shift;
  my $frame  = Protocol::WebSocket::Frame->new(Pms::Prot::Netstring::serialize(shift));
  $handle->push_write($frame->to_bytes);
};

1;