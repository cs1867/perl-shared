package perfSONAR_PS::RegularTesting::Tests::Bwctl;

use strict;
use warnings;

our $VERSION = 3.4;

use IPC::Run qw( start pump );
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use File::Temp qw(tempdir);
use JSON;

use perfSONAR_PS::RegularTesting::Parsers::Bwctl qw(parse_bwctl_output fill_iperf_data fill_iperf3_data);

use Moose;

extends 'perfSONAR_PS::RegularTesting::Tests::BwctlBase';

has 'bwctl_cmd' => (is => 'rw', isa => 'Str', default => '/usr/bin/bwctl');
has 'tool' => (is => 'rw', isa => 'Str', default => 'iperf');
has 'use_udp' => (is => 'rw', isa => 'Bool', default => 0);
has 'streams' => (is => 'rw', isa => 'Int', default => 1);
has 'duration' => (is => 'rw', isa => 'Int', default => 10);
has 'omit_interval' => (is => 'rw', isa => 'Int');
has 'udp_bandwidth' => (is => 'rw', isa => 'Int');
has 'buffer_length' => (is => 'rw', isa => 'Int');
has 'packet_tos_bits' => (is => 'rw', isa => 'Int');
has 'window_size'   => (is => 'rw', isa => 'Int');
has 'zero_copy' => (is => 'rw', isa => 'Bool', default => 0);
has 'single_ended' => (is => 'rw', isa => 'Bool', default => 0);
#new pscheduler parameters
has 'tcp_bandwidth' => (is => 'rw', isa => 'Int');
has 'mss' => (is => 'rw', isa => 'Int');
has 'dscp' => (is => 'rw', isa => 'Int');
has 'no_delay' => (is => 'rw', isa => 'Bool');
has 'congestion' => (is => 'rw', isa => 'Str');
has 'flow_label' => (is => 'rw', isa => 'Int');
has 'client_cpu_affinity' => (is => 'rw', isa => 'Int');
has 'server_cpu_affinity' => (is => 'rw', isa => 'Int');
        
my $logger = get_logger(__PACKAGE__);

override 'type' => sub { "bwctl" };

override 'build_cmd' => sub {
    my ($self, @args) = @_;
    my $parameters = validate( @args, {
                                         source => 1,
                                         destination => 1,
                                         local_destination => 1,
                                         force_ipv4 => 0,
                                         force_ipv6 => 0,
                                         results_directory => 1,
                                         test_parameters => 1,
                                         schedule => 0,
                                      });
    my $source            = $parameters->{source};
    my $destination       = $parameters->{destination};
    my $results_directory = $parameters->{results_directory};
    my $test_parameters   = $parameters->{test_parameters};
    my $schedule          = $parameters->{schedule};

    my @cmd = ();
    push @cmd, $test_parameters->bwctl_cmd;

    # Add the parameters from the parent class
    push @cmd, super();

    if($test_parameters->use_udp){
        push @cmd, '-u';
        push @cmd, ( '-b', $test_parameters->udp_bandwidth ) if $test_parameters->udp_bandwidth;
    }
    push @cmd, ( '-P', $test_parameters->streams ) if $test_parameters->streams;
    push @cmd, ( '-t', $test_parameters->duration ) if $test_parameters->duration;
    push @cmd, ( '-O', $test_parameters->omit_interval ) if $test_parameters->omit_interval;
    push @cmd, ( '-l', $test_parameters->buffer_length ) if $test_parameters->buffer_length;
    push @cmd, ( '-w', $test_parameters->window_size ) if $test_parameters->window_size;
    push @cmd, ( '-Z', $test_parameters->zero_copy ) if $test_parameters->zero_copy;
    push @cmd, ( '--single-ended', $test_parameters->single_ended ) if $test_parameters->single_ended;

    # Set a default reporting interval
    push @cmd, ( '-i', '1' );

    # Have the tool use the most parsable format
    push @cmd, ( '--parsable' );

    return @cmd;
};

override 'build_results' => sub {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         source => 1,
                                         destination => 1,
                                         test_parameters => 0,
                                         schedule => 0,
                                         output => 1,
                                      });
    my $source          = $parameters->{source};
    my $destination     = $parameters->{destination};
    my $test_parameters = $parameters->{test_parameters};
    my $schedule        = $parameters->{schedule};
    my $output          = $parameters->{output};

    my $results = perfSONAR_PS::RegularTesting::Results::ThroughputTest->new();

    my $protocol;
    if ($test_parameters->use_udp) {
        $protocol = "udp";
    }
    else {
        $protocol = "tcp";
    }

    # Fill in the information we know about the test
    $results->source($self->build_endpoint(address => $source, protocol => $protocol));
    $results->destination($self->build_endpoint(address => $destination, protocol => $protocol));

    $results->protocol($protocol);
    $results->streams($test_parameters->streams);
    $results->zero_copy($test_parameters->zero_copy);
    $results->single_ended($test_parameters->single_ended);
    $results->time_duration($test_parameters->duration);
    $results->bandwidth_limit($test_parameters->udp_bandwidth) if $test_parameters->udp_bandwidth;
    $results->buffer_length($test_parameters->buffer_length) if $test_parameters->buffer_length;

    # Add in the raw output
    $results->raw_results($output);

    # Parse the bwctl output, and add it in
    my $bwctl_results = parse_bwctl_output({ stdout => $output });

    # Fill in the data that came directly from BWCTL itself
    $results->source->address($bwctl_results->{sender_address}) if $bwctl_results->{sender_address};
    $results->destination->address($bwctl_results->{receiver_address}) if $bwctl_results->{receiver_address};
    $results->tool($bwctl_results->{tool});
    
    push @{ $results->errors }, $bwctl_results->{error} if ($bwctl_results->{error});

    $results->start_time($bwctl_results->{start_time});
    $results->end_time($bwctl_results->{end_time});

    # Fill in the data that came from the tool itself
    if ($bwctl_results->{tool} eq "iperf") {
        fill_iperf_data({ results_obj => $results, results => $bwctl_results->{results} });
    }
    elsif ($bwctl_results->{tool} eq "iperf3") {
        fill_iperf3_data({ results_obj => $results, results => $bwctl_results->{results} });
    }
    else {
        push @{ $results->errors }, "Unknown tool type: ".$bwctl_results->{tool};
    }

    use Data::Dumper;
    $logger->debug("Build Results: ".Dumper($results->unparse));

    return $results;
};

