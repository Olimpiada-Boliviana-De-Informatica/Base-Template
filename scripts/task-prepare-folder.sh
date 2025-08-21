#git rm --cached -r .commons
#rm -rf .commons
#git submodule add --force git@github.com:Olimpiada-Boliviana-De-Informatica/task-commons.git .commons
#git rm --cached -r .commons
#git config -f .gitmodules --remove-section submodule..commons
#git add .gitmodules
#rm -rf .git/modules/.commons

prepare_folder() {

  cd tasks || exit

  for task_name in "$@"; do
    echo "Task: $task_name"
    mkdir -p "$task_name"
    cd "$task_name" || exit


    echo '  generating "checker" folder ...'
    mkdir -p checker
    cd checker || exit
    rm -rf Makefile
    ln -s ../../.commons/Makefile Makefile
    rm -rf testlib.h
    ln -s ../../.commons/testlib.h testlib.h
    cd .. || exit


    echo '  generating "gen" folder ...'
    mkdir -p gen
    cd gen || exit
    rm -rf Makefile
    ln -s ../../.commons/Makefile Makefile
    rm -rf testlib.h
    ln -s ../../.commons/testlib.h testlib.h
    if [ ! -f gen.cpp ]; then
      cat <<EOF > gen.cpp
#include "testlib.h"
#include <cstdio>

int main(int argc, char* argv[]) {
    registerGen(argc, argv, 1);

    int MIN_A = atoi(argv[1]);
    int MAX_A = atoi(argv[2]);

    int a = rnd.next(MIN_A, MAX_A);
    int b = rnd.next(MIN_A, MAX_A);

    printf("%d %d\n", a, b);

    return 0;
}
EOF
    fi
    if [ ! -f data ]; then
      cat <<EOF > data
@subtask samples
copy ../public/examples/0-01.in

@subtask subtask1
gen 1 100

@subtask subtask2
gen 1 10000
EOF
    fi
    cd .. || exit

    echo '  generating "grader" folder ...'
    mkdir -p grader


    echo '  generating "public" folder ...'
    mkdir -p public
    cd public || exit
    if [ ! -f files ]; then
      cat <<EOF > files
public examples/0-01.in
public examples/0-01.out
EOF
    fi
    mkdir -p examples
    cd examples || exit
    if [ ! -f 0-01.in ]; then
      cat <<EOF > 0-01.in
1 1
EOF
    fi
    if [ ! -f 0-01.out ]; then
      cat <<EOF > 0-01.out
2
EOF
    fi
    cd .. || exit
    cd .. || exit


    echo '  generating "scripts" folder ...'
    rm -rf scripts
    ln -s ../.commons/tps-scripts scripts


    echo '  generating "solution" folder ...'
    mkdir -p solution
    cd solution || exit
    if [ -z "$(ls -A .)" ]; then
      cat <<EOF > main.cpp
#include <iostream>

using namespace std;

int main() {
    int a, b;
    cin >> a >> b;
    cout << (a + b) << endl;
    return 0;
}
EOF
    fi
    cd .. || exit


    echo '  generating "statement" folder ...'
    mkdir -p statement
    cd statement || exit
    if [ ! -f es.md ]; then
      cat <<EOF > es.md
# Lorem ipsum

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
EOF
    fi
    cd .. || exit


    echo '  generating "validator" folder ...'
    mkdir -p validator
    cd validator || exit
    rm -rf Makefile
    ln -s ../../.commons/Makefile Makefile
    rm -rf testlib.h
    ln -s ../../.commons/testlib.h testlib.h
    if [ ! -f validator.cpp ]; then
      cat <<EOF > validator.cpp
#include "testlib.h"

int main(int argc, char* argv[]) {
    registerValidation(argc, argv);

    const int MIN_A = 1;
    const int MAX_A = 10000;

    inf.readInt(MIN_A, MAX_A, "a");
    inf.readSpace();
    inf.readInt(MIN_A, MAX_A, "b");
    inf.readEoln();

    inf.readEof();

    return 0;
}
EOF
    fi
    cd .. || exit


    if [ ! -f problem.json ]; then
      cat <<EOF > problem.json
{
  "name": "$task_name",
  "header": "Problem A",
  "balloonColor": "#5B9BD5",
  "title": "Problem name",
  "type": "Batch",
  "has_grader": false,
  "java_enabled": false,
  "python_enabled": false,
  "time_limit": 1.0,
  "memory_limit": 256,
  "description": "",
  "web_url": "https://example.com/problem"
}
EOF
    fi

    if [ ! -f solutions.json ]; then
      cat <<EOF > solutions.json
{
    "main.cpp": {
        "verdict": "model_solution"
    }
}
EOF
    fi

    if [ ! -f subtasks.json ]; then
      cat <<EOF > subtasks.json
{
  "subtasks": {
    "samples": {
      "index": 0,
      "score": 0,
      "validators": [ "validator.cpp" ]
    },
    "subtask1": {
        "index": 1,
        "score": 40,
        "validators": [ "validator.cpp" ]
    },
    "subtask2": {
        "index": 2,
        "score": 60,
        "validators": [ "validator.cpp" ]
    }
  }
}
EOF
    fi

  done
  cd ..
}

prepare_folder "$@"
