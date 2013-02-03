#!/perl

package ExampleUsage;

use ExampleSyntax;

debug "This is a test\n";

function example ($a, $b) {
    return $a + $b;
};
print "1 + 2 = " . example(1, 2) . "\n";

has 'a' => { is => 'rw', isa => 'Int', default => '123', random => 'abc' };
print "a is " . a . "\n";
a(15);
print "a is " . a . "\n";

function example2 ($a) {
    return $a * a;
}
print "example2 = " . example2(10) . "\n";
