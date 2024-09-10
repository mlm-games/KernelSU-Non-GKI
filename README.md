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

## Credits

- Initially, was built over [this](https://github.com/vc-teahouse/KernelSU-nongki) repository.
- [KernelSU](https://github.com/tiann/KernelSU)
