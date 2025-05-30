
# This script compiles a solution.
#
# Argument list:
#	* SOLUTION: the solution file path
#
# Environment conditions:
#	* Environment variables regarding file locations like SANDBOX, INTERNALS, ... must be set.
#		They are naturally set and exported in locations.sh during TPS initialization.
#	* Environment variable GRADER_TYPE determines the type of grader (meaningful if prob.has_grader() is "true").
#		Its value must be either "judge" or "public".
#		If it is not set, it will be considered to be "judge".
#	* Environment variable VERBOSE determines if verbose details should be printed or not.
#		It must be either "true" or "false".
#		If it is not set, it will be considered to be "false".
#
# Behavior:
#	* The script builds the solution in SANDBOX.
#	* The exit code is non-zero in case of failure.
#	* It also detects compile warnings if WARN_FILE is defined.


set -euo pipefail

source "${INTERNALS}/util.sh"
source "${INTERNALS}/problem_util.sh"


function error_echo {
	cerrcho error -n "Error: "
	errcho "$@"
}
function error_exit {
	local -r exit_code=$1; shift
	error_echo "$@"
	exit ${exit_code}
}


# This function 'echo's its arguments iff VERBOSE is true
# It assumes the variable VERBOSE is already defined with value either "true" or "false".
function vecho {
	if "${VERBOSE}" ; then
		cerrcho cyan "$@"
	fi
}

# Prints a variable name and value in VERBOSE mode
function vecho_var {
	local -r var_name="$1"; shift
	if "${VERBOSE}" ; then
		cerrcho cyan -n "${var_name}='"
		errcho -n "${!var_name}"
		cerrcho cyan "'"
	fi
}


# This function runs a command
# It also prints the command before running iff VERBOSE is true
# It assumes the variable VERBOSE is already defined with value either "true" or "false".
function vrun {
	if "${VERBOSE}" ; then
		cerrcho cyan -n "RUN: "
		errcho "$@"
	fi
	"$@"
}


[ "$#" -eq 1 ] ||
	error_exit 2 "Illegal number of arguments"
SOLUTION="$1"; shift

if variable_not_exists "VERBOSE" ; then
	VERBOSE="false"
else
	is_in "${VERBOSE}" "true" "false" ||
		error_exit 1 "Invalid value for variable VERBOSE: ${VERBOSE}"
fi

PROBLEM_NAME="$(get_problem_data 'short_name')"

HAS_GRADER="$(get_problem_data 'has_grader')"
if "${HAS_GRADER}"; then
	variable_exists "GRADER_TYPE" ||
		GRADER_TYPE="judge"
	if [ "${GRADER_TYPE}" == "judge" ] ; then
		USED_GRADER_DIR="${GRADER_DIR}"
		GRADER_NAME="$(get_problem_data 'grader_name')"
	elif [ "${GRADER_TYPE}" == "public" ] ; then
		USED_GRADER_DIR="${PUBLIC_DIR}"
		GRADER_NAME="$(get_problem_data 'public_grader_name')"
	else
		error_exit 1 "Invalid grader type: ${GRADER_TYPE}"
	fi
else
	GRADER_TYPE="judge"
fi

sensitive check_file_exists "Solution file" "${SOLUTION}"
export SOLUTION
vecho "Compiling solution '${SOLUTION}'."

ext="$(extension "${SOLUTION}")"

if is_in "${ext}" "cpp" "cc" ; then
	vecho "Detected language: C++"
	LANG="cpp"
elif [ "${ext}" == "pas" ] ; then
	vecho "Detected language: Pascal"
	LANG="pas"
elif [ "${ext}" == "java" ] ; then
	vecho "Detected language: Java"
	LANG="java"
elif [ "${ext}" == "py" ] ; then
	vecho "Detected language: Python3"
	LANG="py"
elif [ "${ext}" == "py2" ] ; then
	vecho "Detected language: Python2"
	LANG="py2"
else
	error_exit 1 "Unknown solution extension: ${ext}"
fi

