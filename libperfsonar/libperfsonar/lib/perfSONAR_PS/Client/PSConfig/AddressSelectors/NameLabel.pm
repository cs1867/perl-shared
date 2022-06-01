package perfSONAR_PS::Client::PSConfig::AddressSelectors::NameLabel;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::AddressSelectors::BaseAddressSelector';

has 'type' => (
      is      => 'ro',
      default => sub {
          #override this
          return "namelabel";
      },
  );

=item name()

Gets/sets name

=cut

sub name{
    my ($self, $val) = @_;
    return $self->_field_name('name', $val);
}

=item label()

Gets/sets label

=cut

sub label{
    my ($self, $val) = @_;
    return $self->_field_name('label', $val);
}


=item select()

Selects addresses with given name and label then returns as list of name/label/address
HashRefs.

=cut

sub select{
    my ($self, $psconfig) = @_;
    
    #make sure we have a config
    unless($psconfig){
        return (undef, undef);
    }
    
    #make sure we have a name
    my $name = $self->name();
    unless($name){
        return (undef, undef);
    }
    
    #make sure it matches an address
    my $address = $psconfig->address($name);
    unless($address){
        return (undef, undef);
    }
    
    #got everything we need, return. Label may be undef, but that's ok
    return [{"label" => $self->label(), "name" => $name, "address" => $address}];
}


  
__PACKAGE__->meta->make_immutable;

1;