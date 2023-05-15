
add_global_arguments(['-mavx'], language: ['c', 'cpp'])

project_sources = []
project_libraries = []

subdir('enso')
subdir('syscall_api')

if mock
    project_sources += files(
        'mock_pcie.cpp'
    )
else
    project_sources += files(
        'pcie.cpp'
    )
endif
