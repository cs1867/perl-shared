package perfSONAR_PS::Utils::TL1::HDXc;

use warnings;
use strict;

use Params::Validate qw(:all);
use Data::Dumper;
use perfSONAR_PS::Utils::ParameterValidation;

use base 'perfSONAR_PS::Utils::TL1::Base';
use fields 'PMS', 'PM_CACHE_TIME', 'OMS', 'OM_CACHE_TIME', 'ALARMS', 'ALARMS_CACHE_TIME', 'CROSSCONNECTS', 'CROSSCONNECTS_CACHE_TIME', 'ETHERNET_PORTS', 'ETHERNET_PORTS_CACHE_TIME', 'OPTICAL_PORTS', 'OPTICAL_PORTS_CACHE_TIME', 'WAN_PORTS', 'WAN_PORTS_CACHE_TIME';

sub initialize {
    my ($self, @params) = @_;

    my $parameters = validate(@params,
            {
            address => 1,
            port => 0,
            username => 1,
            password => 1,
            cache_time => 1,
            });

    $parameters->{"type"} = "hdxc";
    $parameters->{"prompt"} = "TL1 Engine>" if (not $parameters->{prompt});
    $parameters->{"port"} = "23" if (not $parameters->{port});

    $self->{OPTICAL_PORTS_CACHE_TIME} = 0;
    $self->{ETHERNET_PORTS_CACHE_TIME} = 0;
    $self->{WAN_PORTS_CACHE_TIME} = 0;
    $self->{PM_CACHE_TIME} = 0;
    $self->{OM_CACHE_TIME} = 0;
    $self->{CROSSCONNECTS_CACHE_TIME} = 0;

    return $self->SUPER::initialize($parameters);
}

