package Devel::Declare::Lexer::Token::String;

use base qw/ Devel::Declare::Lexer::Token /;

use v5;

sub new
{
    my ($caller, %arg) = @_;

    my $self = $caller->SUPER::new(%arg);

    return $self;
}

sub get
{
    my ($self) = @_;

    my $v = $self->{value};
    $v =~ s/\n/\\n/g;

    return $self->{start} . $v . $self->{end};
}

1;
