# The app's QML tests as CTest tests, for Qt Creator's Test Results and for
# `ctest`. Nothing is built: the app is QML only, and the package is made by
# copying (the recipe, tools/install.sh). See "Tests" in README.md.
#
#   cmake -S . -B build/cmake && ctest --test-dir build/cmake
#
# LUNEOS_COMPONENTS is the luneos-components checkout, QMLTESTRUNNER a Qt 6
# qmltestrunner (tests/run-tests.sh looks for one when it is empty).
cmake_minimum_required(VERSION 3.16)
project(org.webosports.app.photos NONE)

set(LUNEOS_COMPONENTS "${CMAKE_CURRENT_SOURCE_DIR}/../luneos-components" CACHE PATH
    "The luneos-components checkout")
set(QMLTESTRUNNER "" CACHE FILEPATH "Qt 6 qmltestrunner (found when empty)")
set(PHOTOS_PROFILES tp mindphone q25 CACHE STRING "Device profiles tst_ui runs on")

enable_testing()

# name, then TESTS=, UI_TESTS= and PROFILES= for tests/run-tests.sh
function(photos_test name tests ui_tests profiles)
    add_test(NAME ${name}
        COMMAND ${CMAKE_COMMAND} -E env
            "COMPONENTS=${LUNEOS_COMPONENTS}"
            "QMLTESTRUNNER=${QMLTESTRUNNER}"
            "TESTS=${tests}" "UI_TESTS=${ui_tests}" "PROFILES=${profiles}"
            sh ${CMAKE_CURRENT_SOURCE_DIR}/tests/run-tests.sh)
endfunction()

photos_test(library tst_library.qml "" "")
photos_test(store tst_store.qml "" "")
foreach(profile IN LISTS PHOTOS_PROFILES)
    photos_test(ui-${profile} "" tst_ui.qml ${profile})
endforeach()
