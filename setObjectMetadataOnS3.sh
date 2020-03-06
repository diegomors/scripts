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
    echo "Getting All Buckets From S3" >&2
    aws s3api list-buckets --query "Buckets[].Name"
}

function getBucketLength() {
    bucket="$1"
    echo "Getting Length of Bucket $bucket" >&2
    aws s3api list-objects --bucket $bucket --query "length(Contents[])"
}

function listObjectsByBucket() {
    bucket="$1"
    nextToken="$2"

    echo "Getting Objects From Bucket $bucket | Token: $nextToken" >&2

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

    cmd="aws s3api copy-object --bucket $bucket --acl public-read --copy-source $path \
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
    allBucketsCount=$2

    echo "Begin Process to Bucket $bucket" >&2

    bucketLength=$(getBucketLength $bucket)
    runSuccess=0
    runFail=0

    lastToken=""
    nextToken=""
    lastKey=""

    while :
    do
        folderPath="out/$(date +%+4Y-%m-%d/%H)"
        mkdir -p $folderPath

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
                    runSuccess=$((runSuccess+1))
                    echo "# $(date --iso-8601=seconds) | $bucket | [S:$runSuccess | E:$runFail]/$bucketLength | $nextToken" >> "$folderPath/success.out"
                    echo $cmd >> "$folderPath/success.out"
                    echo "[SUCCESS] Bucket $((i+1))/$allBucketsCount $bucket | Object [S:$runSuccess | E:$runFail]/$bucketLength" >&2
                else
                    runFail=$((runFail+1))
                    echo "# $(date --iso-8601=seconds) | $bucket | [S:$runSuccess | E:$runFail]/$bucketLength | $nextToken" >> "$folderPath/error.out"
                    echo $cmd >> "$folderPath/error.out"
                    echo "[ERROR] Bucket $((i+1))/$allBucketsCount $bucket | Object [S:$runSuccess | E:$runFail]/$bucketLength" >&2
                fi
            else
                runSuccess=$((runSuccess+1))
                echo "# $(date --iso-8601=seconds) | $bucket | $runSuccess/$bucketLength | $nextToken" >> "$folderPath/script.out"
                echo $cmd >> "$folderPath/script.out"
                echo "[Script Generated] Bucket $((i+1))/$allBucketsCount $bucket | Object $runSuccess/$bucketLength" >&2
            fi
        done

        if [[ "${nextToken}" == "${lastToken}" ]];
        then
            break
        else
            lastToken="$nextToken"
        fi
    done

    echo "End Process to Bucket $bucket" >&2
}

if [[ $# == 0 ]];
then
    echo "$(cat setObjectMetadataOnS3_HELP.md)"
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
        echo "$(cat setObjectMetadataOnS3_HELP.md)"
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
        # TODO: paralelizar execução por bucket com nohup
        $(setObjectsByBucket "${ALL_BUCKETS[$b]}" ${#ALL_BUCKETS[@]})
    done
else
    # TODO: paralelizar execução por bucket com nohup
    $(setObjectsByBucket "$BUCKET" 1)
fi
