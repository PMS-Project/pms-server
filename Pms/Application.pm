#!/usr/bin/perl -w

package Pms::Application;

use strict;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Object::Event;
use Pms::Core::ConnectEvent;

our @PmsEvents = ( 'client_connected'       # Event is fired if a new Client connects to the server
                 , 'client_disconnected'    # Any client closed the connection
                 , 'new_message'            # Any client sent a message to any channel
                 , 'user_entered_channel'   # A connected user entered a channel
                 , 'user_left_channel'      # A connected user left a channel
                 , 'channel_created'        # A new channel was created on the server 
                 , 'channel_closed');       # A channel was deleted/closed
  
sub new (){
  my $class = shift;
  my $self  = {};

  bless ($self, $class);

  $self->{m_eventLoop}     = AnyEvent->condvar();

  #TODO check if we can read the name of the signal in the callback
  $self->{m_signalHandler} = AnyEvent->signal (
                              signal => "TERM", 
                              cb => $self->_termSignalCallback() );

  $self->{m_events}   = Object::Event->new();
  $self->{m_timers}   = ();
  $self->{m_clients}  = ();
  $self->{m_modules}  = ();

  $self->{m_listeningSocket} = 	tcp_server(undef, 8888, $self->_newConnectionCallback());

  return $self;
}

sub execute (){
  my $self = shift;
   
  $self->loadModules();
  $self->{m_eventLoop} ->recv; #eventloop
}

sub loadModules (){
  my $self = shift;
  
  opendir (my $dir, 'Pms/modules') or die $!;
  while( my $file = readdir($dir) ){
    next if (!($file =~ m/.*\.pm$/));
    print "Trying to load Module: ".$file,"\n";
    
    my $modname = "Pms/modules/".$file;
    my $basename = $file;
    $basename =~ s{\.pm$}{}g;   
    require $modname;
    
    my $module = $basename->new($self);
    push(@{$self->{m_modules}},$module); 
  }
  closedir $dir;  
}

sub connectEvent (){
  my $self = shift;
  return $self->{m_events}->reg_cb(@_);
}

sub disconnectEvent (){
  my $self = shift;
  my $guard = shift;

  $self->{m_events}->unreg_cb($guard);
}

sub _termSignalCallback(){
  my $self = shift;
  return sub {
    warn "Received TERM Signal\n";
    $PmsApplication::self{m_eventLoop}->send; #Exit from Eventloop
  }  
}

sub _newConnectionCallback(){
  my $self = shift;

  return sub{
    my ($fh, $host, $port) = @_;

    warn "Incoming Connection";
    my $event = Pms::Core::ConnectEvent->new();
    $self->{m_events}->event('client_connected' => $event);
    if($event->wasRejected()){
      warn "Event was rejected, reason: ".$event->reason();
      syswrite($fh,$event->reason());
      close($fh);
      return;
    }
    
    #TODO check host and port
    $self->{m_clients}{$fh} = new AnyEvent::Handle(
                              fh     => $fh,
                              on_error => sub {
                                warn "error $_[2]";
                                $_[0]->destroy;
                              },
                              on_eof => sub {
                                $_[0]->destroy; # destroy handle
                                warn "Other Side disconnected.";
                              });
                    
    my @start_request; @start_request = (line => sub {
        my ($hdl, $line) = @_;

        warn "Something happend";
        warn ($line);

        warn "Clients Connected".keys(%{$self->{m_clients}});

        
        foreach my $k (keys %{$self->{m_clients}}){
          warn "Key: ".$k;
          if($k ne $hdl->fh()){
              if(defined($self->{m_clients}{$k})){
                  $self->{m_clients}{$k}->push_write($line);
              }
          }
        }

        # push next request read, possibly from a nested callback
        warn "Pushing new Read Request";
        $hdl->push_read(@start_request);
    }); 
    $self->{m_clients}{$fh}->push_read(@start_request);
  }
}

1;