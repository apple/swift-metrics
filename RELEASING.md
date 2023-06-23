# Release process 

Swift metrics follows a relatively simple release process, outlined below.

### Issue and PR management basics

The overall goal of Issue and Pull Request management is to allow referring to them in the future, and being able to 
consistently and easily find out in which release a certain issue was fixed.

- most work should have an associated GitHub issue, and a Pull Request resolving it should mark it so by e.g. using github's "resolves #1234" mechanism or otherwise make it clear which issue it resolves.
- when a PR is merged, the associated issue is closed and the issue is assigned to the milestone the change is going to be released in.

- if a pull request was made directly, and has no associated issue, the pull request is associated with the milestone instead.
  - do not assign both an issue _and_ pull request about the same ticket to the same milestone as it may be confusing why a similar sounding issue was "solved twice".

### Release process

Once it is decided that a release should be cut, follow these steps to make sure the release is nice and clean.

In our example let's consider we're cutting a release for the version `1.2.3`.

- check all outstanding PRs, if any can be merged right away for this release, consider doing so,
- make sure all recently closed PRs or issues have been assigned to the milestone (assign them to the milestone `1.2.3` if not already done),
- create the "next" release milestone, for example `1.2.4` (or `1.3.0` if necessary) and move remaining issues to is, 
  - this way these tickets are carried over to the "next" release and are a bit easier to find and prioritize.
- close the current milestone (`1.2.3`),
- pull and tag the current commit with `1.2.3` 
  - prefer signing your tag (`git tag -s`) so it can be confirmed who performed the release and the tag is trustworthy,
- push the tag,
- update and upload the documentation,
  - e.g. use jazzy to generate and push the documentation branch (TODO: more details here).
- finally, go to the GitHub releases page and [draft a new release](https://github.com/apple/swift-metrics/releases/new).