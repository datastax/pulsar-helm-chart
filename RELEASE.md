Helm Chart Release
====================================================

# Chart Releaser

 The [chart-releaser](https://github.com/helm/chart-releaser) is being used to enable the pulsar-helm-chart [repo](https://github.com/datastax/pulsar-helm-chart) to self-host Helm Chart releases via the use of GitHub pages.

# GitHub Actions

GitHub Actions are used to release a new version of the DataStax Pulsar Helm Charts. The [release action](.github/workflows/release.yaml) creates a release package of the new Helm Chart version and updates the [index.yaml](https://datastax.github.io/pulsar-helm-chart/index.yaml) which in this case is hosted in a GitHub page. The GitHub Action is triggered, when a new commit is pushed to the `master` branch, and a release is performed any time the chart releaser detects a version change.

Note: we switched from CircleCI to GitHub Actions because actions have a token integration which allows us to easily supply a token scoped to the project.

# How to Release a new Version

Before releasing the new version, verify that the most recent Circle CI tests have passed on the master branch. Then, update the version in the *Chart.yaml* for each chart that has changed. Push the changes to the master branch.
```
git add .
git commit -m "Release version x.y.z"
git push origin master
```

The release is then automatically triggered. It uses the [chart-releaser-action](https://github.com/helm/chart-releaser-action) which in turn uses the [chart-releaser](https://github.com/helm/chart-releaser) tool.

We configure the action in the [release.yaml](.github/workflows/release.yaml), and we configure the chart release in the [cr.yaml](cr.yaml).

The chart-releaser tool will handle the packaging of the new version, will push it to the GitHub repo as a new [release](https://github.com/datastax/pulsar-helm-chart/releases). The release notes should be auto generated. Read through them to verify their correctness.

Later it will update the index.yaml file for the Helm repo and commit it to **master** since this is where the GitHub pages are hosted. If this step fails, it is necessary to manually update the file, which can be done using the `cr` tool. Here is a sample script for working around the error:

```shell
mkdir .cr-release-packages/
mv ~/Downloads/pulsar-3.1.0.tgz .cr-release-packages/
cr index -o datastax -r pulsar-helm-chart
```

Then commit the updated index.yaml file.

If you see an error like this from the release script:

```
Error: error creating GitHub release: POST https://api.github.com/repos/datastax/pulsar-helm-chart/releases: 422 Validation Failed [{Resource:Release Field:tag_name Code:already_exists Message:}]
```

It is likely because one of the Helm charts has changed but the version number was not increased. All the changed charts will be listed in the logs of the release script. Bump the missing versions and commit to the release branch.

You should verify that the new chart version are present in the index.yaml:

https://datastax.github.io/pulsar-helm-chart/index.yaml

Also confirm that **master** has been updated with the new versions in the Chart.yaml files.

# How to Install a New Release

The *index.yaml* is hosted in a GitHub page and can be accessed via https://datastax.github.io/pulsar-helm-chart/. In order to make use of a DataStax Pulsar Helm Chart specific version the DataStax Helm repo should be added first by running:

```bash
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
```

And then a version of the preferred chart can be installed by running:

```bash
helm install --namespace pulsar datastax-pulsar/pulsar --version <version_number>
```
Or for Helm3:

```
helm3 install <name> --namespace pulsar --version <version_number> datastax-pulsar/pulsar
```

For example:


```bash
helm install --namespace pulsar --repo https://datastax.github.io/pulsar-helm-chart pulsar --version v1.0.3
```

If no Helm Chart version is specified the latest version will be installed.
