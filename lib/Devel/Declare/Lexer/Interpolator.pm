package Devel::Declare::Lexer::Interpolator;

use strict;
use warnings;

use Data::Dumper;

my $DEBUG = $Devel::Declare::Lexer::DEBUG;

sub interpolate {
    my ($string, @values) = @_;

    my $vars = deinterpolate($string);
    my @varlist = (@$vars);
    $DEBUG and say STDERR Dumper @varlist;
    my $i = 0;
    $DEBUG and say STDERR "old string: $string";
    my $offset = 0;
    for my $var (@varlist) {
        $DEBUG and say STDERR "offset: $offset";
        substr( $string, $var->{start} + $offset, $var->{length} ) = $values[$i];
        my $oldlen = $var->{length};
        my $newlen = length $values[$i];
        $offset += ($newlen - $oldlen);
        $DEBUG and say STDERR "new offset: $offset";
        $i++;
    }
    $DEBUG and say STDERR "new string: $string";
    return $string;
}

sub deinterpolate {
    my ($string) = @_;

    my @vars = ();

    $DEBUG and say STDERR "Deinterpolating '$string'";

    my @chars = split //, $string;

    my @procd = ();
    my $tok = '';
    my $pos = -1;
    for my $char (@chars) {
        push @procd, $char;
        $pos++;
        $DEBUG and say STDERR "Got char '$char'";

        if($char =~ /\s/ && $tok) {
            $DEBUG and say STDERR "    Captured token '$tok' at pos $pos";
            push @vars, {
                token => $tok,
                start => $pos - (length $tok),
                end => $pos,
                length => (length $tok)
            };
            $tok = '';
            next;
        }
        #if($tok && ($char !~ /[\$\@\%]/ || length $tok == 1)) {
        if($tok && ($char !~ /[\$\@]/ || length $tok == 1)) {
        $DEBUG and say STDERR "Got tok '$tok' so far";
            my $eot = 0;
            if($char =~ /[':]/) {
                # do some forwardlooking
                my $c = $chars[$pos + 1];
                #if($c && $c =~ /[\s\$\%\@]/) {
                if($c && $c =~ /[\s\$\@]/) { # hashes are only interpolated with $name{key} syntax
                    $eot = 1;
                }
            }
            if(!$eot) {
                $tok .= $char;
                next;
            }
        }
        #if($char =~ /[\$\@\%]/ || $tok) {
        if($char =~ /[\$\@]/ || $tok) {
            #if($char =~ /[\$\@\%]/ && $tok && $tok !~ /^[\$\@\%]+$/) {
            if( $tok && (($char =~ /[\$\@]/ && $tok !~ /^[\$\@]+$/))) {
                $DEBUG and say STDERR "Captured token '$tok' at pos $pos";
                push @vars, {
                    token => $tok,
                    start => $pos - (length $tok),
                    end => $pos,
                    length => (length $tok)
                };
                $tok = '';
            }
            my $capture = 0;
            $DEBUG and say STDERR "Got tok '$tok' in varcap";
            if(!$tok) {
                # do some backtracking
                my $ec = 0;
                for(my $i = $pos - 1; $i >= 0; $i--) {
                    my $c = $procd[$i];
                    last if $c !~ /\\/;
                    $ec++;
                    $DEBUG and say STDERR "Got char '$c' at pos $i, ec $ec";
                }
                $capture = $ec % 2 == 0 ? 1 : 0;
                #if($ec % 2 == 0) {
                #    print "probably a token\n";
                #} else {
                #    print "probably not a token\n";
                #}
            }
            $DEBUG and say STDERR "Got capture $capture\n";
            $tok = $char if $capture;
            next;
        }
    }

    if(wantarray) {
        $DEBUG and say STDERR "Returning array of token names";
        return map { $_->{token} } @vars;
    }
    $DEBUG and say STDERR "Returning arrayref";
    return \@vars;
}

1;