if "${HAS_GRADER}"; then
	vecho "The task has grader."
	export GRADER_TYPE
	vecho_var 'GRADER_TYPE'
	export USED_GRADER_DIR
	vecho_var 'USED_GRADER_DIR'
	vecho_var 'GRADER_NAME'
	GRADER_LANG_DIR="${USED_GRADER_DIR}/${LANG}"
	export GRADER_LANG_DIR
	vecho_var 'GRADER_LANG_DIR'
else
	vecho "The task does not have grader."
fi

vecho "Cleaning the sandbox..."
vrun recreate_dir "${SANDBOX}"

prog="${PROBLEM_NAME}.${LANG}"

vecho "Copying solution '${SOLUTION}' to sandbox as '${prog}'..."
vrun cp "${SOLUTION}" "${SANDBOX}/${prog}"


coloring_enabled="false"
if [ -t 2 ]; then
	coloring_enabled="true"
fi

function set_coloring_flag {
	local -r do_color_flag="$1"; shift
	local -r dont_color_flag="$1"; shift
	if "${coloring_enabled}" ; then
		coloring_flag="${do_color_flag}"
	else
		coloring_flag="${dont_color_flag}"
	fi
}


vecho "Entering the sandbox."
pushdq "${SANDBOX}"


compiler_out="compile.outputs"

function capture_compile {
	"$@" 2>&1 | tee -i -a "${compiler_out}" 1>&2
}

function check_warning {
	local warning_text_pattern="$1"
	if variable_exists "WARN_FILE"; then
		if grep -q "${warning_text_pattern}" "${compiler_out}"; then
			vecho "Text pattern '${warning_text_pattern}' found in compiler outputs."
			echo "Text pattern '${warning_text_pattern}' found in compiler outputs." >> "${WARN_FILE}"
		else
			vecho "Text pattern '${warning_text_pattern}' not found in compiler outputs."
		fi
	fi	
}

if variable_exists "WARN_FILE"; then
	vecho_var 'WARN_FILE'
else
	vecho "variable WARN_FILE is not defined."
fi


# Running pre-compilation hook
if [ -f "${PRE_COMPILE}" ] ; then
	vecho "Running pre-compilation hook file ${PRE_COMPILE}..."
	vrun bash "${PRE_COMPILE}"
else
	vecho "Pre-compilation hook file '${PRE_COMPILE}' is not present. Nothing to do before compiling."
fi


if [ "${LANG}" == "cpp" ] ; then
	cpp_std_flag="$(get_problem_data 'cpp_std_flag')"
	vecho_var 'cpp_std_flag'
	cpp_warning_flags="$(get_problem_data 'cpp_warning_flags')"
	vecho_var 'cpp_warning_flags'
	cpp_optimization_flags="$(get_problem_data 'cpp_optimization_flags')"
	vecho_var 'cpp_optimization_flags'
	cpp_extra_flags="$(get_problem_data 'cpp_extra_compile_flags')"
	vecho_var 'cpp_extra_flags'
	cpp_flags=""
	function add_cpp_flags {
		local -r new_flags="$1"; shift
		[ -n "${new_flags}" ] ||
			return 0
		[ -z "${cpp_flags}" ] ||
			cpp_flags="${cpp_flags} "
		cpp_flags="${cpp_flags}${new_flags}"
	}
	add_cpp_flags "${cpp_std_flag}"
	add_cpp_flags "${cpp_warning_flags}"
	add_cpp_flags "${cpp_optimization_flags}"
	add_cpp_flags "${cpp_extra_flags}"
	vecho_var 'cpp_flags'
	set_coloring_flag "-fdiagnostics-color=always" "-fdiagnostics-color=never"
	files_to_compile=("${prog}")
	if is_windows; then
		vecho "It is Windows. Needed disabling runtime error dialog."
		wrdd="win_rte_dialog_disabler.cpp"
		vecho "Copying '${wrdd}' to sandbox..."
		vrun cp "${INTERNALS}/${wrdd}" "."
		files_to_compile+=("${wrdd}")
	fi
	if "${HAS_GRADER}"; then
		grader_header="${PROBLEM_NAME}.h"
		grader_cpp="${GRADER_NAME}.cpp"
		vecho "Copying '${grader_header}' and '${grader_cpp}' to sandbox..."
		vrun cp "${GRADER_LANG_DIR}/${grader_header}" "${GRADER_LANG_DIR}/${grader_cpp}" "."
		vecho "Compiling grader..."
		vrun capture_compile g++ ${cpp_flags} -c "${grader_cpp}" -o "${GRADER_NAME}.o" "${coloring_flag}"
		vecho "Removing grader source..."
		vrun rm "${grader_cpp}"
		files_to_compile+=("${GRADER_NAME}.o")
		vecho "Added grader object file to the list of files to compile."
	fi
	vecho "files_to_compile: ${files_to_compile[@]}"
	exe_file="${PROBLEM_NAME}.exe"
	vecho "Compiling and linking..."
	vrun capture_compile g++ ${cpp_flags} "${files_to_compile[@]}" -o "${exe_file}" "${coloring_flag}"
	check_warning "${WARNING_TEXT_PATTERN_FOR_CPP}"
