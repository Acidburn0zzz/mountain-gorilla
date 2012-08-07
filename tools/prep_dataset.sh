#!/bin/bash
# vi: expandtab sw=2 ts=2
#
# "Prepare a dataset." 
#
# This is called for "appliance" image/dataset builds to: (a) provision
# a new zone of a given image, (b) drop in an fs tarball and
# optionally some other tarballs, and (c) make an image out of this.
#
# This uses a "gzhost" on which to create a new zone for the image
# build. One of the hosts in "gzhosts.json" is chosen at random.
# 

export PS4='${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
if [[ -z "$(echo "$*" | grep -- '-h' || /bin/true)" ]]; then
  # Try to avoid xtrace goop when print help/usage output.
  set -o xtrace
fi
set -o errexit



#---- globals, config

JSON="tools/json"

# The host on which we build the output image/dataset.
gzhost=""

# UUID of the created image/dataset.
uuid=""

image_uuid=""
tarballs=""
packages=""
output=""



#---- functions

function fatal {
  echo "$(basename $0): error: $1"
  exit 1
}

function cleanup() {
  local exit_status=${1:-$?}
  if [[ -n $gzhost ]]; then
    SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${gzhost}"
    if [[ -n "$uuid" ]]; then
      echo ${SSH} "vmadm stop -F ${uuid} ; vmadm destroy ${uuid}"
    fi
  fi
  exit $exit_status
}

function usage() {
    if [[ -n "$1" ]]; then
        echo "error: $1"
        echo ""
    fi
    echo "Usage:"
    echo "  prep_dataset.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h              Print this help and exit."
    echo "  -i IMAGE_UUID   The base image UUID."
    echo "  -t TARBALL      Space-separated list of tarballs to unarchive into"
    echo "                  the new image. A tarball is of the form:"
    echo "                    TARBALL-ABSOLUTE-PATH-PATTERN[:SYSROOT]"
    echo "                  The default 'SYSROOT' is '/'. A '/' sysroot is the"
    echo "                  typical fs tarball layout with '/root' and '/site'"
    echo "                  base dirs. This can be called multiple times for"
    echo "                  more tarballs."
    echo "  -p PACKAGES     Space-separated list of pkgsrc package to install."
    echo "                  This can be called multiple times."
    echo "  -o OUTPUT       Image output path. Should be of the form:"
    echo "                  '/path/to/name.zfs.bz2'."
    echo "  -v VERSION      Version for produced image manifest. Default"
    echo "                  to '0.0.0'."
    echo "  -u URN          URN for produced image manifest. Defaults"
    echo "                  to 'sdc:sdc:$output_basename:$version'."
    echo ""
    echo "  -s GZSERVERS    DEPRECATED. Don't see this being used."
    echo ""
    exit 1
}




#---- mainline

trap cleanup ERR

while getopts ht:p:i:o:u:v: opt; do
  case $opt in
  h)
    usage
    ;;
  t)
    if [[ -n "${OPTARG}" ]]; then
      tarballs="${tarballs} ${OPTARG}"
    fi
    ;;
  p)
    if [[ -n "${OPTARG}" ]]; then
      packages="${packages} ${OPTARG}"
    fi
    ;;
  i)
    image_uuid=${OPTARG}
    ;;
  o)
    output=$OPTARG
    ;;
  u)
    urn=$OPTARG
    ;;
  v)
    version=$OPTARG
    ;;
  \?)
    echo "Invalid flag"
    exit 1;
  esac
done

if [[ -z ${output} ]]; then
  fatal "No output file specified. Use '-o' option."
fi

if [[ -z $version ]]; then
  version="0.0.0"
fi

if [[ -z "$image_uuid" ]]; then
  fatal "No image_uuid provided. Use the '-i' option."
fi

if [[ -z $urn ]]; then
  urn=${output%.bz2}
  urn="sdc:sdc:${urn%.zfs}:${version}"
fi

ofbzip=$(echo ${output} | grep ".bz2$" || /bin/true )

if [[ -n $ofbzip ]]; then
  dobzip="true"
  output=${output%.bz2}
fi

host=$(cat gzhosts.json | json  $(($RANDOM % `cat gzhosts.json | ./tools/json length`)) )
gzhost=$(echo ${host} | json hostname)

echo "Using gzhost ${gzhost}"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${gzhost}"

# hack to fix our lab's DHCP
mac="c0:ff:ee:$(openssl rand -hex 1):$(openssl rand -hex 1):$(openssl rand -hex 1)"

echo "{
  \"brand\": \"joyent-minimal\",
  \"zfs_io_priority\": 10,
  \"quota\": 10000,
  \"ram\": 1024,
  \"max_physical_memory\": 1024,
  \"nowait\": true,
  \"image_uuid\": \"${image_uuid}\",
  \"alias\": \"temp_image.$$\",
  \"hostname\": \"temp_image.$$\",
  \"dns_domain\": \"lab.joyent.dev\",
  \"resolvers\": [
    \"8.8.8.8\"
  ],
  \"autoboot\": true,
  \"nics\": [
    {
      \"nic_tag\": \"admin\",
      \"ip\": \"dhcp\",
      \"mac\": \"${mac}\"
    }
  ]
}" | $SSH "vmadm create"

