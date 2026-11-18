# Continuous Integration

This project uses GitHub Actions for continuous integration. The workflow is defined in `.github/workflows/ci.yml`.

## What's being tested and analyzed?

The CI process includes:
1. Running all RSpec tests
2. Running code style checks via RuboCop
3. Running security checks via Brakeman
4. Running best practices checks via Rails Best Practices
5. Checking for missing annotations
6. Linting Dockerfiles
7. Building Docker images
8. Verifying the committed API documentation

## CI Setup Requirements

The CI will automatically run tests and generate coverage reports.

## Parallelization with Parallel Tests & Knapsack

Knapsack and Parallel Tests gems allow us to run tests in several nodes at the same time, benefiting us in the execution time. Knapsack parallelizes them at node level while Parallel Tests does it at CPU level.

Knapsack splits tests based on an execution time report. In case there are files that were not added in the report, they will all run on the same node and may overload it, so it is strongly recommended to update the report frequently.

## Configuration
In case you want to use this you will need the script that splits spec files called `parallel_tests`, which sets up the configuration, assuming you have `n_nodes * cpu_cores_quantity`.

On Github Actions you can add any nodes you want using matrix strategy, setting up some variables:

```sh
  ci_node_total: [4]
  # set N-1 indexes for parallel jobs
  # When you run 2 parallel jobs then first job will have index 0, the second job will have index 1 etc
  ci_node_index: [0, 1, 2, 3]
```

CPU cores quantity on every node are obtained automatically from Github Actions config `echo "cpu_cores=$(nproc)" >> $GITHUB_ENV`.

If you want to update it manually you can do it by updating this variable:
`PARALLEL_TESTS_CONCURRENCY: 2`

To update tests on local machine you can execute `KNAPSACK_CI_NODE_TOTAL=4 KNAPSACK_CI_NODE_INDEX=1 PARALLEL_TESTS_CONCURRENCY=2 bundle exec parallel_rspec -n 2 -e './bin/parallel_tests'`. This will run subset of tests files corresponding to second node.

## Generating report
Knapsack report needs to be updated frequently to balance execution time among nodes. This can be done manually by executing:
`KNAPSACK_GENERATE_REPORT=true bundle exec rspec`

It is also recommended to generate the report in the CI for a better precision. For this you have available a workflow in Github Actions that triggers the report generation and creates a pull request automatically. This workflow can be scheduled in the frequency you want or even can be manually triggered.

To schedule the cron task you have to do it in `.github/workflows/update_knapsack_report.yml:6`
It is now scheduled for February 31 so will never run.

```sh
  - cron: '0 5 31 2 *'
  # The above cron does not run. Replace with the wanted periodicity.
```

If the branch exists or the PR is already created the workflow will fail.
In your repository settings -> actions -> general ->  Workflow permissions we need to allow read / write permissions and mark the option allow Github action to create PR, other case the workflow will fail.

## Coverage and API documentation

Each test node uploads its coverage report as a workflow artifact. CI builds the production image and starts the development stack to check its HTTP status endpoint. The API request specs also generate a fresh OpenAPI contract for comparison with the committed document.