sub getOCN {
    my ($self, $facility_name) = @_;

    if ($self->{OPTICAL_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
        my %ocns = ();

        foreach my $i (3, 12, 48, 192) {
            my ($successStatus, $results) = $self->send_cmd("RTRV-OC".$i.":::".$self->{CTAG}.";");
            if ($successStatus != 1) {
                return (-1, $results);
            }

            $self->{LOGGER}->debug("Got OC$i line\n");

            foreach my $line (@$results) {
                $self->{LOGGER}->debug($line."\n");

# "OC192-1-503-0-2-1:
#  TYP-SH-SL-SBSL-PRT-SIG:
#  TRLCTPGINST=1+11665+11665,LPBKFAC=INACTIVE,TPNTTEM=10G,TRLCTPGTID=34112+34114+34116,TPNTACT=N,SSBITMDE=SONET,STRCSTATE=ST,FECFRMT=FEC1,LABEL=\"IRNC/GEANT2 [Qwest:OC192-13497983]\",LPBKPORT=INACTIVE,B1PTY=RECALC,INCSTRC1B=0,EXPSTRC1B=0,INCSTRC16B=\"TDM3.Ams1_505_2\",TXSTRC16B=\"ManL.HDXc_503_2\",TASTATE=INACTIVE,LPBKTRM=INACTIVE,STRCSUS=RELIABLE,STFORMAT=16BYTE,TRLEPTID=46112+46312,EXPSTRC16B=\"\",FECSTATE=ACTIVE,LPBKLK=LOCKED,SDGTH=10E-8,TXSTRC1B=0,SFTH=10E-4,D4PASS=DISABLE:
# IS,ACT"

                if ($line =~ /^[^"]*"([^:]*):([^:]*):(.*):([A-Z&]*),([A-Z&]*)"/) {
                    my %ocn = ();

                    $ocn{facility} = $1;
                    $ocn{facility_type} = "optical";
                    $ocn{pst} = $4;
                    $ocn{sst} = $5;

                    foreach my $pair (split(',', $3)) {
                        next if (not $pair);

                        my ($key, $value) = split('=', $pair);

                        next if (not $value);

                        $value =~ s/\\"//g;

                        $ocn{lc($key)} = $value;
                    }

                    $ocns{$1} = \%ocn;

                    $self->{LOGGER}->debug("Line: \'$line\'");
                    $self->{LOGGER}->debug("facility: \'$1\'");
                    $self->{LOGGER}->debug("pst: \'$4\'");
                    $self->{LOGGER}->debug("sst: \'$5\'");
                    $self->{LOGGER}->debug("key_value_pairs: \'$3\'");
                    $self->{LOGGER}->debug("Produced: \'".Dumper(\%ocn)."\'");
                }
            }
        }

        $self->{OPTICAL_PORTS} = \%ocns;
        $self->{OPTICAL_PORTS_CACHE_TIME} = time;
    }

    if (not defined $facility_name) {
        return (0, $self->{OPTICAL_PORTS});
    }

    return (0, $self->{OPTICAL_PORTS}->{$facility_name});
}

#sub getETH {
#    my ($self, $facility_name) = @_;
#
#    if ($self->{ETHERNET_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
#        my %eths = ();
#
#        foreach my $type ("ETH", "ETH10G") {
#            my ($successStatus, $results) = $self->send_cmd("RTRV-".$type."::".$type."-1-ALL:".$self->{CTAG}.";");
#            if ($successStatus != 1) {
#                return (-1, $results);
#            }
#
##   "ETH-1-4-3::AN=ENABLE,ANSTATUS=INPROGRESS,ANETHDPX=UNKNOWN,ANSPEED=UNKNOWN,ANPAUSETX=UNKNOWN,ANPAUSERX=UNKNOWN,ADVETHDPX=UNKNOWN,ADVSPEED=UNKNOWN,ADVFLOWCTRL=UNKNOWN,ETHDPX=FULL,SPEED=1000,FLOWCTRL=ASYM,PAUSETX=ENABLE,PAUSERX=DISABLE,PAUSERXOVERRIDE=ENABLE,MTU=9600,TXCON=ENABLE,PASSCTRL=DISABLE,PAUSETXOVERRIDE=DISABLE,RXIDLE=0,CFPRF=CFPRF-1-4,PHYSADDR=00140D034877:OOS-MA,DISCD"
##   "ETH-1-4-4::AN=ENABLE,ANSTATUS=INPROGRESS,ANETHDPX=UNKNOWN,ANSPEED=UNKNOWN,ANPAUSETX=UNKNOWN,ANPAUSERX=UNKNOWN,ADVETHDPX=UNKNOWN,ADVSPEED=UNKNOWN,ADVFLOWCTRL=UNKNOWN,ETHDPX=FULL,SPEED=1000,FLOWCTRL=ASYM,PAUSETX=ENABLE,PAUSERX=DISABLE,PAUSERXOVERRIDE=ENABLE,MTU=9600,TXCON=ENABLE,PASSCTRL=DISABLE,PAUSETXOVERRIDE=DISABLE,RXIDLE=0,CFPRF=CFPRF-1-4,PHYSADDR=00140D034878:OOS-MA,DISCD"
#
#            foreach my $line (@$results) {
#                $self->{LOGGER}->debug($line);
#                if ($line =~ /"([^:]*:[^:]*:[^:]*:[^"]*)"/) {
#                    $line = $1;
#
#                my %eth = ();
#
#                my @fields = split(':', $line);
#                my $aid = $fields[0];
#                my ($pst, $sst) = split(',', $fields[3]);
#
#                $eth{facility} = $aid;
#                $eth{facility_type} = "ethernet";
#
#                foreach my $pair (split(',', $fields[2])) {
#                    next if (not $pair);
#
#                    my ($key, $value) = split('=', $pair);
#
#                    $eth{lc($key)} = $value;
#                }
#
#                $eth{pst} = $pst;
#                $eth{sst} = $sst;
#
#                $eths{$aid} = \%eth;
#            }
#            }
#        }
#
#        $self->{ETHERNET_PORTS} = \%eths;
#        $self->{ETHERNET_PORTS_CACHE_TIME} = time;
#    }
#
#    if (not defined $facility_name) {
#        return (0, $self->{ETHERNET_PORTS});
#    }
#
#    return (0, $self->{ETHERNET_PORTS}->{$facility_name});
#}

#sub getWAN {
#    my ($self, $facility_name) = @_;
#
#    if ($self->{OPTICAL_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
#        my %wans = ();
#
#        my ($successStatus, $results) = $self->send_cmd("RTRV-WAN::WAN-1-ALL:".$self->{CTAG}.";");
#        if ($successStatus != 1) {
#            return (-1, $results);
#        }
#
#        $self->{LOGGER}->debug("Got OCN Lines\n");
#
#        foreach my $line (@$results) {
#            $self->{LOGGER}->debug($line."\n");
##   "WAN-1-10-1::MAPPING=GFP-F,FCS=0,CONDTYPE=GFPCMF,GFPRFI=ENABLE,PROVRXUNITS=0,GFPRTDELAY=ENABLE,RATE=NONE,LCAS=DISABLE,VCAT=ENABLE,PROVUNITS=0,ACTUALUNITS=0,LANFCS=ENABLE,RTDELAY=UNKNOWN,MAXVCDEL=0,CURRVCDEL=0,SCRAMBLE=ENABLE,ACTUALRXUNITS=0:OOS-MA,DISCD"
##   "WAN-1-12-1::MAPPING=GFP-F,FCS=32,CONDTYPE=GFPCMF,GFPRFI=ENABLE,PROVRXUNITS=0,GFPRTDELAY=ENABLE,RATE=NONE,LCAS=DISABLE,VCAT=DISABLE,PROVUNITS=0,ACTUALUNITS=0,LANFCS=ENABLE,RTDELAY=UNKNOWN,MAXVCDEL=0,CURRVCDEL=0,SCRAMBLE=ENABLE,ACTUALRXUNITS=0:OOS-MA,DISCD"
#            if ($line =~ /"([^:]*:[^:]*:[^:]*:[^"]*)"/) {
#                $line = $1;
#                my %wan = ();
#
#                my @fields = split(':', $line);
#                my $aid = $fields[0];
#                my ($pst, $sst) = split(',', $fields[3]);
#
#                $wan{facility} = $aid;
#                $wan{facility_type} = "wan";
#
#                foreach my $pair (split(',', $fields[2])) {
#                    next if (not $pair);
#
#                    my ($key, $value) = split('=', $pair);
#
#                    $wan{lc($key)} = $value;
#                }
#
#                $wan{pst} = $pst;
#                $wan{sst} = $sst;
#
#                $wans{$aid} = \%wan;
#            }
#        }
#
#        $self->{WAN_PORTS} = \%wans;
#        $self->{WAN_PORTS_CACHE_TIME} = time;
#    }
#
#    if (not defined $facility_name) {
#        return (0, $self->{WAN_PORTS});
#    }
#
#    return (0, $self->{WAN_PORTS}->{$facility_name});
#}

sub getCrossconnect {
    my ($self, $facility_name) = @_;

    if ($self->{CROSSCONNECTS_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
        my %crss = ();

        my ($successStatus, $results) = $self->send_cmd("RTRV-CRS-ALL:::".$self->{CTAG}.";");
        if ($successStatus != 1) {
            return (-1, $results);
        }

        $self->{LOGGER}->debug("Got CRS Lines\n");

        foreach my $line (@$results) {
            $self->{LOGGER}->debug($line."\n");

#   "OC192-1-502-0-1-1-73,OC192-1-503-0-4-1-58
#    :
#    2WAY,STS-3C
#    :
#    PRIME=OSS,DISOWN=IDLE,CONNID=2033,LABEL=\"DICE3:NEWY:UVA:0004\",AST=LOCKED
#    :
#    ACT"

#"OC192-1-502-0-3-1-106,OC192-1-503-0-4-1-85:2WAY,STS-3C:PRIME=OSS,DISOWN=IDLE,CONNID=2009,LABEL=\"PHOSPHORUS:CRC:CANARIE:SURFNET:I2CAT:5\",AST=LOCKED:ACT"
            if ($line =~ /^[^"]*"([^,]*),([^:]*):([^,]*),([^:]*):(.*):([A-Z&]*)"/) {
                my %crs = ();

                $crs{fromendpointname} = $1;
                $crs{fromendpointtype} = lc($4);
                $crs{toendpointname} = $2;
                $crs{toendpointtype} = lc($4);
                $crs{direction} = $3;
                $crs{rate} = lc($4);
                $crs{sst} = $6;

                foreach my $pair (split(',', $5)) {
                    my ($key, $value) = split("=", $pair);

                    next if (not $value);

                    # Get rid of the quotes
                    $value =~ s/\\"//g;

                    $crs{lc($key)} = $value;
                }

                $crss{$1."-".$2} = \%crs;

                $self->{LOGGER}->debug("Line: \'$line\'");
                $self->{LOGGER}->debug("from: \'$1\'");
                $self->{LOGGER}->debug("to: \'$2\'");
                $self->{LOGGER}->debug("dir: \'$3\'");
                $self->{LOGGER}->debug("speed: \'$4\'");
                $self->{LOGGER}->debug("key_value_pairs: \'$5\'");
                $self->{LOGGER}->debug("sst: \'$6\'");
                $self->{LOGGER}->debug("Produced: \'".Dumper(\%crs)."\'");
            }
        }

        $self->{CROSSCONNECTS} = \%crss;
        $self->{CROSSCONNECTS_CACHE_TIME} = time;
    }

    return (0, $self->{CROSSCONNECTS});
}

sub getAlarms {
    my ($self, $alarm_to_match) = @_;

    if ($self->{ALARMS_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
        my @alarms = ();

        $self->{LOGGER}->debug("looking up alarms");

        my ($successStatus, $results) = $self->send_cmd("RTRV-ALM-ALL:::".$self->{CTAG}."::;");

        $self->{LOGGER}->debug("Results: ".Dumper($results));

        if ($successStatus != 1) {
            $self->{ALARMS} = undef;
            return (-1, $results);
        }

#   "ETH10G-1-10-4,ETH10G:CR,LOS,SA,01-07,07-34-55,NEND,RCV:\"Loss Of Signal\",NONE:0100000295-0008-0673,:YEAR=2006,MODE=NONE"
        foreach my $line (@{ $results }) {
        if ($line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^,]*),([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/) {
            my $facility = $1;
            my $facility_type = $2;
            my $severity = $3;
            my $alarmType = $4;
            my $serviceAffecting = $5;
            my $date = $6;
            my $time = $7;
            my $location = $8;
            my $direction = $9;
            my $description = $10;
            my $something1 = $11;
            my $alarmId = $12;
            my $something2 = $13;
            my $year = $14;
            my $mode = $15;

            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");

            my $timestamp = $self->convertTimeStringToTimestamp($self->convertPMDateTime($date, $time));

            my %alarm = (
                facility => $facility,
                facility_type => $facility_type,
                severity => $severity,
                alarm_type => $alarmType,
                alarm_time => $timestamp,
                alarm_time_local => $self->convertMachineTSToLocalTS($timestamp),
                description => $description,
                service_affecting => $serviceAffecting,
                measurement_time => time,
                date => $date,
                time => $time,
                location => $location,
                direction => $direction,
                alarm_id => $alarmId,
                year => $year,
                mode => $mode,
            );

            push @alarms, \%alarm;
        }
        }

        $self->{ALARMS} = \@alarms;
        $self->{ALARMS_CACHE_TIME} = time;
    }

    my @ret_alarms = ();

    foreach my $alarm (@{ $self->{ALARMS} }) {
        my $matches = 1;
        if ($alarm_to_match) {
            foreach my $key (keys %$alarm_to_match) {
                if ($alarm->{$key}) {
                    if ($alarm->{$key} ne $alarm_to_match->{$key}) {
                        $matches = 1;
                    }
                }
            }
        }

        if ($matches) {
            push @ret_alarms, $alarm;
        }
    }

    return (0, \@ret_alarms);
}

sub waitEvent {
    my ($self, @args) = @_;
    my $args = validateParams(@args, 
            {
                timeout => { type => SCALAR },
            });

    my ($status, $lines);
    if ($args->{timeout} ) {
        ($status, $lines) = $self->waitMessage({ type => "event", timeout => $args->{timeout} });
    } else {
        ($status, $lines) = $self->waitMessage({ type => "event" });
    }

    if ($status != 0 or not defined $lines) {
        return (-1, undef);
    }

    foreach my $line (@{ $lines }) {
        # "WAN-1-4-1:T-UAS-W,TC,01-14,17-30-21,NEND,RCV,10,10,15-MIN:\"T-UAS-W\":0100000000-0000-0000,:YEAR=2009,MODE=NONE"
        if ($line =~ /"([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/) {
            my $aid = $1;
            my $condtype = $2;
            my $effect = $3;
            my $date = $4;
            my $time = $5;
            my $location = $6;
            my $direction = $7;
            my $monitoredValue = $8;
            my $thresholdLevel = $9;
            my $timePeriod = $10;
            my $description = $11;
            my $eventId = $12;
            my $something = $13;
            my $year = $14;
            my $mode = $15;

            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");

            my %event = (
                facility => $aid,
                eventType => $condtype,
                effect => $effect,
                date => $date,
                time => $time,
                location => $location,
                direction => $direction,
                value => $monitoredValue,
                threshold => $thresholdLevel,
                period => $timePeriod,
                description => $description,
                eventId => $eventId,
                year => $year,
                mode => $mode,
                );

            return (0, \%event);
        }
    }

    return (-1, undef);
}

sub waitAlarm {
    my ($self, @args) = @_;
    my $args = validateParams(@args, 
            {
                timeout => { type => SCALAR },
            });

    my ($status, $lines);
    if ($args->{timeout} ) {
        ($status, $lines) = $self->waitMessage({ type => "alarm", timeout => $args->{timeout} });
    } else {
        ($status, $lines) = $self->waitMessage({ type => "alarm" });
    }

    if ($status != 0 or not defined $lines) {
        return (-1, undef);
    }

    foreach my $line (@{ $lines }) {
        if ($line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^,]*),([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/) {
            my $facility = $1;
            my $facility_type = $2;
            my $severity = $3;
            my $alarmType = $4;
            my $serviceAffecting = $5;
            my $date = $6;
            my $time = $7;
            my $location = $8;
            my $direction = $9;
            my $description = $10;
            my $something1 = $11;
            my $alarmId = $12;
            my $something2 = $13;
            my $year = $14;
            my $mode = $15;

            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug("DESCRIPTION: '$description'\n");

            my $timestamp = $self->convertTimeStringToTimestamp($self->convertPMDateTime($date, $time));

            my %alarm = (
                facility => $facility,
                facility_type => $facility_type,
                severity => $severity,
                alarm_type => $alarmType,
                alarm_time => $timestamp,
                alarm_time_local => $self->convertMachineTSToLocalTS($timestamp),
                description => $description,
                service_affecting => $serviceAffecting,
                measurement_time => time,
                date => $date,
                time => $time,
                location => $location,
                direction => $direction,
                alarm_id => $alarmId,
                year => $year,
                mode => $mode,
                );

            return (0, \%alarm);
        }
    }

    return (-1, undef);
}

sub getETH_PM {
    my ($self, $aid, $pm_type) = @_;

    my %facility_types = ( "eth" => 1, "eth10g" => 1 );

    if ($self->{OM_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
        my ($status, $res) = $self->readETH_OMs();
        if ($status != 0) {
            return ($status, $res);
        }

        $self->{OMS} = $res;
    }

    if ($aid and $pm_type) {
        $self->{LOGGER}->debug("Returning $aid/$pm_type");
        return (0, $self->{OMS}->{$aid}->{$pm_type});
    }

    my %pm = ();
    foreach my $curr_aid (keys %{ $self->{OMS} }) {
        next if ($aid and $aid ne $curr_aid);

        foreach my $curr_type (keys %{ $self->{OMS}->{$curr_aid} }) {
            next if ($pm_type and $pm_type ne $curr_type);

            $self->{LOGGER}->debug("Found $curr_type for $aid");

            my $pm = $self->{OMS}->{$curr_aid}->{$curr_type};

            $pm{$curr_aid}->{$curr_type} = $pm;
        }
    }

    if ($aid) {
        return (0, $pm{$aid});
    } else {
        return (0, \%pm);
    }
}

sub getOCN_PM {
    my ($self, $aid, $pm_type) = @_;

    my %facility_types = ( "optical" => 1 );

    return $self->__get_PM($aid, $pm_type, \%facility_types);
}

sub __get_PM {
    my ($self, $aid, $pm_type, $valid_facility_types) = @_;

    if ($self->{PM_CACHE_TIME} + $self->{CACHE_DURATION} < time) {
        my ($status, $res) = $self->readOCN_PMs();
        if ($status != 0) {
            return ($status, $res);
        }

        $self->{LOGGER}->debug("PMs: ".Dumper($res));

        $self->{PMS} = $res;
    }

    if ($aid and $pm_type) {
        $self->{LOGGER}->debug("Returning $aid/$pm_type");
        return (0, $self->{PMS}->{$aid}->{$pm_type});
    }

    my %pm = ();
    foreach my $curr_aid (keys %{ $self->{PMS} }) {
        next if ($aid and $aid ne $curr_aid);

        foreach my $curr_type (keys %{ $self->{PMS}->{$curr_aid} }) {
            next if ($pm_type and $pm_type ne $curr_type);

            my $pm = $self->{PMS}->{$curr_aid}->{$curr_type};

            next unless ($valid_facility_types->{lc($pm->{facility_type})});

            $pm{$curr_aid}->{$curr_type} = $pm;
        }
    }

    if ($aid) {
        return (0, $pm{$aid});
    } else {
        return (0, \%pm);
    }
}

sub readOCN_PMs {
    my ($self) = @_;
    my %pms = ();

    foreach my $type ("ALL-S", "ALL-L", "ALL-P") {
        my ($successStatus, $results) = $self->send_cmd("RTRV-PM-ALL:::".$self->{CTAG}."::$type;");
        if ($successStatus != 1) {
            $self->{LOGGER}->debug("Error grabbing performance counters");
            return (-1, $results);
        }

        foreach my $line (@$results) {
            $self->{LOGGER}->debug($line."\n");

#       "OC192-1-501-0-2-1:UAS-L,713,PRTL,NEND,RCV,15-MIN,02-21,17-30"'
            if ($line =~ /"([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^"]*)"/) {
                my $facility = $1;
                my $facility_type = "optical";
                my $pm_type = $2;
                my $pm_value = $3;
                my $validity = $4;
                my $location = $5;
                my $direction = $6;
                my $time_period = $7;
                my $monitoring_date = $8;
                my $monitoring_time = $9;

                my $monitoredPeriodStart = $self->convertPMDateTime($monitoring_date, $monitoring_time);

                my %pm = (
                        facility => $facility,
                        facility_type => $facility_type,
                        type => $pm_type,
                        value => $pm_value,
                        time_period => $time_period,
                        time_period_start => $monitoredPeriodStart,
                        measurement_type => "bucket",
                        measurement_time => time,
                        machine_time => $self->getMachineTime_TS(),
                        date => $monitoring_date,
                        time => $monitoring_time,
                        validity => $validity,
                        location => $location,
                        direction => $direction,
                    );

                $pms{$facility}->{$pm_type} = \%pm;
            }
        }
    }

    return (0, \%pms);
}

sub readETH_OMs {
    my ($self) = @_;
    my %pms = ();

    foreach my $type ("ETH", "ETH10G") {
        my ($successStatus, $results) = $self->send_cmd("RTRV-OM-".$type."::".$type."-1-ALL:".$self->{CTAG}.":::;");
        if ($successStatus != 1) {
            return (-1, $results);
        }

        foreach my $line (@$results) {
            $self->{LOGGER}->debug($line."\n");

#   "ETH10G-1-10-1::INFRAMES=104322825591,INFRAMESERR=0,INOCTETS=107554715270446,INDFR=88963,INFRAMESDISCDS=12109,INPAUSEFR=0,INCFR=0,FRTOOSHORTS=0,FCSERR=0,FRTOOLONGS=76854,FRAG=0,JAB=0,SYMBOLERR=0,OUTFRAMES=108023304001,OUTFRAMESERR=163,OUTOCTETS=107341268770788,OUTFRAMESDISCDS=0,OUTPAUSEFR=536,OUTDFR=0,INTERNALMACRXERR=0,INTERNALMACTXERR=0"

            if ($line =~ /"([^:]*):([^:]*):([^"]*)"/) {
                my $facility = $1;
                my $facility_type = "ethernet";
                foreach my $pair (split(',', $3)) {
                    my ($type, $value) = split('=', $pair);

                    my %pm = (
                            facility => $facility,
                            facility_type => $facility_type,
                            type => $type,
                            value => $value,
                            measurement_type => "counter",
                            measurement_time => time,
                            machine_time => $self->getMachineTime_TS(),
                        );

                    $pms{$facility}->{$type} = \%pm;
                }
            }
        }
    }

    return (0, \%pms);
}


# Possible monitoring types:
# CV-S - Coding Violations
# ES-S - Errored Seconds - Section 
# SES-S - Severely Errored Seconds - Section 
# SEFS-S - Severely Errored Frame Seconds - Section 
# CV-L - Coding Violations - Line 
# ES-L - Errored Seconds - Line 
# SES-L - Severely Errored Seconds - Line 
# UAS-L - Unavailable Seconds - Line 
# FC-L - Failure Count - Line 
# OPR-OCH - Optical Power Receive - Optical Channel. When tmper=1- UNT this is a gauge value; when tmper=1-15-MIN, 1-DAY this is a snapshot value 
# OPT-OCH - Optical Power Transmit - Optical Channel 
# OPRN-OCH - Optical Power Receive - Normalised - Optical Channel 
# OPTN-OCH - Optical Power Transmit - Normalised - Optical Channel 
# CV-OTU - Coding Violations - OTU 
# ES-OTU - Errored Seconds - OTU
# SES-OTU Severely Errored Seconds - OTU 
# SEFS-OTU Severely Errored Framing Seconds - OTU 
# FEC-OTU Forward Error Corrections - OTU 
# HCCS-OTU High Correction Count Seconds - OTU 
# CV-ODU Coding Violations - ODU 
# ES-ODU Errored Seconds - ODU 
# SES-ODU Severely Errored Seconds - ODU 
# UAS-ODU Unavailable Seconds - ODU 
# FC-ODU Failure Count - ODU 
# CV-PCS Coding Violations ? Physical Coding Sublayer 
# ES-PCS Errored Seconds - Physical Coding Sublayer 
# SES-PCS Severely Errored Seconds - Physical Coding Sublayer 
# UAS-PCS Unavailable Seconds - Physical Coding Sublayer 
# ES-E Errored Seconds ? ETH 
# SES-E Severely Errored Seconds ? ETH 
# UAS-E Unavailable Seconds ? ETH 
# INFRAMES-E Number of frames received (binned OM) - Ethernet, valid only for Ethernet and WAN 
# INFRAMESERR-E Number of errored frames received ? ETH 
# INFRAMEDISCDS-E Number of ingress discarded frames due to congestion or overflow ? ETH 
# DFR-E Aggregate count of discarded frames ? ETH 
# OUTFRAMES-E Number of frames transmitted (binned OM)- Ethernet 
# FCSERR-E Frame Check Sequence Errors (binned OM) - Ethernet 
# PFBERE-OTU Post-FEC Bit Error Rate Estimates - OTU. When tmper=1-UNT this is a gauge value; when tmper=1-15-MIN, 1-DAY this is a snapshot value 
# PRFBER-OTU Pre-FEC Bit Error Rate - OTU 
# ES-W Errored Seconds - WAN 
# SES-W Severely Errored Seconds ? WAN 
# UAS-W Unavailable Seconds ? WAN 
# INFRAMES-W Number of frames received (binned OM) - WAN 
# INFRAMESERR-W Number of errored frames received ? WAN 
# OUTFRAMES-W ANumber of frames transmitted (binned OM)- WAN 
# ES-W Errored Seconds ? WAN 
# SES-W Severely Errored Seconds ? WAN 
# UAS-W Unavailable Seconds ? WAN 
# INFRAMES-W Number of frames received (binned OM) - WAN 
# INFRAMESERR-W Number of errored frames received ? WAN 
# OUTFRAMES-W ANumber of frames transmitted (binned OM)- WAN 


#   "OC192-1-5-1,OC192:OPR-OCH,-3.06,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-5-1,OC192:OPT-OCH,-2.15,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-5-1,OC192:OPRN-OCH,58,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPR-OCH,-2.78,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPT-OCH,-2.25,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPRN-OCH,64,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPR-OCH,0.36,ADJ,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPT-OCH,-2.27,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPRN-OCH,100,ADJ,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-64,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-67,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-70,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-73,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-76,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-79,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-82,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "WAN-1-2-2,WAN:UAS-W,314,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "ETH-1-2-2,ETH:UAS-E,314,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"

sub login {
    my ($self, @params) = @_;
    my $parameters = validate(@params,
            {
                inhibitMessages => { type => SCALAR, optional => 1, default => 1 },
            });
 
#    my ($status, $lines) = $self->waitMessage({ type => "other" });
#    if ($status != 0 or not defined $lines) {
#        $self->{LOGGER}->debug("login failed");
#        return -1;
#    }

    $self->{LOGGER}->debug("PASSWORD: $self->{PASSWORD}\n");

    my ($status, $lines) = $self->send_cmd("ACT-USER::".$self->{USERNAME}.":".$self->{CTAG}."::".$self->{PASSWORD}.";");

    if ($status != 1) {
        return 0;
    }

    if ($parameters->{inhibitMessages}) {
        $self->send_cmd("INH-MSG-ALL:::".$self->{CTAG}.";");
    }

    return 1;
}

1;

# vim: expandtab shiftwidth=4 tabstop=4