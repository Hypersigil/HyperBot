#!/usr/bin/perl

#
# Version 0.2.1a
# henri chain irc bot
# Modified from original source by 
# The HYPERSIGIL PROJECT
#
# formerly known as
# bubblez irc bot <3 by weekin2day
# based on dapper technology
# integrated with megahal
# 
# Modified 5/17/2015
# 

#use strict; # strict variables and references, doesnt compile
#use warnings; # Uncomment to see warnings

use Getopt::Std;

use POE; # requires POE, apt-get install libpoe-perl
use POE::Component::IRC; # IRC POE

use AI::MegaHAL; # requires AI-MegaHAL perl module
#use Megahal; # tried to use normal Megahal install to no avail

print("Used modules initialized.\n");

getopts('n:r:i:s:p:c:h');

my @responses = ("hey:text:test");

my $VERSION = '0.2a';
my $NAME = 'henri';

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

$nickname = $opt_n;
$realname = $opt_r;
$ircname = $opt_i;
$server = $opt_s;
$port = $opt_p;
$channels = $opt_c;

#$nickname |= ($NAME . $$ ); # orignal line, name + random number
$nickname |= ($NAME);
$realname |= $NAME . " " . $VERSION;
$ircname |= $NAME . " " . $VERSION;
$server |= "irc.hypersigil.org";
$port |= 6667;
$channels |= "#botdev";

@channels = split(/ /, $channels);

# megahal # AI::MegaHAL or Megahal
$megahal = AI::MegaHAL->new('Path' => $brainpath, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => $brainsave);

print("Config Complete.\n");

#irc
print("Spawn IRC Component.\n");
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
	print("Bot started.\n");
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

sub on_connect 
{  
	print("Connection established.\n");
	foreach (@channels) 
	{ 
		$irc->yield('join', $_ ); 
		print "Joining channel: $_ \n";
	} 
}

sub doping
{
	print("DoPing received?\n");
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

	$kernel->post( bot => userhost => $config->{nickname} )unless $heap->{seen_traffic};
	$heap->{seen_traffic} = 0;
	$kernel->delay( autoping => 200 );
}

sub tryreconnect
{
	print("Try Reconnect?\n");
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

	$kernel->delay( autoping => undef );
	$kernel->delay( connect  => 15 );
}

sub on_public
{
	print("On Public triggered.\n");
	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
	my $nick    = (split /!/, $who)[0];
	
	my $channel = $where->[0];
	my $ts      = scalar localtime;
  
	my $hadnick = 0;
  
	if ($msg =~ /$nickname/) { $msg =~ s/$nickname //g; $msg =~ s/$nickname//g; $hadnick = 1; print("Heard nickname?\n");}

	if ($msg =~ /^\.loadresponses/) { @responses = (); open FD, "brain.txt"; while (<FD>) { chomp; push @responses, $_; } close FD; }
	if ($msg =~ /^\.saveresponses/) { open FD, ">brain.txt"; foreach my $r (@responses) { print FD "$r\n"; } close (FD); }
  
	if (my ($msgstring) = $msg =~ /^\.addresponse (.*)/) { push @responses, $msgstring; return; }

	#if ($msg =~ /.time/) { $irc->yield(privmsg =>$channel, `date`); return; }
	#if ($msg =~ /.date/) { $irc->yield(privmsg =>$channel, `date`); return; }
  
	my @output = ();
	my $doresponse = 0;

	# must be language
  
	$megahal->learn($msg);
	print "String learned by MegaHAL.\n";
  
	AI::MegaHAL::megahal_cleanup();
  
	if ($hadnick)
	{
		print("Heard nickname, responding!\n");
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
				push @output, $megahal->do_reply($v);
				$doresponse=1;
			}
		}
	}
}
  
if ($doresponse)
{
	print "Force Response.\n";
	$irc->yield(privmsg => $channel, $output[rand @output]);
	return;
}
  
# everything else has failed
print("All else failed.\n");
$irc->yield(privmsg => $channel, $megahal->do_reply($msg));
  
}
}
print("Running POE Kernel.\n");
$poe_kernel->run();

exit 0;