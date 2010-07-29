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

# The current version is set during `make version`.  Do not modify this line in
# anyway unless you know what you're doing.
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

# Store test plans for looping and state assumptions about test scoring.  These
# will be recalculated as each test runs.
if [ "$#" -gt "0" ]
then
    roundup_plans="$@"
else
    roundup_plans="$(ls *-test.sh)"
fi

roundup_ntests=0
roundup_passed=0
roundup_failed=0

# Colors for output
# -----------------

# If we are writing to a tty device or we've been asked to always show colors,
# we use colors.
if test -t 1
then
    roundup_clr=$(printf "\033[m")
    roundup_red=$(printf "\033[31m")
    roundup_grn=$(printf "\033[32m")
    roundup_mag=$(printf "\033[35m")

# Otherwise, set the color variables to be empty so the are interpolated as
# such.
else
    roundup_clr=
    roundup_red=
    roundup_grn=
    roundup_mag=
fi

# Outputs a trimmed, highlighted trace taken given as the first argument.
roundup_trace() {
    printf "$1\n"                                |
    # Delete the first two lines that represent roundups execution of the
    # test function.  They are useless to the user.
    sed '1,2d'                                   |
    # Trim the two left most `+` signs.  They represent the depth at which
    # roundup executed the function.  They also, are useless and confusing.
    sed 's/^++//'                                |
    # Indent the output by 4 spaces to align under the test name in the
    # summary.
    sed 's/^\(.*\)$/    ! \1/'                   |
    # Highlight the last line to bring notice to where the error occurred.
    sed "\$s/\(.*\)/$roundup_mag\1$roundup_clr/"
}

roundup_pass() {
    printf "$roundup_grn [PASS] $roundup_clr\n"
}

roundup_fail() {
    printf "$roundup_red [FAIL] $roundup_clr\n"
}

roundup_isfunc() {
    [ "$(type -t "$1")" = function ] && true || false
}

roundup_cfunc() {
    if roundup_isfunc "$1"
    then
        printf "$1"
    else
        printf "true"
    fi
}

# Sandbox Test Runs
# -----------------

# The above checks guarantee we have at least one test.  We can now move through
# each specified test plan, determine it's test plan, and administer each test
# listed in a isolated sandbox.
for roundup_p in $roundup_plans
do
    # Create a sandbox, source the test plan, run the tests, then leave
    # without a trace.
    (
        # Add to overall test count.
        roundup_ntests=$(($roundup_ntests + 1))

        # Consider the description to be the `basename` of <plan> minus the
        # tailing -test.sh.
        roundup_desc=$(basename "$roundup_p" -test.sh)

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
            grep "^it_.*()" $roundup_p           |
            sed "s/\(it_[a-zA-Z0-9_]*\).*$/\1/g"
        )

        # We have the test plan and are in our sandbox with [roundup(5)][r5] defined.
        # Now we source the plan to bring it's tests into scope.
        . $roundup_p

        # Consider `before` and `after` usable if present
        roundup_before=$(roundup_cfunc before)
        roundup_after=$(roundup_cfunc after)

        # The plan has been sourced.  It it time to display the title.
        printf "$roundup_desc\n"

        # Determine the test plan and administer each test. Score as we go.  The
        # total grade will be determined once all suites pass.  Before each
        # test, turn off automatic failure on command error so we can handle it
        # as a test failure and not a script failure.
        for roundup_t in $roundup_plan
        do
            # Avoid executing a non-function by checking the name we have is, in
            # fact, a function.
            if roundup_isfunc $roundup_t
            then
                printf "  $roundup_t: "

                $roundup_before
                set +e
                # Set `-xe` before the `eval` in the subshell.  We want the test to
                # fail fast to allow for more accurate output of where things went
                # wrong but not in _our_ process because a failed test should not
                # immediately fail roundup.
                roundup_output=$( set -xe; (eval "$roundup_t") 2>&1 )
                roundup_result=$?
                set -e
                $roundup_after
            fi

            if [ "$roundup_result" -ne 0 ]
            then
                roundup_failed=$(($roundup_failed + 1))
                roundup_fail
                roundup_trace "$roundup_output"
            else
                roundup_passed=$(($roundup_passed + 1))
                roundup_pass
            fi
        done
    )
done

# Test Summary
# ------------

# Display the summary now that all tests are finished.
printf "=======================================\n"
printf "Tests:  %3d | " $roundup_ntests
printf "Passed: %3d | " $roundup_passed
printf "Failed: %3d"    $roundup_failed
printf "\n"
