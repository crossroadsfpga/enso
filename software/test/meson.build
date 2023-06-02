
gtest_main_dep = dependency('gtest_main', version: ['>=1.13.0', '<1.14.0'],
                            fallback : ['gtest', 'gtest_main_dep'])

test_deps = [
    gtest_main_dep
]

queue_test = executable('queue_test', 'queue_test.cpp',
                        dependencies: test_deps, link_with: enso_lib,
                        include_directories: inc)

test('queue_test', queue_test)
