#!/usr/bin/env bash
# https://docs.aws.amazon.com/cli/latest/reference/s3api/copy-object.html

function replace() {
    term=$1
    pattern=$2
    new=$3
    echo "${term//$pattern/$new}"
}

function listAllBuckets() {
    aws s3api list-buckets --query "Buckets[].Name"
}

function listObjectsByBucket() {
    bucket="$1"

    if [[ $MAX_ITEMS == 0 ]];
    then
        aws s3api list-objects --bucket "$bucket" --query "Contents[].Key"
    else
        aws s3api list-objects --bucket "$bucket" --query "Contents[].Key" --max-items $MAX_ITEMS
    fi
}

function setObjectMetadata() {
    bucket="$1"
    objectKey="$2"
    path="/$bucket/$objectKey"

    cmd="aws s3api copy-object --bucket $bucket --copy-source $path \
        --key $objectKey --metadata-directive REPLACE"

    for i in "${!HEADERS[@]}"
    do
        if [[ "${i^^}" == "CONTENT-DISPOSITION" ]];
        then
            cmd="${cmd} --content-disposition \"${HEADERS[$i]}\""
        else
            cmd="${cmd} --metadata '{\"$i\":\"${HEADERS[$i]}\"}'"
        fi
    done

    echo $cmd
}

function setObjectsByBucket() {
    bucket="$1"
    bucketSize=$2

    stdout=$(listObjectsByBucket "$bucket")
    stdout=$(replace "$stdout" "[\[|\]|\,|\"]" "")

    declare -a allObjects=($stdout)

    for j in ${!allObjects[@]};
    do
        cmd=$(setObjectMetadata "$bucket" ${allObjects[$j]})
        if [[ $APPLY == 1 ]];
        then
            if eval $cmd
            then
                echo $cmd >> "success.out"
                echo "[SUCCESS] Bucket $((i+1))/$bucketSize $bucket | Object $((j+1))/${#allObjects[@]}" >&2
            else
                echo $cmd >> "error.out"
                echo "[ERROR] Bucket $((i+1))/$bucketSize $bucket | Object $((j+1))/${#allObjects[@]}" >&2
            fi
        else
            echo $cmd >> "script.out"
            echo "[Script Generated] Bucket $((i+1))/$bucketSize $bucket | Object $((j+1))/${#allObjects[@]}" >&2
        fi
    done
}

if [[ $# == 0 ]];
then
    echo "$(cat HELP_setObjectMetadataOnS3.md)"
    exit 125
fi

APPLY=0
BUCKET=""
MAX_ITEMS=0
declare -A HEADERS=()

for arg in "$@"
do
    case $arg in
        -a|--apply)
        APPLY=1
        shift
        ;;
        -b=*|--bucket=*)
        KEY="${arg//=[^.]*}"
        BUCKET="${arg/$KEY=}"
        shift
        ;;
        -m=*|--max-items=*)
        KEY="${arg//=[^.]*}"
        MAX_ITEMS=${arg/$KEY=}
        shift
        ;;
        *=*)
        KEY="${arg//=[^.]*}"
        VALUE="${arg/$KEY=}"
        HEADERS+=(["$KEY"]="$VALUE")
        shift
        ;;
        -h=--help)
        KEY="${arg//=[^.]*}"
        VALUE="${arg/$KEY=}"
        HEADERS+=(["$KEY"]="$VALUE")
        shift
        ;;
        *)
        echo "$(cat HELP_setObjectMetadataOnS3.md)"
        exit 125
        ;;
    esac
done

if [[ "$BUCKET" == "" ]];
then
    STDOUT=$(listAllBuckets)
    STDOUT=$(replace "$STDOUT" "[\[|\]|\,|\"]" "")

    declare -a ALL_BUCKETS=($STDOUT)

    for b in ${!ALL_BUCKETS[@]};
    do
        echo "Bucket ${ALL_BUCKETS[$b]}"
        $(setObjectsByBucket "${ALL_BUCKETS[$b]}" ${#ALL_BUCKETS[@]})
    done
else
    echo "Bucket $BUCKET"
    $(setObjectsByBucket "$BUCKET" 1)
fi
