const std = @import("std");
const builtin = std.builtin;
const serial = @import("serial.zig");
const panic = @import("../../../panic.zig").panic;
const Serial = @import("../../../serial.zig").Serial;

// Expose the common implementations
pub const gdt_common = @import("gdt.zig");
pub const idt_common = @import("idt.zig");
pub const isr_common = @import("isr.zig");
pub const irq_common = @import("irq.zig");
pub const pic_common = @import("pic.zig");

pub const CpuState = switch (builtin.cpu.arch) {
    .i386 => @import("../32bit/arch.zig").CpuState32,
    .x86_64 => @import("../64bit/arch.zig").CpuState64,
    else => unreachable,
};

const BootPayload = switch (builtin.cpu.arch) {
    .i386 => @import("../32bit/arch.zig").BootPayload,
    .x86_64 => @import("../64bit/arch.zig").BootPayload,
    else => unreachable,
};

// This is the assembly for the FAT bootloader.
//     [bits   16]
//     [org    0x7C00]
//
//     jmp     short _start
//     nop
//
// times 87 db 0xAA
//
// _start:
//     jmp     long 0x0000:start_16bit
//
// start_16bit:
//     cli
//     mov     ax, cs
//     mov     ds, ax
//     mov     es, ax
//     mov     ss, ax
//     mov     sp, 0x7C00
//     lea     si, [message]
// .print_string_with_new_line:
//     mov     ah, 0x0E
//     xor     bx, bx
// .print_string_loop:
//     lodsb
//     cmp     al, 0
//     je      .print_string_done
//     int     0x10
//     jmp     short .print_string_loop
// .print_string_done:
//     mov     al, 0x0A
//     int     0x10
//     mov     al, 0x0D
//     int     0x10
//
// .reboot:
//     xor     ah, ah
//     int     0x16
//     int     0x19
//
// .loop_forever:
//     hlt
//     jmp .loop_forever
// message db "This is not a bootable disk. Please insert a bootable floppy and press any key to try again", 0
// times 510 - ($ - $$) db 0
// dw 0xAA55

/// Basic boot code that will just print to the scream to insert a bootable image. This is intended
/// as a place holder to be over written with real boot code if needed.
/// This assumes the 512 sector size and includes the 0xAA55 boot signature.
pub const filesystem_bootsector_boot_code = [512]u8{
    0xEB, 0x58, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x66, 0xEA, 0x62, 0x7C, 0x00, 0x00,
    0x00, 0x00, 0xFA, 0x8C, 0xC8, 0x8E, 0xD8, 0x8E, 0xC0, 0x8E, 0xD0, 0xBC, 0x00, 0x7C, 0x8D, 0x36,
    0x8F, 0x7C, 0xB4, 0x0E, 0x31, 0xDB, 0xAC, 0x3C, 0x00, 0x74, 0x04, 0xCD, 0x10, 0xEB, 0xF7, 0xB0,
    0x0A, 0xCD, 0x10, 0xB0, 0x0D, 0xCD, 0x10, 0x30, 0xE4, 0xCD, 0x16, 0xCD, 0x19, 0xEB, 0xFE, 0x54,
    0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x6E, 0x6F, 0x74, 0x20, 0x61, 0x20, 0x62, 0x6F, 0x6F,
    0x74, 0x61, 0x62, 0x6C, 0x65, 0x20, 0x64, 0x69, 0x73, 0x6B, 0x2E, 0x20, 0x50, 0x6C, 0x65, 0x61,
    0x73, 0x65, 0x20, 0x69, 0x6E, 0x73, 0x65, 0x72, 0x74, 0x20, 0x61, 0x20, 0x62, 0x6F, 0x6F, 0x74,
    0x61, 0x62, 0x6C, 0x65, 0x20, 0x66, 0x6C, 0x6F, 0x70, 0x70, 0x79, 0x20, 0x61, 0x6E, 0x64, 0x20,
    0x70, 0x72, 0x65, 0x73, 0x73, 0x20, 0x61, 0x6E, 0x79, 0x20, 0x6B, 0x65, 0x79, 0x20, 0x74, 0x6F,
    0x20, 0x74, 0x72, 0x79, 0x20, 0x61, 0x67, 0x61, 0x69, 0x6E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x55, 0xAA,
};

///
/// Assembly that reads data from a given port and returns its value.
///
/// Arguments:
///     IN comptime Type: type - The type of the data. This can only be u8, u16 or u32.
///     IN port: u16           - The port to read data from.
///
/// Return: Type
///     The data that the port returns.
///
pub fn in(comptime Type: type, port: u16) Type {
    return switch (Type) {
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> Type)
            : [port] "N{dx}" (port)
        ),
        u16 => asm volatile ("inw %[port], %[result]"
            : [result] "={ax}" (-> Type)
            : [port] "N{dx}" (port)
        ),
        u32 => asm volatile ("inl %[port], %[result]"
            : [result] "={eax}" (-> Type)
            : [port] "N{dx}" (port)
        ),
        else => @compileError("Invalid data type. Only u8, u16 or u32, found: " ++ @typeName(Type)),
    };
}

