package Devel::Declare::Lexer::Token::String;

use base qw/ Devel::Declare::Lexer::Token /;

use v5.14.2;

sub new
{
    my ($caller, %arg) = @_;

    my $self = $caller->SUPER::new(%arg);

    return $self;
}

sub get
{
    my ($self) = @_;

    return $self->{start} . $self->{value} . $self->{end};
}

1;
