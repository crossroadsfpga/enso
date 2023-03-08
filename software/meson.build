inc = include_directories('include')

subdir('include')
subdir('src')

enso_lib = library('enso', project_sources, install: true,
                   include_directories: inc)

subdir('examples')
