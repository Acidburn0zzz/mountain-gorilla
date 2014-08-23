#!/bin/bash
#
# This script lives at <mountain-gorilla.git/tools/jenkins-build-step.sh>.
# A suggested jenkins build step for an MG component or full SDC build.
#
# See the appropriate jenkins job for the *actual* current build steps:
#   https://jenkins.joyent.us/job/$JOB/configure
#

set -o errexit
unset LD_LIBRARY_PATH   # ensure don't get Java's libs (see OS-703)


echo ""
echo "#---------------------- params"
start_time=$(date +%s)
last_time=${start_time}

# If "payload" is defined, we presume this is from a post-receive hook.
# `payload.ref` will defined the git branch. For "release-YYYYMMDD" branches
# (the Joyent engineering convention for release branches) we'll be strict
# and have:
#   TRY_BRANCH=  BRANCH=$branch
# but for other branches we'll be "nice" and use
#   TRY_BRANCH=$branch  BRANCH=master
# which allows, for example, a commit to a feature branch (say "foo") to
# work when ancillary repos (like mountain-gorilla.git and usb-headnode.git)
# don't have that branch.
if [[ -n "$payload" ]]; then
    ref=$(echo "$payload" | json ref)
    if [[ $(echo "$ref" | cut -d/ -f2) != "heads" ]]; then
        echo "error: unexpected ref '$ref': is not 'refs/heads'"
        exit 1
    fi
    BRANCH=$(echo "$ref" | cut -d/ -f3)
    if [[ -z "$(echo $BRANCH | egrep '^release-[0-9]+' || true)" ]]; then
        TRY_BRANCH=$BRANCH
        BRANCH=master
    fi
fi
if [[ -z "$BRANCH" ]]; then
    BRANCH=master
fi
echo "BRANCH: $BRANCH"
echo "TRY_BRANCH: $TRY_BRANCH"


echo ""
echo "#---------------------- mg"

rm -rf MG.last
# Poorman's backup of last build run.
mkdir -p MG && mv MG MG.last
rm -rf MG
git clone git@git.joyent.com:mountain-gorilla.git MG
cd MG
if [[ -n "$TRY_BRANCH" ]]; then
    git checkout $TRY_BRANCH || git checkout $BRANCH
else
    git checkout $BRANCH
fi

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: clone MG took ${elapsed} seconds"

LOG=build.log
touch $LOG
exec > >(tee ${LOG}) 2>&1



echo ""
echo "#---------------------- env"

date
pwd
whoami
env



echo ""
echo "#---------------------- configure"

[[ -z "$BRANCH" ]] && BRANCH=master
# Note the "-c" to use a cache dir one up, i.e. shared between builds of this job.
CACHE_DIR=$(cd ../; pwd)/cache
if [[ "$CLEAN_CACHE" == "true" ]]; then
    rm -rf $CACHE_DIR
fi
if [[ "$JOB_NAME" == "sdc" ]]; then
    TRACE=1 ./configure -j -c "$CACHE_DIR" -b "$BRANCH" -B "$TRY_BRANCH"
else
    TRACE=1 ./configure -j -t $JOB_NAME -c "$CACHE_DIR" -b "$BRANCH" -B "$TRY_BRANCH"
fi

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: MG configure took ${elapsed} seconds"



echo ""
echo "#---------------------- make"

if [[ "$JOB_NAME" == "sdc" ]]; then
    gmake
else
    gmake $JOB_NAME
fi

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: build took ${elapsed} seconds"



echo ""
echo "#---------------------- upload"

cp $LOG bits/$JOB_NAME/
gmake manta_upload_jenkins
gmake jenkins_publish_image

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: upload took ${elapsed} seconds"
