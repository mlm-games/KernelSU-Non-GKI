For the original KernelSU's readme, click [here](https://github.com/tiann/KernelSU?tab=readme-ov-file#kernelsu).

This repo is just the extension of KernelSU for non GKI devices

For manual integration (kprobes can be referred to from the official docs), Run the below commands in the root of your kernel directory

```
 curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/main/kernel/setup-subm.sh" | bash -s 
```

Then, For adding the ksu modifications in the .c files
```
python3 KernelSU/scripts/integrate-no-kprobe.py 
```

## Credits

- Initially, was built over [this](https://github.com/vc-teahouse/KernelSU-nongki) repository.
- [KernelSU](https://github.com/tiann/KernelSU)
