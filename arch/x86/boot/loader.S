/**
 * SPDX-FileCopyrightText: 2020 Anuradha Weeraman <anuradha@weeraman.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#define ASM_FILE 1
#include <x86/boot/multiboot2.h>

        .set STACK_SIZE,     4096
        .set MB2_ARCH_FLAG,  0x0
        .set MB2_FB_TAG,     0x0

        .section .multiboot
        .align 8
mb2_hdr:
        .long MULTIBOOT2_HEADER_MAGIC
        .long MB2_ARCH_FLAG
        .long mb2_hdr_end - mb2_hdr
        .long -(MULTIBOOT2_HEADER_MAGIC + MB2_ARCH_FLAG + (mb2_hdr_end - mb2_hdr))
        .align 8

#ifdef CONFIG_FRAMEBUFFER_RGB
framebuffer_tag_start:
        .short MULTIBOOT_HEADER_TAG_FRAMEBUFFER
        .short MULTIBOOT_HEADER_TAG_OPTIONAL
        .long framebuffer_tag_end - framebuffer_tag_start
        .long CONFIG_FRAMEBUFFER_WIDTH
        .long CONFIG_FRAMEBUFFER_HEIGHT
        .long CONFIG_FRAMEBUFFER_BPP
framebuffer_tag_end:
        .align 8
#endif

tag_end:
        .word 0                   # end tag type
        .word 0                   # end tag flags
        .long 8                   # size, 8 to terminate
tag_end_end:
mb2_hdr_end:

        .section .text
        .global _start
_start:
        mov $stack_top, %esp

        # Clear EFLAGS
        pushl $0
        popf

        # Pointer to the Multiboot2 information structure
        pushl %ebx

        # Multiboot2 magic value
        pushl %eax

        # Initialize the console
        call early_framebuffer_console_init;

        # Check for the availability of the cpuid instruction
        pushf
        pushf
        xorl $0x00200000, (%esp)
        popf
        pushf
        popl %eax
        xorl (%esp), %eax
        popf
        andl $0x00200000, %eax
        cmp $0, %eax
        je nocpuid
        call cpuid

nocpuid:
        # Disable interrupts
        cli

        # Setup the GDT
        call gdt_init

        # Initialize the PIC
        call pic_init

        # Setup the IDT
        call idt_init

        # Enter protected mode
        mov %cr0, %eax
        or $1, %eax
        mov %eax, %cr0

        # Jump to function in kernel.c
        call kernel_main

        # returning from the kernel
        pushl $shutdown_msg
        call printk

        cli
halt:   hlt
        jmp halt

shutdown_msg:
        .asciz  "System shutdown.\n"

        .section .bss
        .align 16
stack_bottom:
        .skip STACK_SIZE
stack_top:
