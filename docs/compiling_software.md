# Compiling Software

Start by cloning the enso repository, if you haven't already:
```bash
git clone https://github.com/crossroadsfpga/enso
```

Prepare the compilation using `meson` and compile it with `ninja`.

Setup to use gcc:
```bash
meson setup --native-file gcc.ini build
```

This will use `gcc-9`, you may change `gcc.ini` to use a different version of GCC.

Now compile:
```bash
cd build
ninja
```

## Compilation options

There are a few compile-time options that you may set. You can see all the available options with:
```bash
meson configure
```

If you run the above in the build directory, it also shows the current value for each option.

To change one of the options run:
```bash
meson configure -D<option_name>=<value>
```

For instance, to enable latency optimization:
```bash
meson configure -Dlatency_opt=true
```

## Build an application with Ensō

If you want to build an application that uses Ensō, you should install the Ensō library in your system. You can use `ninja` for that:
```bash
cd build
ninja
sudo ninja install
```

Then, you should link the application with the Ensō library. The way you do it depends on how you are compiling your code. Here are some examples using `gcc`, `meson` and `cmake`.

### Using `gcc` with no build system

```bash
g++ -o my_app my_app.cpp -lenso
```

### Using `meson`

If using meson, you should add the following to your `meson.build` file:
```meson
enso_dep = dependency('enso')
```

Then, you can link your application with the Ensō library:
```meson
executable('my_app', 'my_app.cpp', dependencies: [enso_dep])
```

### Using `cmake`

If using `cmake`, you should add the following to your `CMakeLists.txt` file:
```cmake
link_libraries(enso)
```



## Building the documentation

You can access Ensō's documentation at [https://crossroadsfpga.github.io/enso/](https://crossroadsfpga.github.io/enso/). But if you would like to contribute to the documentation, you may choose to also build it locally.

Install the requirements:

```bash
sudo apt update
sudo apt install doxygen python3-pip npm
python3 -m pip install -r docs/requirements.txt
sudo npm install -g teroshdl
```

To build the documentation, run (from the build directory):

```bash
meson compile docs
```

While writing documentation, you can use the following command to automatically rebuild the documentation when you make changes:

```bash
cd <root of enso repository>
mkdocs serve
```

Note that this does not automatically rebuild the hardware and software API reference. You need to rerun `meson compile docs` to do that.


<!-- Compile-time configuration -->