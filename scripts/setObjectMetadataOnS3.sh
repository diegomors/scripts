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
    aws s3api list-objects --bucket "$bucket" --query "Contents[].Key" --max-items 1
}

function setObjectMetadata() {
    bucket="$1"
    objectKey="$2"
    path="/$bucket/$objectKey"

    CMD="aws s3api copy-object --bucket $bucket --copy-source $path \
        --key $objectKey --metadata-directive REPLACE"

    for i in "${!HEADERS[@]}"
    do
        if [[ "${i^^}" == "CONTENT-DISPOSITION" ]];
        then
            CMD="${CMD} --content-disposition \"${HEADERS[$i]}\""
        else
            CMD="${CMD} --metadata '{\"$i\":\"${HEADERS[$i]}\"}'"
        fi
    done

    echo $CMD
}

function setObjectsByBucket() {
    bucket="$1"
    bucketSize=$2

    STDOUT=$(listObjectsByBucket "$bucket")
    STDOUT=$(replace "$STDOUT" "[\[|\]|\,|\"]" "")

    declare -a allObjects=($STDOUT)

    for j in ${!allObjects[@]};
    do
        CMD=$(setObjectMetadata "$bucket" ${allObjects[$j]})
        if [[ $APPLY == 1 ]];
        then
            if eval $CMD
            then
                echo $CMD >> "success.out"
                echo "[SUCCESS] Bucket $((i+1))/$bucketSize $bucket |\
                    Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}" >&2
            else
                echo $CMD >> "error.out"
                echo "[ERROR] Bucket $((i+1))/$bucketSize $bucket |\
                    Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}" >&2
            fi
        else
            echo $CMD >> "script.out"
            echo "[Script Generated] Bucket $((i+1))/$bucketSize $bucket |\
                Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}" >&2
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
declare -A HEADERS=()

for i in "$@"
do
    case $i in
        -a|--apply)
        APPLY=1
        shift
        ;;
        -b=*|--bucket=*)
        KEY="${i//=[^.]*}"
        BUCKET="${i/$KEY=}"
        shift
        ;;
        *=*)
        KEY="${i//=[^.]*}"
        VALUE="${i/$KEY=}"
        HEADERS+=(["$KEY"]="$VALUE")
        shift
        ;;
        -h=--help)
        KEY="${i//=[^.]*}"
        VALUE="${i/$KEY=}"
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
    _STDOUT=$(listAllBuckets)
    _STDOUT=$(replace "$_STDOUT" "[\[|\]|\,|\"]" "")

    declare -a ALL_BUCKETS=($_STDOUT)

    for i in ${!ALL_BUCKETS[@]};
    do
        echo $(setObjectsByBucket "${ALL_BUCKETS[$i]}" ${#ALL_BUCKETS[@]})
    done
else
    echo $(setObjectsByBucket "$BUCKET" 1)
fi
