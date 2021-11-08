Helm Chart Release
====================================================

# Chart Releaser

 The [chart-releaser](https://github.com/helm/chart-releaser) is being used to enable the pulsar-helm-chart [repo](https://github.com/datastax/pulsar-helm-chart) to self-host Helm Chart releases via the use of Github pages.

# CircleCI

CircleCI is being used to release a new version of the DataStax Pulsar Helm Charts. The [release script](https://github.com/datastax/pulsar-helm-chart/blob/master/.circleci/release.sh) creates a release package of the new Helm Chart version and updates the [index.yaml](https://datastax.github.io/pulsar-helm-chart/index.yaml) which in this case is hosted in a Github page. The CircleCI is triggered, when a new commit is pushed in the **release** branch.

# How to Release a new Version

The release process is automated using CircleCI. It uses the [chart-releaser](https://github.com/helm/chart-releaser) tool.

For a new Helm Chart release the version of the Helm Chart needs to be updated in the *Chart.yaml*. Do this for each chart that has changed and commit to **release**. This is important. If you don't change the version and the chart has changed, the release process will fail.

To trigger a release:
```
git fetch
git checkout release
git merge origin/master
```

Now update the versions in the *Chart.yaml* for each chart that has changed. Then push the change to origin:

```
git add .
git commit -m "Updating versions"
git push origin release
```

The chart-releaser tool will handle the packaging of the new version, will push it to the Github repo as a new [release](https://github.com/datastax/pulsar-helm-chart/releases). Then you have to manually edit the release adding the release notes by clicking on the `Auto-generate release notes` button. 

Later it will update the index.yaml file for the Helm repo and commit it to **master** since this is where the GitHub pages are hosted. 

If you see an error like this from the release script:

```
Error: error creating GitHub release: POST https://api.github.com/repos/datastax/pulsar-helm-chart/releases: 422 Validation Failed [{Resource:Release Field:tag_name Code:already_exists Message:}]
```

It is likely becuase one of the Helm charts has changed but the version number was not increased. All the changed charts will be listed in the logs of the release script. Bump the missing versions and commit to the release branch.

You should verify that the new chart version are present in the index.yaml:

https://datastax.github.io/pulsar-helm-chart/index.yaml

Also confirm that **master** has been updated with the new versions in the Chart.yaml files.



# How to Install a New Release

The *index.yaml* is hosted in a Github page and can be accessed via https://datastax.github.io/pulsar-helm-chart/. In order to make use of a DataStax Pulsar Helm Chart specific version the DataStax Helm repo should be added first by running:

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
