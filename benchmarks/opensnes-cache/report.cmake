# OpenSNES cache benchmark: size of four reference GSU jobs against the
# 512-byte code cache, with their results checked in the execution model.
#
#   cmake -DDISCO_TOOLS_DIR=build/release/bin -P benchmarks/opensnes-cache/report.cmake
#
# -DENFORCE_BUDGET=ON fails when a cache job is larger than the budget.
# Wrong results always fail.
if(NOT DISCO_TOOLS_DIR)
    message(FATAL_ERROR "Pass -DDISCO_TOOLS_DIR=<directory holding discc, discld and disco_gsu_execution_tests>")
endif()
get_filename_component(tools "${DISCO_TOOLS_DIR}" ABSOLUTE)
if(NOT OUTPUT_DIR)
    set(OUTPUT_DIR "${tools}/../benchmark-output/opensnes-cache")
endif()
get_filename_component(output "${OUTPUT_DIR}" ABSOLUTE)
file(MAKE_DIRECTORY "${output}")
set(suffix "")
if(CMAKE_HOST_WIN32)
    set(suffix ".exe")
endif()
set(budget 512)

function(run)
    execute_process(COMMAND ${ARGV} RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(result)
        message(FATAL_ERROR "Command failed (${result}): ${ARGV}\n${out}\n${err}")
    endif()
endfunction()

function(build source name)
    run("${tools}/discc${suffix}" "${source}" -o "${output}/${name}.o")
    run("${tools}/discld${suffix}" "${output}/${name}.o" --init-runtime -o "${output}/${name}.bin")
endfunction()

set(over_budget 0)
# name, hand-written bytes, runs from the cache, model expectations
function(job name reference cached)
    set(source "${CMAKE_CURRENT_LIST_DIR}/${name}.dc")
    build("${source}" "${name}")
    file(SIZE "${output}/${name}.bin" size)
    set(checked "${name}")
    if(name STREQUAL "add_job")
        # 600 000 iterations exceed the model's instruction limit: check the
        # same program with a shorter inner loop, measure the real one.
        file(READ "${source}" text)
        string(REPLACE "n = 3000" "n = 30" text "${text}")
        file(WRITE "${output}/add_job_short.dc" "${text}")
        build("${output}/add_job_short.dc" add_job_short)
        set(checked add_job_short)
    endif()
    run("${tools}/disco_gsu_execution_tests${suffix}" "${output}/${checked}.bin" 0x008000 ${ARGN} --register 6 0)
    math(EXPR ratio "(${size} * 10) / ${reference}")
    string(REGEX REPLACE "(.)$" ".\\1" ratio "${ratio}")
    set(verdict "size only (reads ROM)")
    if(cached)
        if(size GREATER budget)
            set(verdict "over the ${budget}-byte cache")
            set(over_budget 1 PARENT_SCOPE)
        else()
            set(verdict "fits the cache")
        endif()
    endif()
    message(STATUS "${name}: ${size} bytes, hand-written ${reference} (x${ratio}), ${verdict}")
endfunction()

job(add_job 40 ON --word 0x700010 42000 --word 0x700012 0 --word 0x700014 0xC0DE)
job(mul_job 20 ON --ram-byte 0x700020 44 --ram-byte 0x700021 1 --ram-byte 0x700022 7 --word 0x700016 2100)
job(rom_job 29 OFF --word 0x700018 0x3CA5)
job(fixed_job 57 ON --byte 0x700030 0x42 --byte 0x700031 0x55 --word 0x700032 0xBEEF
    --word 0x700034 0x4000 --word 0x700036 0x4800)

if(ENFORCE_BUDGET AND over_budget)
    message(FATAL_ERROR "At least one cache job does not fit in ${budget} bytes.")
endif()
