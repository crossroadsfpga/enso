inc = include_directories('include')

subdir('include')
subdir('src')

if dev_backend == 'intel_fpga'
    library_name = 'enso'
elif dev_backend == 'software'
    library_name = 'enso_sw'
else
    error('Unknown backend')
endif

enso_lib = library(library_name, project_sources, install: true,
                   include_directories: [inc, backend_inc, enso_backend_inc])
pkg_mod = import('pkgconfig')
pkg_mod.generate(enso_lib)

subdir('examples')
subdir('test')
