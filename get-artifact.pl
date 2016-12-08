#!/usr/bin/env perl

use REST::Client;
use JSON;
use Data::Dumper;
use Digest::MD5::File qw( file_md5_hex );
use v5.10.0; # for 'say'
use strict;
use warnings;


# # # # # # # # # # # # #
#
# S U B R O U T I N E S
#
# # # # # # # # # # # # #
sub usage {
    return <<EOS
USAGE:
$0 <jenkins-artifact-url>

EOS

}

# # # # # # # # # # # # #
#
# M A I N
#
# # # # # # # # # # # # #

MAIN:
{
    my $url = shift or die usage();

    my @url_parts = split( '/', $url );

    my $file = $url_parts[-1];

    # say "filename: $file";

    if ( -e $file ) {

        # File exists, see if hash matches URL using Jenkins fingerprint.

        # get hash of file on disk
        my $local_hash = file_md5_hex( $file ) or die "[$url] Failed to get md5 of $file: $!";

        # say "local hash: $local_hash";

        # figure out jenkins job url.
        my $job_url;
        for ( my $i = 0; $i <= $#url_parts; $i++ ) {
            if ( $url_parts[$i] eq 'artifact' ) {
                $job_url = join( '/', @url_parts[0 .. $i - 1] );
            }
        }
        die "[$url]: Failed to determine jenkins job url" unless defined $job_url;
        # say "job_url: $job_url";

        my $client = REST::Client->new();
        my $fingerprint_request_uri = "$job_url/api/json?depth=2&tree=fingerprint[fileName,hash]{0,}";
        $client->GET( $fingerprint_request_uri );
        die "[$url] GET $fingerprint_request_uri resulted in responseCode: $client->responseCode()" if ( $client->responseCode() != 200 );

        my $resp = decode_json( $client->responseContent() );
        # say Dumper( $resp );
        # $VAR1 = {
        # 	'fingerprint' => [
        # 	...
        # 		{
        # 			'fileName' => 'ma-service.war',
        # 			'hash' => 'a53e62ce2d117eed7fca821a3b636e53'
        # 		},
        # 	...
        # 	]
        # };
        my ( $hash ) = map { $_->{hash} } grep { $_->{fileName} eq $file } @{ $resp->{fingerprint} };
        # say "jenkins hash: $hash";

        if ( defined( $hash ) && ( $local_hash eq $hash ) ) {
            say "[$url] hashs match, skipping download";
            exit 0;
        }

        # hash mismatch, delete old file
        unlink( $file ) or die "[$url] could not unlink $file: $!";
    }

    exec( qq| wget -nv $url | ) or die "[$url] couldn't exec wget: $!";
}
