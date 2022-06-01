package perfSONAR_PS::Client::PSConfig::Parsers::BaseTemplate;

=head1 NAME

perfSONAR_PS::Client::PSConfig::Parsers::BaseTemplate - A base library for filling in template variables in JSON

=head1 DESCRIPTION

A base library for filling in template variables in JSON

=cut

use Mouse;
use JSON;
use perfSONAR_PS::Utils::JQ qw( jq );

our $VERSION = 4.1;

has 'jq_obj' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'replace_quotes' => (is => 'rw', isa => 'Bool', default => sub { 1 });
has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

=item expand()

Parse the given perl object replace template variables with appropriate values. Returns copy
of object with expanded values.

=cut

sub expand {
    my ($self, $obj) = @_;
    
    #make sure we have an object, otherwise return what was given
    unless($obj){
        return $obj;
    }
    
    #reset error 
    $self->_set_error("");
    
    #convert to string so we get copy and can do replace
    my $json = to_json($obj);
    
    #handle quotes
    my $quote ="";
    if($self->replace_quotes){
        $quote = '"';
    }
    
    #find the variables used
    my %template_var_map = ();
    while($json =~ /\{%\s+(.+?)\s+%\}/g){
        my $template_var = $1;
        next if($template_var_map{$template_var});
        chomp $template_var;
        my $expanded_val = $self->_expand_var($template_var);
        unless(defined $expanded_val){
            return;
        }
        $template_var_map{$template_var} = $expanded_val;
    }
    
    #do the substutions 
    foreach my $template_var(keys %template_var_map){
        #replace standalone quoted variables
        if($quote){
            $json =~ s/\Q${quote}\E\{%\s+\Q${template_var}\E\s+%\}\Q${quote}\E/$template_var_map{$template_var}/g;
            #remove start/end quotes for next substitution
            $template_var_map{$template_var} =~ s/^\Q${quote}\E//;
            $template_var_map{$template_var} =~ s/\Q${quote}\E$//;
        }
        #replace embedded variables
        $json =~ s/\{%\s+\Q${template_var}\E\s+%\}/$template_var_map{$template_var}/g;
    }
    
    # post processing
    ##bracket IPv6 URLs
    $json = $self->_bracket_ipv6_url($json);
    
    #convert back to object
    my $expanded_obj;
    eval{$expanded_obj = from_json($json)};
    if($@){
        $self->_set_error("Unable to create valid JSON after expanding template");
        return;
    }
    
    return $expanded_obj;
    
}

sub _expand_var {
    ##
    # There is probably a more generic way to do this, but starting here
    my ($self, $template_var) = @_;
    die("Override _expand_var");
}

sub _parse_jq {
    my ($self, $jq) = @_;
    
    #in conversions to and from json in expand(), quotes get escaped, so revert that here
    $jq =~ s/\\"/"/g;
    
    my $result;
    eval{
        my $jq_result = jq($jq, $self->jq_obj());
        $result = to_json($jq_result, {"allow_nonref" => 1, 'utf8' => 1});
    };
    if($@){
        $self->_set_error("Error handling jq template variable: " . $@);
        return;
    }
    
    return $result;
}

sub _bracket_ipv6_url {
    my ($self, $json) = @_;
    
    my $IPv4 = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))";
    my $G = "[0-9a-fA-F]{1,4}";

    my @tail = ( ":",
	     "(:($G)?|$IPv4)",
             ":($IPv4|$G(:$G)?|)",
             "(:$IPv4|:$G(:$IPv4|(:$G){0,2})|:)",
	     "((:$G){0,2}(:$IPv4|(:$G){1,2})|:)",
	     "((:$G){0,3}(:$IPv4|(:$G){1,2})|:)",
	     "((:$G){0,4}(:$IPv4|(:$G){1,2})|:)" );


    my $IPv6_re = $G;
    $IPv6_re = "$G:($IPv6_re|$_)" for @tail;
    $IPv6_re = qq/:(:$G){0,5}((:$G){1,2}|:$IPv4)|$IPv6_re/;
    $IPv6_re =~ s/\(/(?:/g;
    $IPv6_re = qr/$IPv6_re/;
    $json =~ s/(https?)\:\/\/($IPv6_re)/$1:\/\/[$2]/gm;
    
    return $json;
}


__PACKAGE__->meta->make_immutable;

1;

