# Contributing to debhelper

Thanks for your interest in improving debhelper.

No matter how you identify yourself or how others perceive you: we
welcome you. We welcome contributions from you as long as they
interact constructively with our community.  See also [Code of
Conduct, Social rules and conflict
resolution](#code-of-conduct-social-rules-and-conflict-resolution).

This document will cover what you need to get started on working with
debhelper, where to submit patches or contributions and what we expect
from contributors.


## Getting started

<a id="getting-starting"></a>

This section helps you get started with working on debhelper.  It
assumes you are comfortable with `git`.

First clone the debhelper git repository and install build-dependencies:

    git clone https://salsa.debian.org/debian/debhelper.git
    cd debhelper
    apt-get build-dep ./
    # Used for running the test suite
    apt-get install perl

Running the test suite:

    # Available from the perl package.
    prove -lr -j`nproc` t


Doing a test build / release build of debhelper:

    # Consider doing it in a chroot to verify that the Build-Depends are correct.
    dpkg-buildpackage -us -uc
    # installing it for further testing
    apt-get install ../debhelper_<version>_all.deb


Please have a look at `doc/PROGRAMMING`, which have guidelines for
debhelper code.


## Balancing simplicity, ease-of-use, performance, etc.

At times, there are conflicting wishes for debhelper.  We cannot
satisfy all requirements and we sometimes have to say no thanks to a
particular change because it conflicts with design goal, or if it is
better suited in a different project, etc.

Here are some guidelines that may be useful:

 * New build systems or helpers that are language/framework specific
   or have a narrow scope are generally better shipped in a separate
   package.  If the scope becomes more general, the tooling can be
   merged in to debhelper at a later stage.

   * Examples: Most `dh-*` packages in Debian are examples of this.

 * Changes that affect performance considerably generally must only
   affect packages that need them and only affect a limited subset of
   packages and a limited subset of `dh_*`-tools.  Particularly, be
   careful of `Dpkg::*`-modules, which tend to have very high load
   costs.

 * Helpers / tools should generally *do the right thing* by default
   (subject to backwards compatibility).  If most people neeed some
   particular option to make the tool work for them, then the default
   should be changed (again, subject to backwards compatibility).


## Handling backwards compatibility for consumers

While changes in debhelper should avoid breaking consumers, some times
we need to implement a backwards incompatible change (e.g. to improve
defaults to match the current packaging norms or fix a bug).

  * For non-trivial breakage, we use compat bumps and migrate to the new
    functionality by default in the new major version of debhelper.
    (see the `compat` function)

  * For trivial issues or (mostly) unused functionality/bugs, then we
    can make exceptions.  Preferably, have all consumers migrate away
    from the feature being changed (in Debian `unstable`) before
    applying it.

Note that we tend to support compat levels for a long time (10+
years).  When changing behaviour via a compat bump, please take an
extra look to ensure the change is sufficient (this is easier said
than done).  See `doc/SUPPORT-POLICY` for more information.

## Debian support baseline for debhelper

The debhelper project aims to support the Debian `unstable`,
`testing`, and `stable-backports` suites by default.  For this to work,
we work based on the following guidelines:

  1) it should be trivial to use/Build-Depend on debhelper in
     `stable-backports`, and
  2) the debhelper in `stable-backports` should behave the same as
     in `testing` when backporting a package from `testing`.

     * Note that we do not require feature/bug compatibility with
       debhelper in `stable` (as most packages will still use
       debhelper from `stable`).

In some cases, we can disable some *minor* functionality in
`stable-backports` (previous cases being `dbgsym` and `R³`).

Where possible, use versioned `Breaks` against other packages to
make it easier to support packages in `stable-backports`
(e.g. debhelper had a `Breaks` against `meson` to ensure packages
used a recent enough version of `meson` when using the debhelper
from `stretch-backports`).

## Submitting your contribution

We accept merge requests on [salsa.debian.org] and in general prefer
these to bug reports with patches.  This is because the merge requests
will run our CI to ensure the tests still pass.  When opening a merge
request, please consider allowing committers to edit the branch as
this enables us to rebase it for you.

However, we fully respect that not everyone may want to sign up on a
Debian service (e.g. it might be a steep overhead for a one-time
contribution).  Therefore, we also accepts bug reports against the
debhelper package in Debian with either patches (`git format-patch`
format preferred) or links to public git repositories with reference
to branches.  Please see [Submitting a bug
report](#submitting-a-bug-report) for the guide on how to do that.

Please see [getting started](#getting-started) for how to obtain the
source code and run the test suite.

[salsa]: https://salsa.debian.org/debian/debhelper


## Submitting a bug report

If you want to submit a bug report against debhelper, please see
[https://www.debian.org/Bugs/Reporting]() for how to report the bug in the
Debian bug tracker (please file it against the `debhelper` package).

Users of Debian can use `reportbug debhelper` if they have the
reportbug tool installed.

You can find the list of open bugs against debhelper at:
[https://bugs.debian.org/src:debhelper]().


## Code of Conduct, Social rules and conflict resolution

The debhelper suite is a part of Debian. Accordingly, the Code of
Conduct, Social rules and conflict resolution from Debian applies to
debhelper and all of its contributors.

As a guiding principle, we strive to have an open welcoming community
working on making Debian packaging easier.  Hopefully, this will be
sufficient for most contributors.  For more details, please consider
reading (some) of the documents below.


 * [Debian's Code of Conduct](https://www.debian.org/code_of_conduct)

   * If you feel a contributor is violating the code of contact, please
     contact the [Debian anti-harassment team](https://wiki.debian.org/AntiHarassment)
     if you are uncomfortable with engaging with them directly.

 * [Debian's Diversity Statement](https://www.debian.org/intro/diversity)

   * Note that `interact constructively with our community` has the
     implication that contributors extend the same acceptance and
     welcome to others as they can expect from others based on the
     diversity statement.

   * The rationale for this implication is based on the
     [Paradoc of tolerance](https://en.wikipedia.org/wiki/Paradox_of_tolerance).
     

 * [Debian's Social Contract and Free Software Guidelines](https://www.debian.org/social_contract).

 * (very optional read) [Debian's Constitution](https://www.debian.org/devel/constitution).

   * The primary point of importance from this document is the
     debhelper project is subject the Debian's technical committee and
     the Debian General Resolution (GR) process.  These
     bodies/processes can make decisions that the debhelper project
     must follow.  Notably, the GR process is used for updating the
     Debian documents above.
