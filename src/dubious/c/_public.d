/*
  Dokan : user-mode file system library for Windows

  Copyright (C) 2015 - 2017 Adrien J. <liryna.stark@gmail.com> and Maxime C. <maxime@islog.com>
  Copyright (C) 2007 - 2011 Hiroki Asakawa <info@dokan-dev.net>

  http://dokan-dev.github.io

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation; either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program. If not, see <http://www.gnu.org/licenses/>.
*/

module dubious.c._public;

import core.sys.windows.winioctl;
import core.sys.windows.windef;
import core.sys.windows.ntdef;

enum DOKAN_MAJOR_API_VERSION = "1"w;

enum DOKAN_DRIVER_VERSION = 0x0000190;

enum EVENT_CONTEXT_MAX_SIZE = (1024 * 32);

enum IOCTL_TEST = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x800, METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_SET_DEBUG_MODE = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x801,
            METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_WAIT = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x802, METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_INFO = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x803, METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_RELEASE = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x804,
            METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_START = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x805, METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_WRITE = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x806,
            METHOD_OUT_DIRECT, FILE_ANY_ACCESS);
enum IOCTL_KEEPALIVE = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x809, METHOD_NEITHER, FILE_ANY_ACCESS);
enum IOCTL_SERVICE_WAIT = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x80A,
            METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_RESET_TIMEOUT = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x80B,
            METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_GET_ACCESS_TOKEN = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x80C,
            METHOD_BUFFERED, FILE_ANY_ACCESS);
enum IOCTL_EVENT_MOUNTPOINT_LIST = CTL_CODE_T!(FILE_DEVICE_UNKNOWN, 0x80D,
            METHOD_BUFFERED, FILE_ANY_ACCESS);

enum DRIVER_FUNC_INSTALL = 0x01;
enum DRIVER_FUNC_REMOVE = 0x02;

enum DOKAN_MOUNTED = 1;
enum DOKAN_USED = 2;
enum DOKAN_START_FAILED = 3;

enum DOKAN_DEVICE_MAX = 10;

enum DOKAN_DEFAULT_SECTOR_SIZE = 512;
enum DOKAN_DEFAULT_ALLOCATION_UNIT_SIZE = 512;
enum DOKAN_DEFAULT_DISK_SIZE = 1024 * 1024 * 1024;

// used in CCB->Flags and FCB->Flags
enum DOKAN_FILE_DIRECTORY = 1;
enum DOKAN_FILE_DELETED = 2;
enum DOKAN_FILE_OPENED = 4;
enum DOKAN_DIR_MATCH_ALL = 8;
enum DOKAN_DELETE_ON_CLOSE = 16;
enum DOKAN_PAGING_IO = 32;
enum DOKAN_SYNCHRONOUS_IO = 64;
enum DOKAN_WRITE_TO_END_OF_FILE = 128;
enum DOKAN_NOCACHE = 256;

// used in DOKAN_START->DeviceType
enum DOKAN_DISK_FILE_SYSTEM = 0;
enum DOKAN_NETWORK_FILE_SYSTEM = 1;

/**
 * This structure is used for copying UNICODE_STRING from the kernel mode driver
 * into the user mode driver.
 * https://msdn.microsoft.com/en-us/library/windows/hardware/ff564879(v=vs.85).aspx
 */
struct _DOKAN_UNICODE_STRING_INTERMEDIATE
{
    USHORT Length;
    USHORT MaximumLength;
    WCHAR[1] Buffer;
}

alias _DOKAN_UNICODE_STRING_INTERMEDIATE DOKAN_UNICODE_STRING_INTERMEDIATE;
alias _DOKAN_UNICODE_STRING_INTERMEDIATE* PDOKAN_UNICODE_STRING_INTERMEDIATE;

/**
 * This structure is used for copying ACCESS_STATE from the kernel mode driver
 * into the user mode driver.
 * https://msdn.microsoft.com/en-us/library/windows/hardware/ff538840(v=vs.85).aspx
 */
struct _DOKAN_ACCESS_STATE_INTERMEDIATE
{
    BOOLEAN SecurityEvaluated;
    BOOLEAN GenerateAudit;
    BOOLEAN GenerateOnClose;
    BOOLEAN AuditPrivileges;
    ULONG Flags;
    ACCESS_MASK RemainingDesiredAccess;
    ACCESS_MASK PreviouslyGrantedAccess;
    ACCESS_MASK OriginalDesiredAccess;

    /// Offset from the beginning of this structure to a SECURITY_DESCRIPTOR
    /// if 0 that means there is no security descriptor
    ULONG SecurityDescriptorOffset;

    /// Offset from the beginning of this structure to a
    /// DOKAN_UNICODE_STRING_INTERMEDIATE
    ULONG UnicodeStringObjectNameOffset;

    /// Offset from the beginning of this structure to a
    /// DOKAN_UNICODE_STRING_INTERMEDIATE
    ULONG UnicodeStringObjectTypeOffset;
}

