# Proposals

Collaborate on API changes to Swift Metrics by writing a proposal.

## Overview

For non-trivial changes that affect the public API, the Swift Metrics project adopts a lightweight version of the [Swift Evolution](https://github.com/apple/swift-evolution/blob/main/process.md) process.

Writing a proposal first helps you discuss multiple possible solutions early, apply useful feedback from other contributors, and avoid reimplementing the same feature multiple times.

Get feedback early by opening a pull request with your proposal, but also consider the complexity of the implementation when evaluating different solutions. For example, include a link to a branch containing a prototype implementation of the feature in the pull request description.

> Note: The goal of this process is to solicit feedback from the whole community around the project, and the project continues to refine the proposal process itself. Use your best judgment, and don't hesitate to propose changes to the proposal structure itself.

### Steps

1. Make sure there's a GitHub issue for the feature or change you would like to propose.
2. Duplicate the `SMT-NNNN.md` document and replace `NNNN` with the next available proposal number.
3. Link the GitHub issue from your proposal, and fill in the proposal.
4. Open a pull request with your proposal and solicit feedback from other contributors.
5. Once a maintainer confirms that the proposal is ready for review, we update the state accordingly. The review period is 7 days, and ends when one of the maintainers marks the proposal as Ready for Implementation, or Deferred.
6. Before merging the pull request, ensure an implementation is ready, either in the same pull request or in a separate one linked from the proposal.
7. A proposal becomes Approved once you merge the implementation and proposal PRs, and enable any feature flags unconditionally.

If you have any questions, ask in an issue on GitHub.

### Possible review states

- Awaiting Review
- In Review
- Ready for Implementation
- In Preview
- Approved
- Deferred

## Topics

- <doc:SMT-0001-task-local-metrics-factory>
- <doc:SMT-NNNN>
