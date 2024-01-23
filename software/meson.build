inc = include_directories('include')

subdir('include')
subdir('src')

enso_lib = library('enso', project_sources, install: true, dependencies: [],
                   include_directories: [inc, backend_inc])
fpga_enso_lib = library('fpga_enso', project_sources, install: true, dependencies: [],
                   include_directories: [inc, fpga_backend_inc])
hybrid_enso_lib = library('hybrid_enso', project_sources, install: true, dependencies: [],
                   include_directories: [inc, hybrid_backend_inc])
pkg_mod = import('pkgconfig')
pkg_mod.generate(fpga_enso_lib)
pkg_mod.generate(hybrid_enso_lib)

subdir('examples')
subdir('test')