alias _DOKAN_ACCESS_STATE_INTERMEDIATE DOKAN_ACCESS_STATE_INTERMEDIATE;
alias _DOKAN_ACCESS_STATE_INTERMEDIATE* PDOKAN_ACCESS_STATE_INTERMEDIATE;

struct _DOKAN_ACCESS_STATE
{
    BOOLEAN SecurityEvaluated;
    BOOLEAN GenerateAudit;
    BOOLEAN GenerateOnClose;
    BOOLEAN AuditPrivileges;
    ULONG Flags;
    ACCESS_MASK RemainingDesiredAccess;
    ACCESS_MASK PreviouslyGrantedAccess;
    ACCESS_MASK OriginalDesiredAccess;
    PSECURITY_DESCRIPTOR SecurityDescriptor;
    UNICODE_STRING ObjectName;
    UNICODE_STRING ObjectType;
}

alias _DOKAN_ACCESS_STATE DOKAN_ACCESS_STATE;
alias _DOKAN_ACCESS_STATE* PDOKAN_ACCESS_STATE;

/**
 * This structure is used for copying IO_SECURITY_CONTEXT from the kernel mode
 * driver into the user mode driver.
 * https://msdn.microsoft.com/en-us/library/windows/hardware/ff550613(v=vs.85).aspx
 */
struct _DOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE
{
    DOKAN_ACCESS_STATE_INTERMEDIATE AccessState;
    ACCESS_MASK DesiredAccess;
}

alias _DOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE DOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE;
alias _DOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE* PDOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE;

struct _DOKAN_IO_SECURITY_CONTEXT
{
    DOKAN_ACCESS_STATE AccessState;
    ACCESS_MASK DesiredAccess;
}

alias _DOKAN_IO_SECURITY_CONTEXT DOKAN_IO_SECURITY_CONTEXT;
alias _DOKAN_IO_SECURITY_CONTEXT* PDOKAN_IO_SECURITY_CONTEXT;

struct _CREATE_CONTEXT
{
    DOKAN_IO_SECURITY_CONTEXT_INTERMEDIATE SecurityContext;
    ULONG FileAttributes;
    ULONG CreateOptions;
    ULONG ShareAccess;
    ULONG FileNameLength;

    /// Offset from the beginning of this structure to the string
    ULONG FileNameOffset;
}

alias _CREATE_CONTEXT CREATE_CONTEXT;
alias _CREATE_CONTEXT* PCREATE_CONTEXT;

