#!/usr/bin/env bash
# https://docs.aws.amazon.com/cli/latest/reference/s3api/copy-object.html
# https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingMetadata.html#object-metadata

function replace() {
    term=$1
    pattern=$2
    new=$3
    echo "${term//$pattern/$new}"
    return 1
}

function listAllBuckets() {
    aws s3api list-buckets --query "Buckets[].Name"
}

function listObjectsByBucket() {
    bucket=$1

    aws s3api list-objects --bucket $bucket --query 'Contents[].Key'
}

function setObjectMetadata() {
    bucket=$1
    objectKey=$2
    path="/$bucket/$objectKey"
    headerKey=$3
    headerValue=$4

    echo "aws s3api copy-object --bucket $bucket --copy-source $path --key $objectKey \
    --metadata-directive REPLACE --metadata '{\"$headerKey\":\"attachment; filename='$headerValue'\"}'"

    '{"$headerKey":"attachment; filename='\"'$headerValue\""}'
}

STDOUT=$(listAllBuckets)
STDOUT=$(replace "$STDOUT" "[\[|\]|\,|\"]" "")

declare -a allBuckets=($STDOUT)

for i in ${!allBuckets[@]}; do

   STDOUT=$(listObjectsByBucket ${allBuckets[$i]})
   STDOUT=$(replace "$STDOUT" "[\[|\]|\,|\"]" "")
   declare -a allObjects=($STDOUT)
   for j in ${!allObjects[@]}; do
       CMD=$(setObjectMetadata ${allBuckets[$i]} ${allObjects[$j]} "$1" "$2")
       if [[ $3 == "--apply" ]];
       then
           if eval $CMD
           then
               echo $CMD >> "success.out"
               echo "[SUCCESS] Bucket $((i+1))/${#allBuckets[@]} ${allBuckets[$i]} |\
                Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}"
           else
               echo $CMD >> "error.out"
               echo "[ERROR] Bucket $((i+1))/${#allBuckets[@]} ${allBuckets[$i]} |\
                Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}"
           fi
       else
           echo $CMD >> "script.out"
           echo "Script Generated >> Bucket $((i+1))/${#allBuckets[@]} ${allBuckets[$i]} |\
            Object $((j+1))/${#allObjects[@]} ${allObjects[$j]}"
       fi
   done

done
