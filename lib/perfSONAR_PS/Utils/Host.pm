package perfSONAR_PS::Utils::Host;

=head1 NAME

perfSONAR_PS::Utils::Host - A module that extract the usable IP addresses
from a host.  

=head1 DESCRIPTION

This module provides a function that parses the ouput of the /sbin/ifconfig
command on *nix systems looking for ip addresses.

=head1 DETAILS

TBD

=head1 API

TBD

=cut

use base 'Exporter';

use strict;
use warnings;

our @EXPORT_OK = ('get_ips');

sub get_ips {
    my @ret_interfaces = ();

    my $IFCONFIG;
    open( $IFCONFIG, "-|", "/sbin/ifconfig" ) or return;
    my $is_eth = 0;
    while (<$IFCONFIG>) {
        if (/Link encap:([^ ]+)/) {
            if ( lc($1) eq "ethernet" ) {
                $is_eth = 1;
            }
            else {
                $is_eth = 0;
            }
        }

        next if ( not $is_eth );

        if (/inet addr:(\d+\.\d+\.\d+\.\d+)/) {
            push @ret_interfaces, $1;
        }
        elsif (/inet6 addr: (\d*:[^\/ ]*)(\/\d+)? +Scope:Global/) {
            push @ret_interfaces, $1;
        }
    }
    close($IFCONFIG);

    return @ret_interfaces;
}

1;

__END__

=head1 SEE ALSO

L<Exporter>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown <aaron@internet2.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2008, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4