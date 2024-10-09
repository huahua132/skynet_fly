The Corpora of the OpenSSL Fuzzing Data
=======================================

This repository contains the OpenSSL fuzz regression testing data and
it is supposed to be used as a submodule of the main git repository
checkout.

The reason for the separation as a submodule is that there is a huge
number of files which would make cloning the main OpenSSL source code
repository too much resource-consuming.

Policy for Committing Changes
=============================

Patches to this repository must be submitted in form of pull requests
on the repository.

Additions of new fuzz corpora files require just one OTC member review
approval and it is not required to wait 24 hours after the approval
before merging the pull request.

Any other modifications to the repository require reviews from at
least one OTC member and one committer and after the pull request
is approved it must wait for 24 hours before it is merged.

License
=======

The fuzz corpora data is licensed under the same license as the main
source code, the Apache License 2.0, which means that you are free to
get and use it for commercial and non-commercial purposes as long as
you fulfill its conditions.

See the [LICENSE.txt](LICENSE.txt) file for more details.