uuid=$(${SSH} "vmadm list -p -o uuid,alias | grep temp_image.$$ | cut -d ':' -f 1")
echo "Created build zone ${uuid}"


# "tarballs" is a list of:
#   TARBALL-ABSOLUTE-PATH-PATTERN[:SYSROOT]
# e.g.:
#   /root/joy/mountain-gorilla/bits/amon/amon-agent-*.tgz:/opt
for tb_info in $tarballs; do
  tb_tarball=$(echo "$tb_info" | awk -F':' '{print $1}')
  tb_sysroot=$(echo "$tb_info" | awk -F':' '{print $2}')
  [[ -z "$tb_sysroot" ]] && tb_sysroot=/

  bzip=$(echo $tb_tarball | grep "bz2$" || /bin/true)
  if [[ -n ${bzip} ]]; then
    uncompress=bzcat
  else
    uncompress=gzcat
  fi

  echo "Copying tarball '${tb_tarball}' to zone '${uuid}'."
  if [[ "$tb_sysroot" == "/" ]]; then
    # Special case: for tb_sysroot == '/' we presume these are fs-tarball
    # style tarballs with "/root/..." and "/site/...". We strip
    # appropriately.
    cat ${tb_tarball} | ${SSH} "zlogin ${uuid} 'cd / ; ${uncompress} | gtar --strip-components 1 -xf - root'"
  else
    cat ${tb_tarball} | ${SSH} "zlogin ${uuid} 'cd ${tb_sysroot} ; ${uncompress} | gtar -xf -'"
  fi
done

##
# install packages
if [[ -n "${packages}" ]]; then
  echo "Installing these pkgsrc package: '${packages}'"

  echo "Need to wait for an IP address..."
  count=0
  IP_ADDR=$(${SSH} "zlogin ${uuid} 'ipadm show-addr -p -o addrobj,addr | grep net0 | cut -d : -f 2 | xargs dirname'")
  until [[ -n $IP_ADDR && $IP_ADDR != '.' ]]
  do
    if [[ $count -gt 10 ]];  then
      echo "**Could not acquire IP address**"
      cleanup
      exit 1
    fi
      sleep 5
      IP_ADDR=$(${SSH} "zlogin ${uuid} 'ipadm show-addr -p -o addrobj,addr | grep net0 | cut -d : -f 2 | xargs dirname'")
      count=$(($count + 1))
  done
  echo "IP address acquired: ${IP_ADDR}"

  ${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -f -y update'"
  ${SSH} "zlogin ${uuid} 'touch /opt/local/.dlj_license_accepted'"
  ${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -y in ${packages}'"

  echo "Validating pkgsrc installation"
  for p in ${packages}
  do
    echo "Checking for $p"
    PKG_OK=$(${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -y list | grep ${p}'")
    if [[ -z "${PKG_OK}" ]]; then
      echo "pkgin install failed (${p})"
      exit 1
    fi
  done

fi

#
# import smf manifests
${SSH} "zlogin ${uuid} '/usr/bin/find /opt/smartdc -name manifests -exec svccfg import {} \;'"

cat tools/clean-image.sh | ${SSH} "zlogin ${uuid} 'cat > /tmp/clean-image.sh; /usr/bin/bash /tmp/clean-image.sh; shutdown -i5 -g0 -y;'"

${SSH} "zfs snapshot zones/${uuid}@prep_dataset.$$ ; zfs send zones/${uuid}@prep_dataset.$$" | cat > ${output}

${SSH} "vmadm destroy ${uuid}"

if [[ -n $dobzip ]]; then
  bzip2 ${output}
  output=${output}.bz2
fi

timestamp=$(node -e 'console.log(new Date().toISOString())')
shasum=$(/usr/bin/sum -x sha1 ${output} | cut -d ' ' -f1)
size=$(/usr/bin/du -ks ${output} | cut -f 1)


cat <<EOF>> ${output%.bz2}.dsmanifest
  {
    "name": "${output%.zfs}",
    "version": "${version}",
    "type": "zone-dataset",
    "description": "${output}",
    "published_at": "${timestamp}",
    "os": "smartos",
    "files": [
      {
        "path": "${output}",
        "sha1": "${shasum}",
        "size": ${size},
        "url": "${output}"
      }
    ],
    "requirements": {
      "networks": [
        {
          "name": "net0",
          "description": "admin"
        }
      ]
    },
    "uuid": "${uuid}",
    "creator_uuid": "352971aa-31ba-496c-9ade-a379feaecd52",
    "vendor_uuid": "352971aa-31ba-496c-9ade-a379feaecd52",
    "creator_name": "sdc",
    "platform_type": "smartos",
    "cloud_name": "sdc",
    "urn": "${urn}:${version}",
    "created_at": "${timestamp}",
    "updated_at": "${timestamp}"
  }
EOF
