package perfSONAR_PS::NPToolkit::DataService::Host;
use fields qw(LOGGER config_file admin_info_conf config);

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy :levels);
use POSIX;
use Data::Dumper;
use Sys::MemInfo qw(totalmem);
use Params::Validate qw(:all);

use perfSONAR_PS::NPToolkit::Config::Version;
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

use perfSONAR_PS::Utils::Host qw( discover_primary_address );
use perfSONAR_PS::Utils::LookupService qw( is_host_registered );

use perfSONAR_PS::NPToolkit::Services::ServicesMap qw(get_service_object);

use perfSONAR_PS::Web::Sidebar qw(set_sidebar_vars);

use perfSONAR_PS::NPToolkit::Config::BWCTL;
use perfSONAR_PS::NPToolkit::Config::OWAMP;

use Config::General;
use Time::HiRes qw(gettimeofday tv_interval);

sub new {
    my ( $class, @params ) = @_;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );
    my $parameters = validate(
        @params,
        {
            config_file => 1
        }
    );
    $self->{config_file} = $parameters->{config_file};
    my $config = Config::General->new( -ConfigFile => $self->{config_file} );
    $self->{config} = { $config->getall() };
    my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
    $administrative_info_conf->init( { administrative_info_file => $self->{config}->{administrative_info_file} } );
    $self->{admin_info_conf} = $administrative_info_conf;

    return $self;
}

sub get_information {
    my $self = shift;
    my $administrative_info_conf = $self->{admin_info_conf};

    my $info = {
        administrator => {
            name => $administrative_info_conf->get_administrator_name(),
            email => $administrative_info_conf->get_administrator_email(),
        },
        location => {
            city => $administrative_info_conf->get_city(),
            state => $administrative_info_conf->get_state(),
            country => $administrative_info_conf->get_country(),
            zipcode => $administrative_info_conf->get_zipcode(),
            latitude => $administrative_info_conf->get_latitude(),
            longitude => $administrative_info_conf->get_longitude(),
        }
    };
    return $info;
    
}

sub get_status {
    my $self = shift;
    # get addresses, mtu, ntp status, globally registered, toolkit version, toolkit rpm version
    # external address
    # total RAM
    
    my $status = {};


    my $version_conf = perfSONAR_PS::NPToolkit::Config::Version->new();
    $version_conf->init();

    $status->{toolkit_version} = $version_conf->get_version();


    # Getting the external addresses seems to be by far the slowest thing here (~0.9 sec)

    my %conf = %{$self->{config}};
    my $external_addresses = discover_primary_address({
            interface => $conf{primary_interface},
            allow_rfc1918 => $conf{allow_internal_addresses},
            disable_ipv4_reverse_lookup => $conf{disable_ipv4_reverse_lookup},
            disable_ipv6_reverse_lookup => $conf{disable_ipv6_reverse_lookup},
        });
    my $external_address;
    my $external_address_mtu;
    my $external_address_ipv4;
    my $external_address_ipv6;
    my $is_registered = 0;
    if ($external_addresses) {
        $external_address = $external_addresses->{primary_address};
        $external_address_mtu = $external_addresses->{primary_iface_mtu};
        $external_address_ipv4 = $external_addresses->{primary_ipv4};
        $external_address_ipv6 = $external_addresses->{primary_ipv6};
        $status->{external_address} = {
            address => $external_address,
            ipv4_address => $external_address_ipv4,
            ipv6_address => $external_address_ipv6,
            mtu => $external_address_mtu
        };
    }

    if ($external_address) {
        eval {
            # Make sure it returns in a reasonable amount of time if reverse DNS
            # lookups are failing for some reason.
            local $SIG{ALRM} = sub { die "alarm" };
            alarm(2);
            $is_registered = is_host_registered($external_address);
            alarm(0);
        };
    }

    $status->{globally_registered} = $is_registered;

    my $toolkit_rpm_version;

    # Make use of the fact that the config daemon is contained in the Toolkit RPM.
    my $config_daemon = get_service_object("config_daemon");
    if ($config_daemon) {
        $toolkit_rpm_version = $config_daemon->package_version;
    }
    $status->{toolkit_rpm_version} = $toolkit_rpm_version;

    my $ntp = get_service_object("ntp");
    $status->{ntp}->{synchronized} = $ntp->is_synced();

    $status->{host_memory} = int((&totalmem()/(1024*1024*1024) + .5)); #round to nearest GB

    return $status;

}

