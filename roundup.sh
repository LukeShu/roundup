#!/bin/sh
# [r5]: roundup.5.html
# [r1t]: roundup-1-test.sh.html
# [r5t]: roundup-5-test.sh.html
#
# _(c) 2010 Blake Mizerany - MIT License_
#
# Spray **roundup** on your shells to eliminate weeds and bugs.  If your shells
# survive **roundup**'s deathly toxic properties, they are considered
# roundup-ready.
#
# roundup reads shell scripts to form test plans.  Each
# test plan is sourced into a sandbox where each test is executed.
#
# See [roundup-1-test.sh.html][r1t] or [roundup-5-test.sh.html][r5t] for example
# test plans.
#
# __Install__
#
#     git clone http://github.com/bmizerany/roundup.git
#     cd roundup
#     make
#     sudo make install
#     # Alternatively, copy `roundup` wherever you like.
#
# __NOTE__:  Because test plans are sourced into roundup, roundup prefixes it's
# variable and function names with `roundup_` to avoid name collisions.  See
# "Sandbox Test Runs" below for more insight.

# Usage and Prerequisites
# -----------------------

# Exit if any following command exits with a non-zero status.
set -e

# Error on any unbound variables
set -u

# The current version is set during `make version`.  Do not modify this line in anyway
# unless you know what you're doing.
VERSION="0.1.0"

# Usage is defined in a specific comment syntax. It is `grep`ed out of this file
# when needed (i.e. The Tomayko Method).  See
# [shocco](http://rtomayko.heroku.com/shocco) for more detail.

#/ usage: roundup [plan ...]

roundup_usage() {
    grep '^#/' <"$0" | cut -c4-
}

# Usage expected.  Run `usage` and exit clean.
expr -- "$*" : ".*--help" >/dev/null && {
    roundup_usage
    exit 0
}

# Test at least one plan was given
test "$#" -eq 0 && {
    roundup_usage
    exit 1
}

# Store test plans for looping and state assumptions about test scoring.  These
# will be recalculated as each test runs.
roundup_plans="$@"
roundup_ntests=0
roundup_passed=0
roundup_failed=0

# Colors for output
roundup_clr=$(echo -e "\033[m")
roundup_red=$(echo -e "\033[31m")
roundup_grn=$(echo -e "\033[32m")
roundup_mag=$(echo -e "\033[35m")

roundup_trace() {
    echo "$1"                                       |
    sed -e '1,2d ; s/^++// ; s/^\(.*\)$/    ! \1/'  |
    sed -e "\$s/\(.*\)/$roundup_mag\1$roundup_clr/"
}

roundup_pass() {
    echo $roundup_grn $1 $roundup_clr
}

roundup_fail() {
    echo $roundup_red $1 $roundup_clr
}

# Sandbox Test Runs
# -----------------

# The above checks guarantee we have at least one test.  We can now move through
# each specified test plan, determine it's test plan, and administer each test
# listed in a isolated sandbox.
for roundup_p in "$roundup_plans"
do
    # Create a sandbox, source the test plan, run the tests, then leave
    # without a trace.
    (
        # Add to overall test count.
        roundup_ntests=$(($roundup_ntests + 1))

        # Consider the description to be the `basename` of <plan> minus the
        # tailing -test.sh.
        roundup_desc=$(basename "$roundup_p" .sh | sed 's/-test$//g')

        # Define functions for
        # [roundup(5)][r5]

        # A custom description is recommended, but optional.  Use `describe` to
        # set the description to something more meaningful.
        describe() {
            roundup_desc="$*"
        }

        # Seek test methods and aggregate their names, forming a test plan.  This
        # is done before populating the sandbox with tests to avoid odd
        # conflicts.
        roundup_plan=$(
            grep "^it_.*()" $1                       |
            sed "s/\(it_[a-zA-Z0-9_]*\).*$/\1/g"
        )

        # We have the test plan and are in our sandbox with [roundup(5)][r5] defined.
        # Now we source the plan to bring it's tests into scope.
        . $roundup_p

        # The plan has been sourced.  It it time to display the title.
        echo "$roundup_desc"

        # Determine the test plan and administer each test. Score as we go.  The
        # total grade will be determined once all suites pass.  Before each
        # test, turn off automatic failure on command error so we can handle it
        # as a test failure and not a script failure.
        for roundup_t in $roundup_plan
        do
            printf "  $roundup_t: "

            set +e
            before
            roundup_output=$( set -x -e; (eval "$roundup_t") 2>&1 )
            roundup_result=$?
            after
            set -e

            if [ "$roundup_result" -ne 0 ]
            then
                roundup_failed=$(($roundup_failed + 1))
                roundup_fail "[FAIL]"
                roundup_trace "$roundup_output"
            else
                roundup_passed=$(($roundup_passed + 1))
                roundup_pass "[PASS]"
            fi
        done
    )
done

# Test Summary
# ------------

# Display the summary now that all tests are finished.
echo "======================================="
printf "Tests:  %3d | " $roundup_ntests
printf "Passed: %3d | " $roundup_passed
printf "Failed: %3d"    $roundup_failed
echo
