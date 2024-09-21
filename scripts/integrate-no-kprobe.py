import os
import re

def apply_patch(kernel_path, patch_file):
    os.chdir(kernel_path)
    try:
        # Ensure we're working with a clean state
        subprocess.run(["git", "reset", "--hard"], check=True)
        subprocess.run(["git", "clean", "-fd"], check=True)
        
        # Apply the patch
        result = subprocess.run(["git", "apply", "--check", patch_file], check=False, capture_output=True, text=True)
        if result.returncode == 0:
            # If --check is successful, apply the patch
            subprocess.run(["git", "apply", patch_file], check=True)
            print(f"Successfully applied patch {patch_file}")
        else:
            print(f"Patch {patch_file} does not apply cleanly.")
            print(result.stdout)
            print(result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred while applying the patch: {e}")
        print(f"Output: {e.output}")


def modify_ksu_config(defconfig, enable=True):
    # Possible directories for defconfig
    directories = [
        "arch/arm64/configs",
        "arch/arm64/configs/vendor"
    ]

    # Find the defconfig file
    defconfig_path = None
    for directory in directories:
        for filename in os.listdir(directory):
            if filename.endswith("_defconfig"):
                if os.path.exists(os.path.join(directory, filename)):
                    defconfig_path = os.path.join(directory, filename)
                    break
        if defconfig_path:
            break

    if not defconfig_path:
        print("Error: Could not find defconfig file.")
        return

    # Read the current content of the defconfig file
    with open(defconfig_path, 'r') as file:
        content = file.read()

    # Check if CONFIG_KPROBES is enabled
    kprobes_enabled = re.search(r'^CONFIG_KPROBES=y$', content, re.MULTILINE)
    if kprobes_enabled:
        print(f"Error: CONFIG_KPROBES is enabled in {defconfig_path}. Follow the official docs for kprobe integration.")
        exit()

    # Check if CONFIG_KSU is already present
    ksu_regex = re.compile(r'^CONFIG_KSU=.*$', re.MULTILINE)
    ksu_match = ksu_regex.search(content)

    new_config = "CONFIG_KSU=y" if enable else "CONFIG_KSU=n"

    if ksu_match:
        # Replace existing CONFIG_KSU line
        new_content = ksu_regex.sub(new_config, content)
    else:
        # Add new CONFIG_KSU line
        new_content = content + f"\n\n# KernelSU\n{new_config}\n"

    # Write the modified content back to the file
    with open(defconfig_path, 'w') as file:
        file.write(new_content)

    print(f"Successfully {'enabled' if enable else 'disabled'} CONFIG_KSU in {defconfig_path}")

def add_ksu_header(file_path, disable_external_mods=False):
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Find the last #include statement
    last_include = content.rfind('#include')
    if last_include != -1:
        # Find the end of the line containing the last #include
        end_of_line = content.find('\n', last_include)
        if end_of_line != -1:
            # Insert the new header after the last #include
            new_header = '\n#ifdef CONFIG_KSU\n#include <ksu_hook.h>\n#endif\n'
            modified_content = content[:end_of_line + 1] + new_header + content[end_of_line + 1:]
            
            with open(file_path, 'w') as file:
                file.write(modified_content)
            print(f"Added KSU header to {file_path}")
        else:
            print(f"Error: Couldn't find the end of the last #include line in {file_path}")
    else:
        print(f"Error: No #include statements found in {file_path}")
        
def add_ksu_calls(file_path, function_names, ksu_code, disable_external_mods=False):
    with open(file_path, 'r') as file:
        content = file.read()

    # Try to find any of the provided function names
    for function_name in function_names:
        if function_name.startswith('SYSCALL_DEFINE'):
            # Special handling for SYSCALL_DEFINE macros
            pattern = rf'{re.escape(function_name)}.*?\n.*?\{{.*?\n'
            match = re.search(pattern, content, re.DOTALL)
        else:
            # Regular function definition
            function_name = re.escape(function_name)
            pattern = rf'{function_name}\s*\([^)]*\)\s*\{{.*?\n'
            match = re.search(pattern, content, re.DOTALL)
        
        if match:
            break
    
    if match:
        # Find the position of the first 'if' statement after the function opening
        function_body = content[match.end():]
        if_match = re.search(r'\n\s*if\s*\(', function_body)
        
        if if_match:
            insert_pos = match.end() + if_match.start()

            # One letter difference
            if function_name == 'vfs_statx':
                ksu_code = ksu_code.replace('&flag', '&flags')
            
            # Insert KSU code before the first 'if' statement
            if not disable_external_mods or file_path.endswith(('exec.c', 'open.c', 'read_write.c', 'stat.c')):
                modified_content = content[:insert_pos] + "\n\n" + ksu_code + '\n' + content[insert_pos:]
            else:
                modified_content = content  # No changes for external modifications if disabled
            
            # Write the modified content back to the file
            with open(file_path, 'w') as file:
                file.write(modified_content)
            print(f"Added KSU calls to {function_name} in {file_path}")
        else:
            print(f"No 'if' statement found in {function_name} in {file_path}")
    else:
        print(f"Function {', '.join(function_names)} not found in {file_path}")

def process_kernel_source(file_paths, enable_ksu=True, disable_external_mods=False):
    for file_path in file_paths:
        file_name = os.path.basename(file_path)
        if file_name in ksu_calls:
            with open(file_path, 'r') as file:
                content = file.read()

            if enable_ksu:
                add_ksu_header(file_path, disable_external_mods)
                add_ksu_calls(file_path, ksu_calls[file_name]['functions'], ksu_calls[file_name]['code'], disable_external_mods)
            else:
                # Remove KSU modifications if KSU is disabled
                content = re.sub(r'#ifdef CONFIG_KSU.*?#endif', '', content, flags=re.DOTALL)
                with open(file_path, 'w') as file:
                    file.write(content)

            print(f"Processed {file_path}")
        else:
            print(f"Skipped {file_path} (not in ksu_calls)")

# KSU calls for each file (extern declarations removed, present in header file)
ksu_calls = {
    'exec.c': {
        'functions': ['do_execveat_common'],
        'code': '''   #ifdef CONFIG_KSU
       if (unlikely(ksu_execveat_hook))
               ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
       else
               ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);
   #endif'''
    },
    'open.c': {
        'functions': ['do_faccessat', 'SYSCALL_DEFINE3(faccessat,'],
        'code': '''   #ifdef CONFIG_KSU
            ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
   #endif'''
    },
    'read_write.c': {
        'functions': ['vfs_read'],
        'code': '''   #ifdef CONFIG_KSU
       if (unlikely(ksu_vfs_read_hook))
               ksu_handle_vfs_read(&file, &buf, &count, &pos);
   #endif'''
    },
    'stat.c': {
        'functions': ['vfs_statx', 'vfs_fstatat'],
        'code': '''   #ifdef CONFIG_KSU
        if (unlikely(ksu_vfs_stat_hook))
            ksu_handle_stat(&dfd, &filename, &flag);
    #endif'''
    },
    # External modifications
    'inode.c': {
        'functions': ['*devpts_get_priv'],
        'code': '''   #ifdef CONFIG_KSU
       ksu_handle_devpts(dentry->d_inode);
   #endif'''
    },
    'input.c': {
        'functions': ['input_handle_event'],
        'code': '''   #ifdef CONFIG_KSU
       if (unlikely(ksu_input_hook))
           ksu_handle_input_handle_event(&type, &code, &value);
   #endif'''
    }
}

def process_kernel_source(file_paths, enable_ksu=True, disable_external_mods=False):
    for file_path in file_paths:
        file_name = os.path.basename(file_path)
        if file_name in ksu_calls:
            with open(file_path, 'r') as file:
                content = file.read()

            if enable_ksu:
                add_ksu_header(file_path, disable_external_mods)
                add_ksu_calls(file_path, ksu_calls[file_name]['functions'], ksu_calls[file_name]['code'], disable_external_mods)
            else:
                # Remove KSU modifications if KSU is disabled
                content = re.sub(r'#ifdef CONFIG_KSU.*?#endif', '', content, flags=re.DOTALL)
                with open(file_path, 'w') as file:
                    file.write(content)

            print(f"Processed {file_path}")
        else:
            print(f"Skipped {file_path} (not in ksu_calls)")

def main():
    # Parse command-line arguments
    import argparse
    parser = argparse.ArgumentParser(description='KernelSU integration script')
    parser.add_argument('defconfig', help='Path to the defconfig file')
    parser.add_argument('--disable-ksu', action='store_true', help='Disable KernelSU')
    parser.add_argument('--disable-external-mods', action='store_true', help='Disable external modifications')
    parser.add_argument('--patch', help='Path to the patch file to apply')
    args = parser.parse_args()

    if args.patch:
        apply_patch(args.kernel_path, args.patch)

    # Modify KSU config based on the defconfig provided
    modify_ksu_config(defconfig=args.defconfig, enable=not args.disable_ksu)

    # Define the paths to your kernel source files
    file_paths = [
        './fs/exec.c',
        './fs/open.c',
        './fs/read_write.c',
        './fs/stat.c',
        './fs/devpts/inode.c',
        './drivers/input/input.c'
    ]

    # Process kernel source files
    process_kernel_source(file_paths, enable_ksu=not args.disable_ksu, disable_external_mods=args.disable_external_mods)

if __name__ == '__main__':
    main()
