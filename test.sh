#! /usr/bin/env bash

verbose=false
goflags=""
if [[ $1 = "-v" ]]; then
  verbose=true
  goflags="-v"
fi

# If we're outputting to a terminal, let's use color. Otherwise, don't.
if [ -t 1 ]; then
    KNRM="\x1B[0m"
    KRED="\x1B[31m"
    KGRN="\x1B[32m"
else
    KNRM=""
    KRED=""
    KGRN=""
fi

# Keep track of how many tests have failed.
let failed=0

function run_test() {
  local phase=$1
  local cmd=${@:2}

  echo "Running phase ${phase} tests..."

  if $verbose; then
    exec 3>&1; exec 4>&2
    ($cmd >&3 2>&4)
  else
    output=$($cmd)
  fi

  if [ $? -ne 0 ]; then
    let failed+=1
    echo -e ":: ${KRED}failed${KNRM}\n"
    if ! $verbose; then
      echo -e "${KRED}:: begin test output ::${KNRM}"
      echo "${output}"
      echo -e "${KRED}:: end test output ::${KNRM}"
    fi
  else
    echo -e ":: ${KGRN}success${KNRM}"
  fi

  echo ""
}

function build_run_bin() {
  local name=$1
  local inputs=${@:2}

  rm -f $output

  go build $name
  if [ $? -ne 0 ]; then
    echo "${name} failed to compile."
    exit 1
  fi

  ./${name} -s $inputs
  if [ $? -ne 0 ]; then
    echo "${name} exited unsuccessfully."
    exit 1
  fi
}

function check_output() {
  local name=$1
  local expected_name=$2
  local diff_cmd=${@:3}

  local output="data/output/mr.result.${name}"
  local expected="data/expected/${expected_name}-expected.txt"
  local diff="data/output/diff-${name}.out"

  # clean up all of the job's output except the final result
  rm -f data/output/mr.${name}*

  if ! [ -s "${output}" ]; then
    echo "${name} completed with no output. '${output}' is empty."
    exit 1
  fi

  rm -f $diff
  cat $output | eval $diff_cmd | diff - $expected > $diff
  if [ -s $diff ]; then
    echo "Failed test. Output should be as in ${expected}."
    echo "Your job's full output is in ${output}."
    echo "Your output differs as follows (found in ${diff}):"
    cat $diff | tail -n +2
    exit 1
  else
    rm -f $output
    rm -f $diff
  fi
}

function test_wc() {
  build_run_bin "wordcount" data/input/pg-*.txt
  check_output "wordcount" "wc" "sort -n -k2 | tail -10"
}

function test_ii() {
  build_run_bin "invertedindex" data/input/pg-*.txt
  check_output "invertedindex" "ii" \
    "sort -k1,1 | sort -snk2,2 | grep -v '16' | tail -10"
}

function test_pr() {
  build_run_bin "pagerank" data/input/pr-input-*.txt
  check_output "pagerank" "pr" "sort -k2,2 -srn | cut -c-13 | head -n 15"
}

run_test 1 go test mapreduce --cwd="$PWD" -run SequentialNoMerge $goflags
run_test 2 go test mapreduce --cwd="$PWD" -run FullSequential $goflags
#run_test 3 test_wc
#run_test 4 go test mapreduce --cwd="$PWD" -run Parallel $goflags
#run_test 5 test_ii
# run_test 6 test_pr # TODO: Uncomment me for extra credit phase.

if [ $failed -eq 0 ]; then
  echo -e "${KGRN}Unit tests completed successfully.${KNRM}"
else
  echo -e "${KRED}Unit testing failed.${KNRM}"
fi
