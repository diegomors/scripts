#!/usr/bin/env bash
# https://docs.aws.amazon.com/cli/latest/reference/s3api/list-objects.html
# https://docs.aws.amazon.com/cli/latest/reference/s3api/copy-object.html

function replace() {
    term=$1
    pattern=$2
    new=$3
    echo "${term//$pattern/$new}"
}

function extract() {
    term=$1
    pattern=$2
    echo "$term" | grep -P "$pattern" -o
}

function listAllBuckets() {
    aws s3api list-buckets --query "Buckets[].Name"
}

function listObjectsByBucket() {
    bucket="$1"
    nextToken="$2"
    if [[ "${nextToken}" == "" ]];
    then
        aws s3api list-objects --bucket "$bucket" --query "{NextToken: NextToken, Key: Contents[].Key}" --max-items=$MAX_ITEMS
    else
        aws s3api list-objects --bucket "$bucket" --query "{NextToken: NextToken, Key: Contents[].Key}" --max-items=$MAX_ITEMS --starting-token $nextToken
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

    if [[ $APPLY == 1 ]];
    then
        echo "" > "success.out"
        echo "" > "error.out"
    else
        echo "" > "script.out"
    fi

    lastToken=""
    nextToken=""
    lastKey=""

    while :
    do
        declare -a allObjects=()

        stdout=$(listObjectsByBucket "$bucket" "$nextToken")

        props=$(extract "$stdout" "\"[^\"]+\"")
        props=$(replace "$props" "\"" "")

        while IFS= read -r line
        do
            case "$lastKey" in
                "NextToken")
                if [[ "$line" != "Key" ]];
                then
                    nextToken="$line"
                fi
                shift
                ;;
                "Key")
                if [[ "$line" != "NextToken" ]];
                then
                    allObjects+=("$line")
                fi
                shift
                ;;
            esac

            case "$line" in
                "NextToken"|"Key")
                lastKey="$line"
                shift
                ;;
            esac
        done < <(echo "$props")

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

        if [[ "${nextToken}" == "${lastToken}" ]];
        then
            break
        else
            lastToken="$nextToken"
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
MAX_ITEMS=1000
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
        echo "Getting Objects From Bucket ${ALL_BUCKETS[$b]}"
        $(setObjectsByBucket "${ALL_BUCKETS[$b]}" ${#ALL_BUCKETS[@]})
    done
else
    echo "Getting Objects From Bucket $BUCKET"
    $(setObjectsByBucket "$BUCKET" 1)
fi
