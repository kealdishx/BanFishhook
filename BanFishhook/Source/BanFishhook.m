//
//  BanFishhook.m
//  BanFishhook
//
//  Created by Kealdish on 2020/5/23.
//  Copyright © 2020 Kealdish. All rights reserved.
//

#include <dlfcn.h>
#include <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>

#import "BanFishhook.h"

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

static int8_t stub_helper_section_name[16] = {0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00};
static inline void reset_symbol_for_image(const char *symbol, const struct mach_header *header, intptr_t slide);
static inline void rebind_lazy_symbol(const char *symbol, const struct mach_header *header, intptr_t slide, segment_command_t *text_segment, uintptr_t lazy_bind_info_cmd, uint32_t lazy_bind_info_size);


void reset_symbol(const char *symbol) {
    int32_t count = _dyld_image_count();
    for (int32_t i = 0; i < count; i++) {
        reset_symbol_for_image(symbol, _dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
    }
}

static inline void reset_symbol_for_image(const char *symbol, const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) {
        return;
    }
    
    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    segment_command_t *text_segment = NULL;
    struct dyld_info_command *dyld_info_cmd = NULL;
    
    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_DYLD_INFO_ONLY || cur_seg_cmd->cmd == LC_DYLD_INFO) {
            dyld_info_cmd = (struct dyld_info_command *)cur_seg_cmd;
        } else if (strcmp(cur_seg_cmd->segname, SEG_TEXT) == 0) {
            text_segment = cur_seg_cmd;
        }
    }
    
    if (!linkedit_segment || !text_segment || !dyld_info_cmd) {
        return;
    }
    
    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    uintptr_t lazy_bind_info_cmd = linkedit_base + dyld_info_cmd->lazy_bind_off;
    rebind_lazy_symbol(symbol, header, slide, text_segment, lazy_bind_info_cmd, dyld_info_cmd->lazy_bind_size);
}

static inline bool rebind_lazy_symbol(const char *symbol, const struct mach_header *header, intptr_t slide, segment_command_t *text_segment, uintptr_t lazy_bind_info_cmd, uint32_t lazy_bind_info_size) {
    if (!lazy_bind_info_cmd) {
        return false;
    }
    
    section_t *stub_helper_section = NULL;
    for (uint i = 0; i < text_segment->nsects; i++) {
        section_t *cur_section = (section_t *)((uintptr_t)text_segment + sizeof(mach_header_t) + sizeof(segment_command_t)) + i;
        char *sectname = cur_section->sectname;
        if (sectname[0] == stub_helper_section_name[0]
            && sectname[1] == stub_helper_section_name[1]
            && sectname[2] == stub_helper_section_name[2]
            && sectname[3] == stub_helper_section_name[3]
            && sectname[4] == stub_helper_section_name[4]
            && sectname[5] == stub_helper_section_name[5]
            && sectname[6] == stub_helper_section_name[6]
            && sectname[7] == stub_helper_section_name[7]
            && sectname[8] == stub_helper_section_name[8]
            && sectname[9] == stub_helper_section_name[9]
            && sectname[10] == stub_helper_section_name[10]
            && sectname[11] == stub_helper_section_name[11]
            && sectname[12] == stub_helper_section_name[12]) {
            stub_helper_section = cur_section;
            break;
        }
        
        if (!stub_helper_section) {
            return false;
        }
        
        intptr_t stub_helper_vm_addr = slide + stub_helper_section->addr;
        
        if (!stub_helper_vm_addr) {
            return false;
        }
        
        return true;
    }
    
}

// https://developer.apple.com/documentation/kernel/nlist_64/1583957-n_desc?language=objc
static bool get_library_ordinal(uint16_t value, int *result) {
    //  REFERENCE_FLAG_UNDEFINED_NON_LAZY = 0x0
    if ((value & 0x00ff) == 0x0) {
        *result = ((value >> 8) & 0xff);
        return true;
    }
    return false;
}

static void get_all_load_dyld(const struct mach_header *header, intptr_t slide) {
    
}
