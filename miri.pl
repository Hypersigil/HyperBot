#!/usr/bin/perl

#
# henri chain irc bot
# Modified from original source by 
# The HYPERSIGIL PROJECT
#
# formerly known as
# bubblez irc bot <3 by weekin2day
# based on dapper technology
# integrated with megahal
# 
# Modified 5/14/2015
# 


use Getopt::Std;

use POE;
use POE::Component::IRC;

use AI::MegaHAL;
#use Megahal;

use URI;
use HTML::Strip;
use WWW::Mechanize;
require URI::Find;
use HTML::LinkExtractor;
use LWP::Simple qw($ua head);

getopts('n:r:i:s:p:c:h');

my @responses = ("hey:text:test");

my $VERSION = '0.2a';
my $NAME = 'miri';

my $irc;
my $megahal;

my $brainsave = 1;
my $brainpath = './';

# irc stuff
my $nickname;
my $realname;
my $ircname;
my $server;
my $port;
my @channels;
my $channels;

# HTML reader
my $htmlstrip = HTML::Strip->new();
my $mech = WWW::Mechanize->new();
my $uri_finder = URI::Find->new(\&strip_html);
my $uri_recurse = URI::Find->new(\&recurse_html);
$mech->agent("Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36");
my $LX = new HTML::LinkExtractor();

$nickname = $opt_n;
$realname = $opt_r;
$ircname = $opt_i;
$server = $opt_s;
$port = $opt_p;
$channels = $opt_c;

#$nickname |= ($NAME . $$ );
$nickname |= ($NAME);
$realname |= $NAME . " " . $VERSION;
$ircname |= $NAME . " " . $VERSION;
$server |= "irc.hypersigil.org";
$port |= 6667;
$channels |= "#domus,#botdev";

@channels = split(/ /, $channels);

# megahal # AI::MegaHAL or Megahal
$megahal = AI::MegaHAL->new('Path' => $brainpath, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => $brainsave);

#irc
$irc = POE::Component::IRC->spawn();



# create poe session
POE::Session->create(
  inline_states => {
    _start     => \&bot_start,
    irc_001    => \&on_connect,
    irc_public => \&on_public,
    irc_disconnected => \&tryreconnect,
    irc_error        => \&tryreconnect,
    irc_socketerr    => \&tryreconnect,
    autoping         => \&doping,

  },
);

sub bot_start
{
  $irc->yield(register => "all");

  $irc->yield(
    connect => {
      Nick     => $nickname,
      Username => $realname,
      Ircname  => $ircname,
      Server   => $server,
      Port     => $port,
    }
  );
}

sub on_connect {  foreach (@channels) { $irc->yield('join', $_ ); } }

sub doping
{
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

    $kernel->post( bot => userhost => $config->{nickname} )unless $heap->{seen_traffic};
    $heap->{seen_traffic} = 0;
    $kernel->delay( autoping => 300 );
}

sub tryreconnect
{

    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

    $kernel->delay( autoping => undef );
    $kernel->delay( connect  => 15 );
}