///
/// Assembly to write to a given port with a give type of data.
///
/// Arguments:
///     IN port: u16     - The port to write to.
///     IN data: anytype - The data that will be sent This must be a u8, u16 or u32 type.
///
pub fn out(port: u16, data: anytype) void {
    switch (@TypeOf(data)) {
        u8 => asm volatile ("outb %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{al}" (data)
        ),
        u16 => asm volatile ("outw %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{ax}" (data)
        ),
        u32 => asm volatile ("outl %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{eax}" (data)
        ),
        else => @compileError("Invalid data type. Only u8, u16 or u32, found: " ++ @typeName(@TypeOf(data))),
    }
}

///
/// Load the GDT and refreshing the code segment with the code segment offset of the kernel as we
/// are still in kernel land. Also loads the kernel data segment into all the other segment
/// registers.
///
/// Arguments:
///     IN gdt_ptr: *gdt.GdtPtr - The address to the GDT.
///
pub fn lgdt(gdt_ptr: *const gdt_common.GdtPtr) void {
    asm volatile (
        \\lgdt %[gdt_ptr]
        \\mov %[offset], %%ds
        \\mov %[offset], %%es
        \\mov %[offset], %%fs
        \\mov %[offset], %%gs
        \\mov %[offset], %%ss
        :
        : [gdt_ptr] "*p" (gdt_ptr),
          [offset] "rm" (gdt_common.KERNEL_DATA_OFFSET)
    );
    if (builtin.cpu.arch == .x86_64) {
        asm volatile (
            \\push %[offset]
            \\push $1f
            \\lretq
            \\1:
            :
            : [offset] "i" (gdt_common.KERNEL_CODE_OFFSET)
        );
    } else {
        asm volatile (
            \\ljmp %[offset], $1f
            \\1:
            :
            : [offset] "i" (gdt_common.KERNEL_CODE_OFFSET)
        );
    }
}

///
/// Get the previously loaded GDT from the CPU.
///
/// Return: gdt.GdtPtr
///     The previously loaded GDT from the CPU.
///
pub fn sgdt() gdt_common.GdtPtr {
    var gdt_ptr = gdt_common.GdtPtr{ .limit = undefined, .base = undefined };
    asm volatile ("sgdt %[tab]"
        : [tab] "=m" (gdt_ptr)
    );
    return gdt_ptr;
}

///
/// Tell the CPU where the TSS is located in the GDT.
///
/// Arguments:
///     IN offset: u16 - The offset in the GDT where the TSS segment is located.
///
pub fn ltr(offset: u16) void {
    asm volatile ("ltr %%ax"
        :
        : [offset] "{ax}" (offset)
    );
}

///
/// Load the IDT into the CPU.
///
/// Arguments:
///     IN comptime IdtEntry: type - The IDT entry type.
///     IN idt_ptr: *const idt.IdtPtr(IdtEntry) - The address of the iDT.
///
pub fn lidt(comptime IdtEntry: type, idt_ptr: *const idt_common.IDT(IdtEntry).IdtPtr) void {
    asm volatile ("lidt (%[idt_ptr])"
        :
        : [idt_ptr] "r" (idt_ptr)
    );
}

///
/// Get the previously loaded IDT from the CPU.
///
/// Arguments:
///     IN comptime IdtEntry: type - The IDT entry type.
///
/// Return: idt.IdtPtr(IdtEntry)
///     The previously loaded IDT from the CPU.
///
pub fn sidt(comptime IdtEntry: type) idt_common.IDT(IdtEntry).IdtPtr {
    var idt_ptr = idt_common.IDT(IdtEntry).IdtPtr{ .limit = undefined, .base = undefined };
    asm volatile ("sidt %[tab]"
        : [tab] "=m" (idt_ptr)
    );
    return idt_ptr;
}

///
/// Enable interrupts.
///
pub fn enableInterrupts() void {
    asm volatile ("sti");
}

///
/// Disable interrupts.
///
pub fn disableInterrupts() void {
    asm volatile ("cli");
}

///
/// Halt the CPU, but interrupts will still be called.
///
pub fn halt() void {
    asm volatile ("hlt");
}

///
/// Wait the kernel but still can handle interrupts.
///
pub fn spinWait() noreturn {
    enableInterrupts();
    while (true) {
        halt();
    }
}

///
/// Halt the kernel. No interrupts will be handled.
///
pub fn haltNoInterrupts() noreturn {
    while (true) {
        disableInterrupts();
        halt();
    }
}

///
/// Force the CPU to wait for an I/O operation to compete. Use port 0x80 as this is unused.
///
pub fn ioWait() void {
    out(0x80, @as(u8, 0));
}

///
/// Write a byte to serial port com1. Used by the serial initialiser
///
/// Arguments:
///     IN byte: u8 - The byte to write
///
fn writeSerialCom1(byte: u8) void {
    serial.write(byte, serial.Port.COM1);
}

///
/// Initialise serial communication using port COM1 and construct a Serial instance
///
/// Arguments:
///     IN boot_payload: arch.BootPayload - The payload passed at boot. Not currently used by x86
///                                         or x86_64.
///
/// Return: serial.Serial
///     The Serial instance constructed with the function used to write bytes
///
pub fn initSerial(boot_payload: BootPayload) Serial {
    serial.init(serial.DEFAULT_BAUDRATE, serial.Port.COM1) catch |e| {
        panic(@errorReturnTrace(), "Failed to initialise serial: {}", .{e});
    };
    return Serial{
        .write = writeSerialCom1,
    };
}
