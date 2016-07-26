#
# This file is licensed under the Perl Artistic License 2.0 - http://www.opensource.org/licenses/artistic-license-2.0
# Development copy of this package available from: https://github.com/unixtools/perllib
# Cross contributions/development maintained in parallel with Missouri S&T/UMRPerl library
#

=begin
Begin-Doc
Name: Local::AuthSrv
Type: module
Description: password stashing utilities for perl scripts
Requires: authorization in privsys to actually stash password, and host set up to support it

Comment: Note - modules such as the oracle module typically default to using AuthSrv
behind the scenes, so you shouldn't usually have to use AuthSrv directly yourself.

Authsrv tools themselves must also be installed.

Example: 
use Local::OracleObject;
use Local::AuthSrv;

$db = new Local::OracleObject;

$userid = "myuserid";
$passwd = &AuthSrv_Fetch(
                user => $userid,
                instance => "oracle");

$db->SQL_OpenDatabase("srvp",
        user =&gt; $userid,
        passwd =&gt; $passwd) || $db->SQL_Error("open db");

End-Doc

=cut

package Local::AuthSrv;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Local::CurrentUser;
use Local::UsageLogger;
use IPC::Open3;
use Symbol 'gensym';

@ISA    = qw(Exporter);
@EXPORT = qw(
    AuthSrv_Fetch
    AuthSrv_FetchRaw
    AuthSrv_SetPathPrefix
);

BEGIN {
    &LogAPIUsage();
}

my $AUTHSRV_CACHE = {};

my $AUTHSRV_DECRYPT;
my $AUTHSRV_RAW_DECRYPT;

&AuthSrv_SetPathPrefix();

# Begin-Doc
# Name: AuthSrv_SetPathPrefix
# Type: function
# Description: sets prefix for authsrv executables to allow use when not installed in path
# Syntax: &AuthSrv_SetPathPrefix($prefix);
# Comments: Prefix should end in "/" (or other platform appropriate path separator)
# End-Doc
sub AuthSrv_SetPathPrefix {
    my $prefix = shift;
    if ( !defined($prefix) ) {
        $prefix = "";
    }

    $AUTHSRV_DECRYPT     = $prefix . "authsrv-decrypt";
    $AUTHSRV_RAW_DECRYPT = $prefix . "authsrv-raw-decrypt";
}

# Begin-Doc
# Name: AuthSrv_Fetch
# Type: function
# Description: fetch a stashed password
# Syntax: $pw = &AuthSrv_Fetch(instance => $instance, [user => $userid] );
# Comments: Returns stashed password. 'user' defaults to the
#       current userid on unix. If running as root, 'owner' can be specified.
# End-Doc
sub AuthSrv_Fetch {
    my (%opts) = @_;
    my $instance = $opts{instance} || return undef;
    my $user = $opts{user};
    if ( !defined($user) ) {
        $user = &Local_CurrentUser();
    }
    my $owner = $opts{owner} || &Local_CurrentUser();
    my $passwd;

    &LogAPIUsage();

    if ( !defined( $AUTHSRV_CACHE->{$owner}->{$user}->{$instance} ) ) {
        if ( $ENV{MOD_PERL} ) {
            open( my $in, "-|", $AUTHSRV_DECRYPT, $owner, $user, $instance );
            while ( defined( my $line = <$in> ) ) {
                chomp($line);
                $passwd .= $line;
            }
            close($in);
        }
        else {
            my ( $wtr, $rdr, $err );
            $wtr = gensym;
            $rdr = gensym;
            $err = gensym;
            my $childpid = open3( $wtr, $rdr, $err, $AUTHSRV_DECRYPT, $owner, $user, $instance );
            while ( defined( my $line = <$rdr> ) ) {
                chomp($line);
                $passwd .= $line;
            }
            waitpid( $childpid, 0 );
            close($rdr);
            close($wtr);
            close($err);
        }

        $AUTHSRV_CACHE->{$owner}->{$user}->{$instance} = $passwd;
    }

    return $AUTHSRV_CACHE->{$owner}->{$user}->{$instance};
}

# Begin-Doc
# Name: AuthSrv_FetchRaw
# Type: function
# Description: fetch a stashed password raw - not just a single line
# Syntax: $pw = &AuthSrv_FetchRaw(instance => $instance, [user => $userid] );
# Comments: Returns stashed content. 'user' defaults to the
#       current userid on unix. If running as root, 'owner' can be specified.
# End-Doc
sub AuthSrv_FetchRaw {
    my (%opts) = @_;
    my $instance = $opts{instance} || return undef;
    my $user = $opts{user};
    if ( !defined($user) ) {
        $user = &Local_CurrentUser();
    }
    my $owner = $opts{owner} || &Local_CurrentUser();
    my $passwd;

    if ( !defined( $AUTHSRV_CACHE->{$owner}->{$user}->{$instance} ) ) {
        if ( $ENV{MOD_PERL} ) {
            open( my $in, "-|", $AUTHSRV_RAW_DECRYPT, $owner, $user, $instance );
            while ( defined( my $line = <$in> ) ) {
                $passwd .= $line;
            }
            close($in);
        }
        else {
            my ( $wtr, $rdr, $err );
            $wtr = gensym;
            $rdr = gensym;
            $err = gensym;
            my $childpid = open3( $wtr, $rdr, $err, $AUTHSRV_RAW_DECRYPT, $owner, $user, $instance );
            while ( defined( my $line = <$rdr> ) ) {
                $passwd .= $line;
            }
            waitpid( $childpid, 0 );
            close($rdr);
            close($wtr);
            close($err);
        }

        $AUTHSRV_CACHE->{$owner}->{$user}->{$instance} = $passwd;
    }

    return $AUTHSRV_CACHE->{$owner}->{$user}->{$instance};
}

1;

