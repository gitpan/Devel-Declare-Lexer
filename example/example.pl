#!/perl

package ExampleUsage;

use ExampleSyntax;

debug "This is a test\n";

function example ($a, $b) {
    return $a + $b;
};
print "1 + 2 = " . example(1, 2) . "\n";