override 'build_pscheduler_task' => sub {
    my ($self, @args) = @_;
    my $parameters = validate( @args, {
                                         url => 1,
                                         source => 1,
                                         destination => 1,
                                         destination_port => 0,
                                         local_destination => 1,
                                         force_ipv4 => 0,
                                         force_ipv6 => 0,
                                         test_parameters => 1,
                                         test => 1,
                                         source_node => 0,
                                         dest_node => 0,
                                      });
    my $psc_url           = $parameters->{url};
    my $source            = $parameters->{source};
    my $destination       = $parameters->{destination};
    my $local_destination = $parameters->{local_destination};
    my $force_ipv4        = $parameters->{force_ipv4};
    my $force_ipv6        = $parameters->{force_ipv6};
    my $test_parameters   = $parameters->{test_parameters};
    my $test              = $parameters->{test};
    my $schedule          = $test->schedule();
    my $source_node       = $parameters->{source_node};
    my $dest_node         = $parameters->{dest_node};
    
    my $psc_task = new perfSONAR_PS::Client::PScheduler::Task(url => $psc_url);
    $psc_task->reference_param('description', $test->description()) if $test->description();
    foreach my $test_ref(@{$test->references()}){
        next if($test_ref->name() eq 'description' || $test_ref->name() eq 'created-by');
        $psc_task->reference_param($test_ref->name(), $test_ref->value());
    }
    
    #Test parameters
    my $psc_test_spec = {};
    $psc_task->test_type('throughput');
    $psc_test_spec->{'source'} = $source if($source);
    $psc_test_spec->{'dest'} = $destination;
    if($test->parameters->tool){
        my @tools = split ',', $test->parameters->tool;
        foreach my $tool(@tools){
            if($tool eq 'iperf'){
                $psc_task->add_requested_tool('bwctliperf2');
                $psc_task->add_requested_tool('iperf2');
            }elsif($tool eq 'iperf3'){
                $psc_task->add_requested_tool('bwctliperf3');
                $psc_task->add_requested_tool('iperf3');
            }else{
                $psc_task->add_requested_tool($tool);
            }
        }
    }
    if($test_parameters->use_udp){
        $psc_test_spec->{'udp'} = JSON::true;
        $psc_test_spec->{'bandwidth'} = int($test_parameters->udp_bandwidth) if $test_parameters->udp_bandwidth;
    }else{
        $psc_test_spec->{'bandwidth'} = int($test_parameters->tcp_bandwidth) if $test_parameters->tcp_bandwidth;
    }      
    $psc_test_spec->{'duration'} = "PT" . $test_parameters->duration . "S" if $test_parameters->duration;
    $psc_test_spec->{'omit'} = "PT" . $test_parameters->omit_interval . "S" if $test_parameters->omit_interval;
    $psc_test_spec->{'buffer-length'} = int($test_parameters->buffer_length)  if $test_parameters->buffer_length;
    $psc_test_spec->{'ip-tos'} = int($test_parameters->packet_tos_bits) if $test_parameters->packet_tos_bits;
    $psc_test_spec->{'parallel'} = int($test_parameters->streams) if $test_parameters->streams;
    $psc_test_spec->{'window-size'} = int($test_parameters->window_size) if $test_parameters->window_size;
    $psc_test_spec->{'zero-copy'} = int($test_parameters->zero_copy) if $test_parameters->zero_copy;
    $psc_test_spec->{'single-ended'} = int($test_parameters->single_ended) if $test_parameters->single_ended;
    $psc_test_spec->{'mss'} = int($test_parameters->mss) if $test_parameters->mss;
    $psc_test_spec->{'dscp'} = int($test_parameters->dscp) if $test_parameters->dscp;
    $psc_test_spec->{'no-delay'} = JSON::true if($test_parameters->{no_delay});
    $psc_test_spec->{'congestion'} = $test_parameters->congestion if $test_parameters->congestion;
    $psc_test_spec->{'flow-label'} = int($test_parameters->flow_label) if $test_parameters->flow_label;
    $psc_test_spec->{'client-cpu-affinity'} = int($test_parameters->client_cpu_affinity) if $test_parameters->client_cpu_affinity;
    $psc_test_spec->{'server-cpu-affinity'} = int($test_parameters->server_cpu_affinity) if $test_parameters->server_cpu_affinity;
    $psc_test_spec->{'source-node'} = $source_node if($source_node);
    $psc_test_spec->{'dest-node'} = $dest_node if($dest_node);
    $psc_test_spec->{'ip-version'} = 4 if($force_ipv4);
    $psc_test_spec->{'ip-version'} = 6 if($force_ipv6);
    $psc_task->test_spec($psc_test_spec);
    #TODO: Support for more scheduling params
    if ($schedule->type eq "regular_intervals") {
        $self->psc_test_interval(schedule => $schedule, psc_task => $psc_task);
    }else{
        $logger->warn("Schedule type " . $schedule->type . " not currently supported. Skipping test.");
        return;
    }
    
    return $psc_task;    
    
};


override 'pscheduler_archive_type' => sub {
    return 'esmond/throughput';
};

1;