elif [ "${LANG}" == "pas" ] ; then
	variable_exists "PAS_OPTS" || PAS_OPTS="-dEVAL -XS -O2"
	vecho_var 'PAS_OPTS'
	files_to_compile=()
	if "${HAS_GRADER}"; then
		grader_pas="${GRADER_NAME}.pas"
		vecho "Copying '${grader_pas}' to sandbox..."
		vrun cp "${GRADER_LANG_DIR}/${grader_pas}" "."
		graderlib="${GRADER_NAME}lib.pas"
		if [ -f "${GRADER_LANG_DIR}/${graderlib}" ] ; then
			vecho "Copying '${graderlib}' to sandbox..."
			vrun cp "${GRADER_LANG_DIR}/${graderlib}" "."
		fi
		files_to_compile+=("${grader_pas}")
	else
		files_to_compile+=("${prog}")
	fi
	vecho "files_to_compile: ${files_to_compile[@]}"
	exe_file="${PROBLEM_NAME}.exe"
	vecho "Compiling and linking..."
	vrun capture_compile fpc ${PAS_OPTS} "${files_to_compile[@]}" "-o${exe_file}"
	[ -x "${exe_file}" ] ||
		error_exit 1 -e "Executable ${exe_file} is not created by the compiler.\nThe source file was probably a UNIT instead of a PROGRAM."
	check_warning "${WARNING_TEXT_PATTERN_FOR_PAS}"
elif [ "${LANG}" == "java" ] ; then
	variable_exists "JAVAC_WARNING_OPTS" || JAVAC_WARNING_OPTS="-Xlint:all"
	vecho_var 'JAVAC_WARNING_OPTS'
	variable_exists "JAVAC_OPTS" || JAVAC_OPTS="${JAVAC_WARNING_OPTS}"
	vecho_var 'JAVAC_OPTS'
	files_to_compile=("${prog}")
	if "${HAS_GRADER}"; then
		grader_java="${GRADER_NAME}.java"
		vecho "Copying '${grader_java}' to sandbox..."
		vrun cp "${GRADER_LANG_DIR}/${grader_java}" "."
		files_to_compile+=("${grader_java}")
		main_class="${GRADER_NAME}"
	else
		main_class="${PROBLEM_NAME}"
	fi
	vecho "files_to_compile: ${files_to_compile[@]}"
	vecho "Compiling java sources..."
	vrun capture_compile javac ${JAVAC_OPTS} "${files_to_compile[@]}"
	jar_file="${PROBLEM_NAME}.jar"
	vecho "Creating the jar file..."
	vrun capture_compile jar cfe "${jar_file}" "${main_class}" *.class
	vecho "Removing *.class files..."
	vrun rm *.class
	check_warning "${WARNING_TEXT_PATTERN_FOR_JAVA}"
