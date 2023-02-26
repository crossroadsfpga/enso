inc = include_directories('include')

subdir('include')
subdir('src')

norman_lib = library('norman', project_sources, install: true,
                     include_directories: inc)

subdir('examples')
