# Kaltura Platform Packages CI Project
See [Kaltura Install Packaging Project](https://github.com/kaltura/platform-install-packages) for the parent project.  

## Project Goal
The Continuous Integration system will be responsible for the automation of the following tasks:   

* Overall build of the [Kaltura platform packages](https://github.com/kaltura/platform-install-packages) against the master branch, release branches and approved pull-requests (for both nightly and stable releases).
* Pushing the packages to the install repositories.
* Perform a full Kaltura deployment on a test cluster.
* Perform automated testing of the installed server features via API calls and command line scripts, determining overall build stability for both clean install and version to version upgrades.
* Generate web-page build reports and email in case of fails.
* Distribute packaged/compiled API client libraries to respective language repositories.

## Why we need a CI system?
An automatic approach to the build, test and release process has many advantages, most prominently, it significantly reduces the time to release new packages and verifies that packages were fully tested before being used in production.
We’ve also listed some key advantages in our specific project -   

* Release more often, faster, and provide nightly builds for advanced platform testers.
* Ensure new commits do not break existing functionality on the master branch.
* Allow contributors to make changes and additions with a higher level of security, knowing pull-requests are tested as part of the whole system in production mode, before being merged.
* Provide elaborate platform test reports before entering official manual QA phase.

## CI Workflow
This will be the general flow of each CI run.   

#### Build Packages & Deploy to Install Repository

1. Versions of packages included in the new release will be updated in spec files.
1. Additional required steps for the upgrade [SQL alter scripts, additional token replacements, etc] will be added to the postinst according to need
1. The packages will be built
1. Packages are uploaded to the repository using an SSH key
1. Packages are distributed to Akamai

#### Deploy test clusters on AWS
Following successful build, AMI instances are launched via EC2 CLI API, and Kaltura will be deployed on them.    
All deployments will be done using self-signed SSL certificates.   

##### Clean scenario: clean images of the following structure:

* 2 fronts behind an HTTPs LB (a Linux machine running Apache configured to use the ProxyPass module)
* 1 Admin Console front
* 2 batch servers
* 2 sphinx servers
* 1 MySQL DB server (shall we also test replication?)

##### Upgrade scenario: images of the following roles with the previous version installed:

* 2 fronts behind an HTTPs LB (a Linux machine running Apache configured to use the ProxyPass module)
* 1 Admin Console front
* 2 batch servers
* 2 sphinx servers
* 1 MySQL DB server (shall we also test replication?)

#### Test and Report
Following successful deployment and upgrade of the Kaltura clusters, the test suites will be ran, and build & test reports will be generated.


## The Test Suites
**All API calls and apps will be loaded over SSL.**

The following test cases will be run in the following order, on each cluster deployment (both clean and upgrade).
Nightly testing should run a complete regression coverage via API client libs, verifying the stability of the latest MASTER branch.   

1. Verify that all relevant processes (Apache, MySQL, Sphinx, batch, memcache, monit) are up and running on all machines in the cluster
1. Verify that all processes and crons are properly configured to run after system restart
1. Verify HTTPs call redirects for start page, KMC, Admin Console and testme. Perform curl request (with redirect follow) to each of the URLs, and test the response returned as expected:
    1. https://[DOMAIN]/  --- Verify Start Page
    1. https://[DOMAIN]/api_v3/testme/  --- Verify TestMe Console Page
    1. https://[DOMAIN]/index.php/kmc  --- Verify KMC 
    1. https://[DOMAIN]/admin_console/  --- Verify Admin Console
1. Verify system restart behaviour (run 1 through 3 post restart)
1. Verify that processes (Apache, MySQL, Sphinx, batch, memcache) are being relaunched by monit after MANUAL kill (testing crash resurrection).
1. Verify new publisher account creation. Continue all following tests on this new partner account.
1. Test email logs for sent new publisher account activation email.
1. uiConf and file verifications - 
    1. Run through all the uiConfs in the database.
    1. For each uiConf, run through the uiConf object URLs AND inside the uiConf XML for all referenced file paths (swf, js, image files, etc.) and verify the existence of these files on disk.
1. Verify simple transcoding: Upload video, see complete transcoding flow finished successfully.
1. Verify fallback transcoding: Rename the ffmpeg symlink. Upload video, see complete transcoding flow finished successfully. Rename the ffmpeg symlink back.
1. Verify clipping and trimming API: Clip an entry, verify READY status on the newly created entry.
1. Run all client libraries and their respective unit-tests. (Get build & test script from Eran K)
1. Create a Local XML DropFolder, copy a file to the folder, test the file was successfully pulled in to Kaltura, transcoded and that the XML metadata exists.
1. Create a Remote Storage profile against an S3 Bucket, verify that content uploaded gets pushed to the S3 bucket.
1. Test Bulk Upload XML that includes custom metadata fields and thumbnails.
1. Check email notifications:
1. Setup email notifications for new entry event
1. Create a new Entry
1. Check mail logs to see if email was sent.
1. Analytics verification:
1. Run PhantomJS to play a video using the HTML5 player
1. Rotate logs and run Analytics crons
1. Check the report API to see the play count
1. Check the bandwidth report API to see bandwidth and storage counts
1. Verify KS Access Control:
1. Create an AC Profile with KS protection
1. Assign it to a Video Entry
1. Curl playManifest to that Entry without a KS, see that the video fails to return
1. Curl playManifest to that Entry WITH a valid sview KS, see that the video returns
1. Verify YouTube distribution (create profile, distribute entry, query for success)
1. Thumbnail API verification:
    1. *This test will have a stored prepared image to compare against*
    1. Clone the Fish Aquarium entry
    1. Call the thmbnail API for second 25 of the new entry
    1. Use ImageMagick to compare the returned image against the stored test imaged
    1. If diff returns exact - test passes
1. Verify Red5 is working -  http://exchange.nagios.org/directory/Plugins/Software/FMS-monitor/details
1. Verify Player - Use http://phantomjs.org/ to run base tests against player embed, playlist embed, thumbnail embed, and common player scenarios (play, pause, seek)


## The Reports
Setup a mailing list for people to subscribe for reports via email. 3 types of emails:

1. If RPM layer failed packaging - email subject: [PACKAGING_FAILED] Kaltura Release - {CORE.VERSION} - {BUILD.DATE}
1. If any of the core unit tests failed - email subject: [CORE_FAILED] Kaltura Release - {HEALTH.PERCENT} - {CORE.VERSION} - {BUILD.DATE}
1. If all tests passed successfully - email subject: [BUILD_READY] Kaltura Release - {CORE.VERSION} - {BUILD.DATE}

The body of the email will always be a full report of the test suite in the following table: 

| Test File     | Status        | Details                           |
|:-------------:|:-------------:|:---------------------------------:|
| test_xxx      | PASSED        |                                   |
| test_yyy      | PASSED        |                                   |
| test_zzz      | FAILED        | Output of what failed in the test |


#### Nightly

* Nightly packages are built and saved into the /nightly/ folder.
* Full test report available on a URL with the version-date combo.
* Overall health status of the build - percentage of fail/pass
* Per test, status (FAIL or PASS), and if failed, dump of error info.

#### Pre-QA-Release

* Pre-QA-Release packages are built and saved into the /release/ folder with respective release version and date.
* Full test report available on a URL with the version-date combo.
* Overall health status of the build - percentage of fail/pass
* Per test, status (FAIL or PASS), and if failed, dump of error info.

#### Release Ready: Distribution

* If Pre-QA-Release passes 100%, also distribute packaged/compiled client libraries to respective repositories: http://rubygems.org/ , https://www.npmjs.org/ , https://getcomposer.org/ https://pypi.python.org/ 

