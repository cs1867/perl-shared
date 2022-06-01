package perfSONAR_PS::Client::PSConfig::AddressClasses::DataSources::CurrentConfig;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::AddressClasses::DataSources::BaseDataSource';

has 'type' => (
      is      => 'ro',
      default => sub {
          my $self = shift;
          $self->data->{'type'} = 'current-config';
          return $self->data->{'type'};
      },
  );

=item fetch()

Accepts a config object and returns HashRef of Address objects from the current config file

=cut

sub fetch{
    my ($self, $psconfig) = @_;
    
    #make sure we have a config
    unless($psconfig){
        return;
    }
    
    return $psconfig->addresses();
}

__PACKAGE__->meta->make_immutable;

1;