sub get_services {
    my $self = shift;

    my @bwctl_test_ports = ();
    my $bwctld_cfg = perfSONAR_PS::NPToolkit::Config::BWCTL->new();
    $bwctld_cfg->init();

    foreach my $port_type ("peer", "iperf", "iperf3", "nuttcp", "thrulay", "owamp", "test") {
        my ($status, $res) = $bwctld_cfg->get_port_range(port_type => $port_type);
        if ($status == 0) {
            push @bwctl_test_ports, {
                type => $port_type,
                min_port => $res->{min_port},
                max_port => $res->{max_port},
            };
        }

        if ($port_type eq "test" and $status != 0) {
            # BWCTL's test range defaults to 5001-5900
            push @bwctl_test_ports, {
                type => $port_type,
                min_port => 5001,
                max_port => 5900,
            };
        }
        elsif ($port_type eq "peer" and $status != 0) {
            # BWCTL's peer range defaults to "any port"
            push @bwctl_test_ports, {
                type => $port_type,
                min_port => 1,
                max_port => 65535,
            };
        }
    }

    my @owamp_test_ports = ();
    my $owampd_cfg = perfSONAR_PS::NPToolkit::Config::OWAMP->new();
    $owampd_cfg->init();

    my ($status, $res) = $owampd_cfg->get_test_port_range();
    if ($status == 0) {
        push @owamp_test_ports, {
            type => "test",
            min_port => $res->{min_port},
            max_port => $res->{max_port},
        };
    }
    else {
        # OWAMP's peer range defaults to "any port"
        push @owamp_test_ports, {
            type => "test",
            min_port => 1,
            max_port => 65535,
        };
    }

    my $owamp = get_service_object("owamp");
    my $bwctl = get_service_object("bwctl");
    my $npad = get_service_object("npad");
    my $ndt = get_service_object("ndt");
    my $regular_testing = get_service_object("regular_testing");


    my %services = ();

    foreach my $service_name ( "owamp", "bwctl", "npad", "ndt", "regular_testing", "esmond", "iperf3" ) {
        my $service = get_service_object($service_name);

        $self->{LOGGER}->debug("Checking ".$service_name);
        my $is_running = $service->check_running();

        my @addr_list;
        if ($service->can("get_addresses")) {
            @addr_list = @{$service->get_addresses()};
            if (@addr_list > 0) {
                my @del_indexes = reverse(grep { $addr_list[$_] =~ /^tcp/ } 0..$#addr_list);
                #my @del_indexes = reverse(grep { $addr_list[$_] =~ /^tcp:/ } 0..$#addr_list);
                foreach my $index (@del_indexes) {
                    splice (@addr_list, $index, 1);
                }
            }
        }

        my $is_running_output = ($is_running)?"yes":"no";

        if ($service->disabled) {
            $is_running_output = "disabled" unless $is_running;
        }

        my %service_info = ();
        $service_info{"name"}       = $service_name;
        $service_info{"is_running"} = $is_running_output;
        $service_info{"addresses"}  = \@addr_list;
        $service_info{"version"}    = $service->package_version;

        if ($service_name eq "bwctl") {
            $service_info{"testing_ports"} = \@bwctl_test_ports;
        }
        elsif ($service_name eq "owamp") {
            $service_info{"testing_ports"} = \@owamp_test_ports;
        }


        $services{$service_name} = \%service_info;
    }


    my @services = values %services;

    return {'services', \@services};
}

sub get_summary {
    my $self = shift;

    my $start_time = gettimeofday();
    my $end_time;

    my $administrative_info = $self->get_information();
    my $status = $self->get_status();
    my $services = $self->get_services();
    my $communities = $self->get_communities();
    my $meshes = $self->get_meshes();

    my $results = { %$administrative_info, %$status, %$services, %$communities, %$meshes };

    return $results;

}

sub get_communities {
    my $self = shift;

    my $communities = $self->{admin_info_conf}->get_keywords();

    return {communities => $communities};

}

sub get_meshes {
    my $self = shift;
    my @mesh_urls = ();
    eval {
        my $mesh_config_conf = "/opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf";

        die unless ( -f $mesh_config_conf );

        my %conf = Config::General->new($mesh_config_conf)->getall;

        $conf{mesh} = [ ] unless $conf{mesh};
        $conf{mesh} = [ $conf{mesh} ] unless ref($conf{mesh}) eq "ARRAY";

        foreach my $mesh (@{ $conf{mesh} }) {
            next unless $mesh->{configuration_url};

            push @mesh_urls, $mesh->{configuration_url};
        }
    };
    if ($@) {
        @mesh_urls = [];
    }
    return {meshes => \@mesh_urls};
}


1;

# vim: expandtab shiftwidth=4 tabstop=4