elif is_in "${LANG}" "py" "py2" ; then
	function check_py_cmd {
		local CMD="$1"; shift
		command_exists "${CMD}" || return 1
		vecho "Python command '${CMD}' exists and is being used."
		PYTHON_CMD="${CMD}"
		return 0
	}
	if [ "${LANG}" == "py" ] ; then
		# Relying on the Python detection code in 'tps_init.sh'.
		variable_exists "PYTHON" ||
			error_exit 3 "Environment variable 'PYTHON' is not set."
		vecho "Environment variable PYTHON is set to '${PYTHON}'."
		check_py_cmd "${PYTHON}" ||
			error_exit 3 "Python command '${PYTHON}' set by environment variable 'PYTHON' does not exist."
	elif [ "${LANG}" == "py2" ] ; then
		function find_py2_cmd {
			check_py_cmd "python2" && return
			vecho "Python command 'python2' does not exist."
			check_py_cmd "python" && return
			vecho "Python command 'python' does not exist."
			variable_exists "PYTHON" ||
				error_exit 3 "Neither of python commands 'python2' nor 'python' exists and environment variable 'PYTHON' is not set."
			vecho "Environment variable PYTHON is set to '${PYTHON}'."
			check_py_cmd "${PYTHON}" ||
				error_exit 3 "Python command '${PYTHON}' set by environment variable 'PYTHON' does not exist."
		}
		find_py2_cmd
	else
		error_exit 5 "Illegal state; unhandled python language: ${LANG}"
	fi
	files_to_compile=("${prog}")
	if "${HAS_GRADER}"; then
		grader_py="${GRADER_NAME}.py"
		vecho "Copying '${grader_py}' to sandbox..."
		vrun cp "${GRADER_LANG_DIR}/${grader_py}" "."
		files_to_compile+=("${grader_py}")
		MAIN_FILE_NAME="${GRADER_NAME}"
	else
		MAIN_FILE_NAME="${PROBLEM_NAME}"
	fi
	vecho "files_to_compile: ${files_to_compile[@]}"
	vecho "Compiling python sources..."
	capture_compile echo "Running py_compile..."
	vrun capture_compile "${PYTHON_CMD}" -m py_compile "${MAIN_FILE_NAME}.py"
	# Using pylint as a static code analyzer
	static_code_analyzer="pylint"
	set_coloring_flag "--output-format=colorized" "--output-format=text"
	if command_exists "${static_code_analyzer}"; then
		vecho "Static code analyzer '${static_code_analyzer}' is available."
		variable_exists "PYLINT_OPTS" || PYLINT_OPTS="--persistent=n --disable=R,C"
		vecho_var 'PYLINT_OPTS'
		capture_compile echo "Running ${static_code_analyzer}..."
		if vrun capture_compile "${static_code_analyzer}" ${PYLINT_OPTS} "${coloring_flag}" "${MAIN_FILE_NAME}.py"; then
			vecho "No errors found by static code analyzer '${static_code_analyzer}'."
		else
			vecho "Errors found by static code analyzer '${static_code_analyzer}'."
			echo "Errors found by static code analyzer '${static_code_analyzer}'." >> "${WARN_FILE}"
		fi
	else
		vecho "Static code analyzer '${static_code_analyzer}' is not available."
	fi
	# Using mypy as a static type checker
	static_type_checker="mypy"
	set_coloring_flag "--color-output" "--no-color-output"
	if command_exists "${static_type_checker}"; then
		vecho "Static type checker '${static_type_checker}' is available."
		variable_exists "MYPY_OPTS" || MYPY_OPTS=""
		vecho_var 'MYPY_OPTS'
		capture_compile echo "Running ${static_type_checker}..."
		if vrun capture_compile "${static_type_checker}" ${MYPY_OPTS} "${coloring_flag}" "${MAIN_FILE_NAME}.py"; then
			vecho "No errors found by static type checker '${static_type_checker}'."
		else
			vecho "Errors found by static type checker '${static_type_checker}'."
			echo "Errors found by static type checker '${static_type_checker}'." >> "${WARN_FILE}"
		fi
	else
		vecho "Static type checker '${static_type_checker}' is not available."
	fi
else
	error_exit 5 "Illegal state; unknown language: ${LANG}"
fi

vecho "Exiting the sandbox."
popdq


function replace_general_tokens {
	local -r the_file="$1"; shift
	vrun replace_in_file_content "PROBLEM_NAME_PLACE_HOLDER" "${PROBLEM_NAME}" "${the_file}"
	if variable_exists "MAIN_FILE_NAME" ; then
		vrun replace_in_file_content "MAIN_FILE_NAME_PLACE_HOLDER" "${MAIN_FILE_NAME}" "${the_file}"
	fi
	if variable_exists "PYTHON_CMD" ; then
		vrun replace_in_file_content "PYTHON_CMD_PLACE_HOLDER" "${PYTHON_CMD}" "${the_file}"
	fi
}

