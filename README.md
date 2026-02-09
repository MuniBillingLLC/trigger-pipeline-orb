# Trigger Pipeline Orb

[![CircleCI Build Status](https://circleci.com/gh/MuniBillingLLC/trigger-pipeline-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/MuniBillingLLC/trigger-pipeline-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/munibillingllc/trigger-pipeline-orb.svg)](https://circleci.com/developer/orbs/orb/munibillingllc/trigger-pipeline-orb) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/MuniBillingLLC/trigger-pipeline-orb/main/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

A fork of [`circleci/trigger-pipeline`](https://github.com/CircleCI-Public/trigger-pipeline-orb) with proper error handling. The upstream orb silently succeeds even when the CircleCI API returns errors, which can cause deployment failures to go unnoticed for hours. This fork fixes that.

## How This Fork Differs from `circleci/trigger-pipeline`

| Behavior | `circleci/trigger-pipeline` | This fork |
|---|---|---|
| API error responses (e.g. `{"message":"Pipeline not found."}`) | Exits 0 (green check) | Exits 1 (red failure) |
| Non-2xx HTTP status codes | Ignored | Exits 1 with error message |
| Missing pipeline ID in response | Ignored | Exits 1 with error message |
| `definition_id` format | Only checks non-empty | Validates UUID format before API call |
| `project_slug`, `token`, `branch`/`tag` | Only checks non-empty | Same (checks non-empty) |
| Shell error handling | No `set -e` | `set -euo pipefail` |
| Tag path `--argjson` | Broken (`--argjson "$PARAMETERS"`) | Fixed (`--argjson params "$PARAMETERS"`) |

### Drop-in replacement

This orb uses the same parameters as `circleci/trigger-pipeline`. To switch, change the orb reference:

```yaml
# Before
orbs:
  trigger-pipeline: circleci/trigger-pipeline@1.0.0

# After
orbs:
  trigger-pipeline: munibillingllc/trigger-pipeline-orb@0.0.1
```

No other changes are needed. All command and parameter names are identical.

## Usage

An easier method to trigger a pipeline from within a job in another pipeline. For complex software delivery processes, this can make it easier to manage the process or distribute ownership. It also allows customers who want to trigger downstream pipelines based on updates to a shared service, component, or library to trigger their pipelines after an update.

### Example

```yaml
version: 2.1

orbs:
  trigger-pipeline: munibillingllc/trigger-pipeline-orb@0.0.1

jobs:
  trigger-downstream:
    docker:
      - image: cimg/base:stable
    steps:
      - trigger-pipeline/trigger:
          project_slug: github/my-org/my-repo
          branch: main
          definition_id: $PIPELINE_DEFINITION_ID
          token: $CCI_TOKEN
          parameters: key1=value1,key2=value2
```

### Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `project_slug` | string | Yes | | The project slug (e.g. `github/my-org/my-repo`). Found on project settings. |
| `definition_id` | string | Yes | | Pipeline definition ID (UUID). Found on project settings. |
| `token` | string | Yes | | Name of the environment variable containing the PAT token for authentication. |
| `branch` | string | No | `""` | Branch to run the pipeline from. Not compatible with `tag`. |
| `tag` | string | No | `""` | Tag to run the pipeline from. Not compatible with `branch`. |
| `parameters` | string | No | `""` | Comma-separated `key=value` pipeline parameters. |

Either `branch` or `tag` must be provided.

### Error Handling

The command will fail (exit 1) in the following cases:

- **Pre-flight validation failures**: missing required parameters, invalid UUID format for `definition_id`, `jq` not installed
- **HTTP errors**: any non-2xx response from the CircleCI API
- **API error responses**: response body contains a `message` field (e.g. `{"message":"Pipeline not found."}`)
- **Missing pipeline ID**: successful HTTP status but no `id` field in the response

On success, the command logs the pipeline ID and number.

## Resources

[CircleCI Orb Registry Page](https://circleci.com/developer/orbs/orb/munibillingllc/trigger-pipeline-orb) - The official registry page of this orb for all versions, executors, commands, and jobs described.

[CircleCI Orb Docs](https://circleci.com/docs/orb-intro/#section=configuration) - Docs for using, creating, and publishing CircleCI Orbs.

### How to Contribute

We welcome [issues](https://github.com/MuniBillingLLC/trigger-pipeline-orb/issues) and [pull requests](https://github.com/MuniBillingLLC/trigger-pipeline-orb/pulls) against this repository!

### How to Publish An Update
1. Merge pull requests with desired changes to the main branch.
    - For the best experience, squash-and-merge and use [Conventional Commit Messages](https://conventionalcommits.org/).
2. Find the current version of the orb.
    - You can run `circleci orb info munibillingllc/trigger-pipeline-orb | grep "Latest"` to see the current version.
3. Create a [new Release](https://github.com/MuniBillingLLC/trigger-pipeline-orb/releases/new) on GitHub.
    - Click "Choose a tag" and _create_ a new [semantically versioned](http://semver.org/) tag. (ex: v1.0.0)
      - We will have an opportunity to change this before we publish if needed after the next step.
4.  Click _"+ Auto-generate release notes"_.
    - This will create a summary of all of the merged pull requests since the previous release.
    - If you have used _[Conventional Commit Messages](https://conventionalcommits.org/)_ it will be easy to determine what types of changes were made, allowing you to ensure the correct version tag is being published.
5. Now ensure the version tag selected is semantically accurate based on the changes included.
6. Click _"Publish Release"_.
    - This will push a new tag and trigger your publishing pipeline on CircleCI.
