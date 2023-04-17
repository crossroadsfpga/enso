# Compiling Software

Start by cloning the enso repository, if you haven't already:
```bash
git clone https://github.com/crossroadsfpga/enso
```

Prepare the compilation using meson and compile it with ninja.

Setup to use gcc:
```bash
meson setup --native-file gcc.ini build
```

Compile:
```bash
cd build
ninja
```

### Compilation options

There are a few compile-time options that you may set. You can see all the options with:
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


## Building Documentation

You can access Ensō's documentation at [https://crossroadsfpga.github.io/enso/](https://crossroadsfpga.github.io/enso/). But if you would like to contribute to the documentation, you may choose to also build it locally.

Install the requirements, this assumes that you already have pip and npm installed:

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
mkdocs serve
```

Note that this does not automatically rebuild the hardware and software API reference. You need to rerun `meson compile docs` to do that.


<!-- Compile-time configuration -->