For the original KernelSU's readme, click [here](https://github.com/tiann/KernelSU?tab=readme-ov-file#kernelsu).

This repo is just the extension of KernelSU for non GKI devices

For manual integration (kprobes can be referred to from the official docs), Run the below commands in the root of your kernel directory

```
 curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/main/kernel/setup-subm.sh" | bash -s 
```

Then, For adding the ksu modifications in the .c files, For whichever defconfig you're using, Just pass it as an argument to the below script.
> Keep in mind that on some devices, your defconfig may be in arch/arm64/configs or in other cases arch/arm64/configs/vendor/your_defconfig. 
```
python3 KernelSU/scripts/integrate-no-kprobe.py <__your_defconfig__>
```

Usage:

To use the script, you would run it from the command line, providing the path to your defconfig file as an argument. For example:
```
python3 KernelSU/scripts/integrate-no-kprobe.py /path/to/your_defconfig
```
If you want to disable KernelSU in your defconfig:
```
python3 KernelSU/scripts/integrate-no-kprobe.py some_random_defconfig --disable-ksu
```
If you want to disable external modifications (non neccessary ones like inode.c, input.c):
```
python3 KernelSU/scripts/integrate-no-kprobe.py your_defconfig --disable-external-mods
```


If you want to build your kernel entirely online with custom gcc or clang, checkout [kernelsu_build_action](https://github.com/xiaoleGun/KernelSU_Action/)
## Credits

- Initially, was built over [this](https://github.com/vc-teahouse/KernelSU-nongki) repository.
- [KernelSU](https://github.com/tiann/KernelSU)