struct _CLEANUP_CONTEXT
{
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _CLEANUP_CONTEXT CLEANUP_CONTEXT;
alias _CLEANUP_CONTEXT* PCLEANUP_CONTEXT;

struct _CLOSE_CONTEXT
{
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _CLOSE_CONTEXT CLOSE_CONTEXT;
alias _CLOSE_CONTEXT* PCLOSE_CONTEXT;

struct _DIRECTORY_CONTEXT
{
    ULONG FileInformationClass;
    ULONG FileIndex;
    ULONG BufferLength;
    ULONG DirectoryNameLength;
    ULONG SearchPatternLength;
    ULONG SearchPatternOffset;
    WCHAR[1] DirectoryName;
    WCHAR[1] SearchPatternBase;
}

alias _DIRECTORY_CONTEXT DIRECTORY_CONTEXT;
alias _DIRECTORY_CONTEXT* PDIRECTORY_CONTEXT;

struct _READ_CONTEXT
{
    LARGE_INTEGER ByteOffset;
    ULONG BufferLength;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _READ_CONTEXT READ_CONTEXT;
alias _READ_CONTEXT* PREAD_CONTEXT;

struct _WRITE_CONTEXT
{
    LARGE_INTEGER ByteOffset;
    ULONG BufferLength;
    ULONG BufferOffset;
    ULONG RequestLength;
    ULONG FileNameLength;
    WCHAR[2] FileName;
    // "2" means to keep last null of contents to write
}

alias _WRITE_CONTEXT WRITE_CONTEXT;
alias _WRITE_CONTEXT* PWRITE_CONTEXT;

struct _FILEINFO_CONTEXT
{
    ULONG FileInformationClass;
    ULONG BufferLength;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _FILEINFO_CONTEXT FILEINFO_CONTEXT;
alias _FILEINFO_CONTEXT* PFILEINFO_CONTEXT;

struct _SETFILE_CONTEXT
{
    ULONG FileInformationClass;
    ULONG BufferLength;
    ULONG BufferOffset;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _SETFILE_CONTEXT SETFILE_CONTEXT;
alias _SETFILE_CONTEXT* PSETFILE_CONTEXT;

struct _VOLUME_CONTEXT
{
    ULONG FsInformationClass;
    ULONG BufferLength;
}

alias _VOLUME_CONTEXT VOLUME_CONTEXT;
alias _VOLUME_CONTEXT* PVOLUME_CONTEXT;

struct _LOCK_CONTEXT
{
    LARGE_INTEGER ByteOffset;
    LARGE_INTEGER Length;
    ULONG Key;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _LOCK_CONTEXT LOCK_CONTEXT;
alias _LOCK_CONTEXT* PLOCK_CONTEXT;

struct _FLUSH_CONTEXT
{
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _FLUSH_CONTEXT FLUSH_CONTEXT;
alias _FLUSH_CONTEXT* PFLUSH_CONTEXT;

struct _UNMOUNT_CONTEXT
{
    WCHAR[64] DeviceName;
    ULONG Option;
}

alias _UNMOUNT_CONTEXT UNMOUNT_CONTEXT;
alias _UNMOUNT_CONTEXT* PUNMOUNT_CONTEXT;

struct _SECURITY_CONTEXT
{
    SECURITY_INFORMATION SecurityInformation;
    ULONG BufferLength;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _SECURITY_CONTEXT SECURITY_CONTEXT;
alias _SECURITY_CONTEXT* PSECURITY_CONTEXT;

struct _SET_SECURITY_CONTEXT
{
    SECURITY_INFORMATION SecurityInformation;
    ULONG BufferLength;
    ULONG BufferOffset;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _SET_SECURITY_CONTEXT SET_SECURITY_CONTEXT;
alias _SET_SECURITY_CONTEXT* PSET_SECURITY_CONTEXT;

struct _EVENT_CONTEXT
{
    ULONG Length;
    ULONG MountId;
    ULONG SerialNumber;
    ULONG ProcessId;
    UCHAR MajorFunction;
    UCHAR MinorFunction;
    ULONG Flags;
    ULONG FileFlags;
    ULONG64 Context;
    union Operation
    {
        DIRECTORY_CONTEXT Directory;
        READ_CONTEXT Read;
        WRITE_CONTEXT Write;
        FILEINFO_CONTEXT File;
        CREATE_CONTEXT Create;
        CLOSE_CONTEXT Close;
        SETFILE_CONTEXT SetFile;
        CLEANUP_CONTEXT Cleanup;
        LOCK_CONTEXT Lock;
        VOLUME_CONTEXT Volume;
        FLUSH_CONTEXT Flush;
        UNMOUNT_CONTEXT Unmount;
        SECURITY_CONTEXT Security;
        SET_SECURITY_CONTEXT SetSecurity;
    };
}

alias _EVENT_CONTEXT EVENT_CONTEXT;
alias _EVENT_CONTEXT* PEVENT_CONTEXT;

enum WRITE_MAX_SIZE = (EVENT_CONTEXT_MAX_SIZE - EVENT_CONTEXT.sizeof - 256 * WCHAR.sizeof);

struct _EVENT_INFORMATION
{
    ULONG SerialNumber;
    NTSTATUS Status;
    ULONG Flags;
    union Operation
    {
        struct Directory
        {
            ULONG Index;
        };
        struct Create
        {
            ULONG Flags;
            ULONG Information;
        };
        struct Read
        {
            LARGE_INTEGER CurrentByteOffset;
        };
        struct Write
        {
            LARGE_INTEGER CurrentByteOffset;
        };
        struct Delete
        {
            UCHAR DeleteOnClose;
        };
        struct ResetTimeout
        {
            ULONG Timeout;
        };
        struct AccessToken
        {
            HANDLE Handle;
        };
    };
    ULONG64 Context;
    ULONG BufferLength;
    UCHAR[8] Buffer;
}

alias _EVENT_INFORMATION EVENT_INFORMATION;
alias _EVENT_INFORMATION* PEVENT_INFORMATION;

enum DOKAN_EVENT_ALTERNATIVE_STREAM_ON = 1;
enum DOKAN_EVENT_WRITE_PROTECT = 2;
enum DOKAN_EVENT_REMOVABLE = 4;
enum DOKAN_EVENT_MOUNT_MANAGER = 8;
enum DOKAN_EVENT_CURRENT_SESSION = 16;
enum DOKAN_EVENT_FILELOCK_USER_MODE = 32;

struct _EVENT_DRIVER_INFO
{
    ULONG DriverVersion;
    ULONG Status;
    ULONG DeviceNumber;
    ULONG MountId;
    WCHAR[64] DeviceName;
}

alias _EVENT_DRIVER_INFO EVENT_DRIVER_INFO;
alias _EVENT_DRIVER_INFO* PEVENT_DRIVER_INFO;

struct _EVENT_START
{
    ULONG UserVersion;
    ULONG DeviceType;
    ULONG Flags;
    WCHAR[260] MountPoint;
    WCHAR[64] UNCName;
    ULONG IrpTimeout;
}

alias _EVENT_START EVENT_START;
alias _EVENT_START* PEVENT_START;

struct _DOKAN_RENAME_INFORMATION
{
    BOOLEAN ReplaceIfExists;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _DOKAN_RENAME_INFORMATION DOKAN_RENAME_INFORMATION;
alias _DOKAN_RENAME_INFORMATION* PDOKAN_RENAME_INFORMATION;

struct _DOKAN_LINK_INFORMATION
{
    BOOLEAN ReplaceIfExists;
    ULONG FileNameLength;
    WCHAR[1] FileName;
}

alias _DOKAN_LINK_INFORMATION DOKAN_LINK_INFORMATION;
alias _DOKAN_LINK_INFORMATION* PDOKAN_LINK_INFORMATION;