sub on_public
{
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick    = (split /!/, $who)[0];
  # read any websites linked to
  # except by people who are... prone to abusing the bot
  if(lc($nick) ne "assbutt"){
	if($msg =~ /^\.read.*$/){  $uri_recurse->find(\$msg);$irc->yield(privmsg => $where->[0], "Done reading"); } else{ $uri_finder->find(\$msg); }
  }
#$uri_finder->find(\$msg);  
  
  
  my $channel = $where->[0];
  my $ts      = scalar localtime;
  
  my $hadnick = 0;
  
  if ($msg =~ /$nickname/) { $msg =~ s/$nickname //g; $msg =~ s/$nickname//g; $hadnick = 1; }

  if ($msg =~ /^\.loadresponses/) { @responses = (); open FD, "brain.txt"; while (<FD>) { chomp; push @responses, $_; } close FD; }
  if ($msg =~ /^\.saveresponses/) { open FD, ">brain.txt"; foreach my $r (@responses) { print FD "$r\n"; } close (FD); }
  
  if (my ($msgstring) = $msg =~ /^\.addresponse (.*)/) { push @responses, $msgstring; return; }

#  if ($msg =~ /.time/) { $irc->yield(privmsg =>$channel, `date`); return; }
#  if ($msg =~ /.date/) { $irc->yield(privmsg =>$channel, `date`); return; }
  
  my @output = ();
  my $doresponse = 0;

  # must be language
  
  $megahal->learn($msg);
  
  AI::MegaHAL::megahal_cleanup();
  
  if(rand(222) > 220) {$irc->yield(privmsg => $channel, lc($megahal->do_reply($msg)));}
  
  
  if ($hadnick)
  {
  foreach my $response (@responses)
  {
   # my ($m, $f, $v) = split(/:/, $response);
    if ($response =~ /(\S+)\:(\S+)\:(.*)/)
    {
      my $m=$1;
      my $f=$2;
      my $v=$3;
      
      if ($msg =~ /$m/) {
        if ($f eq "text")
        {
          push @output, $v;
          $doresponse=1;
        }
         if ($f eq "markov")
        {
          push @output, lc($megahal->do_reply($v));
          $doresponse=1;
        }
      }
    }
  }
  
  
  if ($doresponse)
  {
    $irc->yield(privmsg => $channel, $output[rand @output]);
    return;
  }
  
  # everything else has failed
  $irc->yield(privmsg => $channel, lc($megahal->do_reply($msg)));
  
  }
}

# takes a URL, retrieves page, strips out HTML, feeds content to MegaHAL
sub strip_html
{
  print STDOUT "Reading: ";
  my $url = $_[0];
  print STDOUT $url;
  print STDOUT "\n";
  #anti MRA-bot
  my $turl = lc($url);
  if($turl =~ /.*reddit.*/){ print STDOUT 'reddit fail\n\n'; return; };
  if($turl =~ /.*\.jpg$/){ print STDOUT 'jpg fail\n\n'; return; };
  if($turl =~ /.*\.jpeg$/){ print STDOUT 'jpeg fail\n\n'; return; };
  if($turl =~ /.*\.gif$/){ print STDOUT 'gif fail\n\n'; return; };
  if($turl =~ /.*\.png$/){ print STDOUT 'png fail\n\n'; return; };
  if($turl =~ /.*\.zip$/){ print STDOUT 'zip fail\n\n'; return; };
  if($turl =~ /.*\.pdf$/){ print STDOUT 'pdf fail\n\n'; return; };
  if($turl !~ /^http.*$/){ print STDOUT 'http fail\n\n'; return; };

  if($url ne ''){
	if(head($url)){
		print STDOUT "Got URL\n\n";
		$mech->get($url) or return;
		$megahal->learn($htmlstrip->parse($mech->content()));
		AI::MegaHAL::megahal_cleanup();
	}
  }
}

sub recurse_html
{
  print STDOUT "Recursive Reading: ";
  my $url = $_[0];
  print STDOUT "$url\n\n";
  #anti MRA-bot
  my $turl = lc($url);
  if($turl =~ /.*reddit.*/){ print STDOUT 'reddit fail\n\n'; return; };
  if($turl =~ /.*\.jpg$/){ print STDOUT 'jpg fail\n\n'; return; };
  if($turl =~ /.*\.jpeg$/){ print STDOUT 'jpeg fail\n\n'; return; };
  if($turl =~ /.*\.gif$/){ print STDOUT 'gif fail\n\n'; return; };
  if($turl =~ /.*\.png$/){ print STDOUT 'png fail\n\n'; return; };
  if($turl =~ /.*\.zip$/){ print STDOUT 'zip fail\n\n'; return; };
  if($turl =~ /.*\.pdf$/){ print STDOUT 'pdf fail\n\n'; return; };
  if($turl !~ /^http.*$/){ print STDOUT 'http fail\n\n'; return; };
  
  if(head($url)){
	print STDOUT "Got URL\n\n";
	$mech->get($url) or return;
	my $content = $mech->content();
	$LX->parse(\$content);

	for my $Link( @{ $LX->links } ) {
		my $tempurl = $$Link{href};
		print STDOUT "TempURL: $tempurl\n";
		if($tempurl =~ /^http.*/){
			print STDOUT "Found absolute\n\n";
			if(head($tempurl)){
				strip_html($tempurl);
			}
		}else{
			my $uri = URI->new_abs($tempurl,$url);
			print STDOUT "Found relative: ".$uri->canonical."\n\n";
			if(head($uri->canonical)){
				strip_html($uri->canonical);
			}
		}
	}
	$megahal->learn($htmlstrip->parse($content));
    AI::MegaHAL::megahal_cleanup();
  }
}

$poe_kernel->run();

exit 0;
