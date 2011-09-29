#!/usr/bin/perl

$ENV{https_proxy}=undef;
$ENV{http_proxy}=undef;

# $Header: /var/cvsroot/platform/hsync/tests/Attic/resty.pl,v 1.1.4.2 2010/02/09 17:54:42 abaumann Exp $
#
# Example use
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/capabilities
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/account
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 PUT /hsync/account text/xml acc.xml
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/logs
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/status
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/motd
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /hsync/users
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 POST /hsync/users text/ldif 100.ldif
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 PUT /hsync/users text/ldif 100.ldif
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 GET /logs/hosted_agg01o_100001_10.5.133.41_1_1252339674_1.gz
# resty.pl -s -h hss02o -u MD1234 -p Rdrd1234 DELETE /logs/hosted_agg01o_100001_10.5.133.41_1_1252339674_1.gz
# 
use strict;
use warnings;

use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use Getopt::Long;
use Digest::MD5 qw(md5_base64 md5_hex);
use Compress::Zlib;

my $user;
my $password;
my $host;
my $protocol = 'http://';
my $port;
my $ssl;
my $gzip;
my $ta;
my $content = '/tmp/hsyncout';
my $quiet;
my $etag;
my $realm = 'hsync';

GetOptions("user|u=s" => \$user,
           "password|p=s" => \$password,
           "host|h=s" => \$host,
           "content|c=s" => \$content,
           "gzip|g" => \$gzip,
           "ta" => \$ta,
           "ssl|s" => \$ssl,
           "realm|r" => \$realm,
           "quiet|q" => \$quiet,
           "etag|e=s" => \$etag,
           "port=s" => \$port,
);

if ($ssl) {
    $protocol = 'https://';
}

if (!defined $port) {
    $port= '80';
    if ($ssl) {
        $port = '443';
    }
    if ($ta) {
        $port = '8529';
    }
}

my $ua = LWP::UserAgent->new(timeout=>1800);
$ua->agent("resty/0.1 ");

if ($user) {
    $ua->credentials("$host:$port", $realm, $user, $password);
}

if ($port != 80) {
    $host = "$host:$port";
}

# Quick command line interface
sub subcommand {
    my ($expected, $code) = @_;
    if ($expected eq $ARGV[0]) {
        shift @ARGV;
        my $resp = $code->();
        print STDERR "Response Code:".$resp->code."\n" unless $quiet;
        print STDERR $resp->headers_as_string unless $quiet;
        print STDERR "\n" unless $quiet;
        print $resp->content unless $quiet;
        open my $outfh, '>', $content;
        print $outfh $resp->content;
        close $outfh;
        print STDERR "\n" unless $quiet;
        print STDERR "Length: ",length($resp->content),"\n" unless $quiet;
        print STDERR "MD5:    ", md5_base64($resp->content),"\n" unless $quiet;
        if (!$resp->is_success) {
            exit 1;
        }
        exit;
    }
}

sub slurp {
    my $filename = shift;

    # Slurp up the contents of the given filename
    open my $slurpy, '<', $filename or die "Cannot open $filename: $!";
    return do { local $/; <$slurpy> };
}

subcommand 'GET' => sub {
    # generic GET 
    my $resource = shift @ARGV;

#    $ua->max_redirect(0);
#	if ($resource =~ /\?/)
#	{
#		$resource .= '&'
#	}
#	else
#	{
#		$resource .= '?';
#	}
#	$resource .= 'xmlformat=1';
    my $resp = $ua->request(GET "$protocol$host$resource");

    return $resp;
};

subcommand 'DELETE' => sub {
    # generic DELETE 
    my $resource = shift @ARGV;

    my $resp = $ua->request(
        HTTP::Request->new(DELETE => "$protocol$host$resource")
        );

    return $resp;
};

subcommand 'POST' => sub {
    # generic POST 
    my $resource = shift @ARGV;
    my $type = shift @ARGV;
    my $filename = shift @ARGV;

    my $data = slurp($filename);

    my @headers = ('Content-Type' => $type);
    if ($etag) {
        push @headers, ('ETag' => $etag);
    }

    if ($gzip) {
        push @headers, 'Content-Encoding' => 'gzip';
        $data = Compress::Zlib::memGzip($data);
    }
    push @headers, 'Content-MD5' => md5_base64($data)."==";

    my $resp = $ua->request(POST "$protocol$host$resource", @headers, Content => $data);

    return $resp;
};

subcommand 'PUT' => sub {
    # generic PUT 
    my $resource = shift @ARGV;
    my $type = shift @ARGV;
    my $filename = shift @ARGV;

    my $data = slurp($filename);

    my @headers = ('Content-Type' => $type);
    if ($etag) {
        push @headers, ('ETag' => $etag);
    }

    if ($gzip) {
        push @headers, 'Content-Encoding' => 'gzip';
        $data = Compress::Zlib::memGzip($data);
    }
    push @headers, 'Content-MD5' => md5_base64($data)."==";

    my $resp = $ua->request(PUT "$protocol$host$resource", @headers, Content => $data);

    return $resp;
};

subcommand 'OPTIONS' => sub {
    # generic OPTIONS 
    my $resource = shift @ARGV;

    my $resp = $ua->request(
        HTTP::Request->new(OPTIONS => "$protocol$host$resource")
        );

    return $resp;
};

subcommand 'TRACE' => sub {
    # generic TRACE 
    my $resource = shift @ARGV;

    my $resp = $ua->request(
        HTTP::Request->new(TRACE => "$protocol$host$resource")
        );

    return $resp;
};

subcommand 'HEAD' => sub {
    # generic HEAD 
    my $resource = shift @ARGV;

    my $resp = $ua->request(HEAD "$protocol$host$resource");

    return $resp;
};

exit 0;
