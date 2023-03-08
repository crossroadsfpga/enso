
add_global_arguments(['-mavx'], language: ['c', 'cpp'])

project_sources = []
project_libraries = []

subdir('enso')
subdir('syscall_api')

project_sources += files(
    'pcie.cpp'
)