function replace_tokens_for_run {
	local -r the_file="$1"; shift
	local -r runner_type="$1"; shift
	if [ "${runner_type}" == "communication" ]; then
		num_sol_processes="$(get_problem_data 'num_sol_processes')"
		vecho_var 'num_sol_processes'
		vrun replace_in_file_content "NUM_SOL_PROCESSES_PLACE_HOLDER" "${num_sol_processes}" "${the_file}"
		# Removing the irrelevant lines from run.sh based on user_communication_policy
		user_comm_stdio="$(get_problem_data 'user_communicates_through_stdio')"
		vecho_var 'user_comm_stdio'
		user_comm_file_args="$(get_problem_data 'user_communicates_through_file_args')"
		vecho_var 'user_comm_file_args'
		vrun replace_tagged_lines "USER_COMM_STDIO" "${user_comm_stdio}" "${the_file}"
		vrun replace_tagged_lines "!USER_COMM_STDIO" "! ${user_comm_stdio}" "${the_file}"
		vrun replace_tagged_lines "USER_COMM_FILE_ARGS" "${user_comm_file_args}" "${the_file}"
		vrun replace_tagged_lines "!USER_COMM_FILE_ARGS" "! ${user_comm_file_args}" "${the_file}"
	fi
}

# Adding exec.sh
execsh_name="exec.sh"
execsh="${SANDBOX}/${execsh_name}"
vecho "Creating '${execsh_name}' in sandbox..."
vrun cp "${TEMPLATES}/exec.${LANG}.sh" "${execsh}"
replace_general_tokens "${execsh}"
vrun chmod +x "${execsh}"

# Adding run.sh
runner_type=""
if [ "${GRADER_TYPE}" == "judge" ]; then
	runner_type="$(get_problem_data 'run_script_type_in_compilation')"
	vecho_var 'runner_type'
	source_runsh_name="run.${GRADER_TYPE}.${runner_type}.sh"
else
	source_runsh_name="run.${GRADER_TYPE}.sh"
fi
vecho_var 'source_runsh_name'
source_runsh="${TEMPLATES}/${source_runsh_name}"
runsh_name="run.sh"
runsh="${SANDBOX}/${runsh_name}"
vecho "Creating '${runsh_name}' in sandbox..."
vrun cp "${source_runsh}" "${runsh}"
replace_general_tokens "${runsh}"
replace_tokens_for_run "${runsh}" "${runner_type}"
vrun chmod +x "${runsh}"

# Compiling manager if needed.
HAS_MANAGER="$(get_problem_data 'has_manager')"
vecho_var 'HAS_MANAGER'
if "${HAS_MANAGER}"; then
	if [ "${GRADER_TYPE}" == "judge" ]; then
		vecho "Compiling manager as needed when grader type is ${GRADER_TYPE}..."
		vrun build_with_make "${MANAGER_DIR}"
		if compile_outputs_list=$(makefile_compile_outputs_list "${MANAGER_DIR}"); then
			for compile_output in ${compile_outputs_list}; do
				vecho "Content of '${MANAGER_DIR}/${compile_output}':"
				cat "${MANAGER_DIR}/${compile_output}"
			done
		else
			vecho "Makefile in '${MANAGER_DIR}' does not have target '${MAKEFILE_COMPILE_OUTPUTS_LIST_TARGET}'."
		fi
		vecho "Copying manager executable binary to sandbox..."
		vrun cp "${MANAGER_DIR}/manager.exe" "${SANDBOX}"
	else
		vecho "Manager is not needed when grader type is ${GRADER_TYPE}."
	fi
fi

# Running post-compilation hook
if [ -f "${POST_COMPILE}" ] ; then
	vecho "Running post-compilation hook file ${POST_COMPILE}..."
	vrun bash "${POST_COMPILE}"
else
	vecho "Post-compilation hook file '${POST_COMPILE}' is not present. Nothing more to do."
fi
