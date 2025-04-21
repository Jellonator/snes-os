#!/usr/bin/python3

import json
import struct
import os

FILE_PATH = os.fsencode("static")
OUT_PATH = "include/staticdata.inc"

MAX_FILES_IN_DIR = 12
MAX_FILE_NAME_LENGTH = 14
MAX_FILE_SIZE = 4096+192

BASE_FILE_SIZE = 192
INDIRECT_BLOCK_FILE_SIZE = 256

out_inc = open(OUT_PATH, 'w')

nodelist = []

def read_file(path, name):
    with open(path, 'rb') as file:
        data = file.read()
        if len(data) > MAX_FILE_SIZE:
            print(f"WARN: File '{name}' exceeds {MAX_FILE_SIZE}B in size")
            return
        node_id = len(nodelist)
        node = {
            'type': 'file',
            'name': name,
            'size': len(data),
            'data': data[:192],
            'direct': [],
            'indirect': []
        }
        nodelist.append(node)
        num_required_direct_nodes = max(0, (len(data) + INDIRECT_BLOCK_FILE_SIZE - BASE_FILE_SIZE - 1) // INDIRECT_BLOCK_FILE_SIZE)
        # TODO: support indirect nodes
        for i in range(num_required_direct_nodes):
            base = BASE_FILE_SIZE + i * INDIRECT_BLOCK_FILE_SIZE
            subdata_id = len(nodelist)
            subdata = {
                'type': 'direct',
                'data': data[base:(base+INDIRECT_BLOCK_FILE_SIZE)]
            }
            nodelist.append(subdata)
            node['direct'].append(subdata_id)
        return node_id

def read_folder(parentpath, name):
    node_id = len(nodelist)
    node = {
        'type': 'dir',
        'name': name,
        'children': []
    }
    nodelist.append(node)
    for name in os.listdir(parentpath):
        if len(name) > MAX_FILE_NAME_LENGTH:
            print(f"WARN: Filename '{name}' in '{parentpath}' is too long")
            continue
        fullpath = os.path.join(parentpath, name)
        if os.path.isfile(fullpath):
            child_node_id = read_file(fullpath, name)
            if child_node_id != None:
                if len(node['children']) < MAX_FILES_IN_DIR:
                    node['children'].append(child_node_id)
                else:
                    print(f"WARN: too many files in '{parentpath}', exceeds {MAX_FILES_IN_DIR}.")
                    break
        else:
            child_node_id = read_folder(fullpath, name)
            if child_node_id != None:
                if len(node['children']) < MAX_FILES_IN_DIR:
                    node['children'].append(child_node_id)
                else:
                    print(f"WARN: too many files in '{parentpath}', exceeds {MAX_FILES_IN_DIR}.")
                    break
    return node_id

root_node_id = read_folder(FILE_PATH, "")

out_inc.write(".include \"base.inc\"\n")
out_inc.write(".FUNCTION inode(addr) ((bankbyte(addr) << 8) | hibyte(addr))\n")

section_id = 0

def format_bytes_ascii(s):
    return s.decode('ascii').replace('\n', '\\n')

def format_name_ascii(s):
    ret = format_bytes_ascii(s)
    if len(s) < MAX_FILE_NAME_LENGTH:
        return ret + "\\0"
    else:
        return ret

def write_direct(node_id):
    global section_id
    node = nodelist[node_id]
    section_id += 1
    out_inc.write(".SECTION \"static data {}\" SLOT \"ROM\" SEMISUPERFREE BANKS 127-0 ALIGN 256\n".format(section_id))
    out_inc.write(".DSTRUCT staticnode_data_{} INSTANCEOF fs_memdev_direct_data_block VALUES \n".format(node_id))
    out_inc.write("    data: .db \"{}\"\n".format(format_bytes_ascii(node['data'])))
    # END
    out_inc.write(".ENDST\n")
    out_inc.write(".ENDS\n")

def write_dir(node_id):
    global section_id
    node = nodelist[node_id]
    section_id += 1
    out_inc.write(".SECTION \"static data {}\" SLOT \"ROM\" SEMISUPERFREE BANKS 127-0 ALIGN 256\n".format(section_id))
    out_inc.write(".DSTRUCT staticnode_data_{} INSTANCEOF fs_memdev_inode_t VALUES \n".format(node_id))
    out_inc.write("    type .dw FS_INODE_TYPE_DIR\n")
    out_inc.write("    nlink .dw 1\n")
    out_inc.write("    size .dw {}, 0\n".format(len(node['children'])))
    out_inc.write("    inode_next .dw $0000\n")
    # nodes
    for i in range(len(node["children"])):
        out_inc.write("    dir.entries.{}.blockId .dw inode(staticnode_data_{})\n".format(i+1, node['children'][i]))
        out_inc.write("    dir.entries.{}.name .db \"{}\"\n".format(i+1, format_name_ascii(nodelist[node["children"][i]]['name'])))
    if len(node['children']) < MAX_FILES_IN_DIR:
        out_inc.write("    dir.entries.{}.blockId .dw 0\n".format(1+len(node['children'])))
    # END
    out_inc.write(".ENDST\n")
    out_inc.write(".ENDS\n")
    # iterate children
    for child_id in node["children"]:
        if nodelist[child_id]['type'] == 'dir':
            write_dir(child_id)
        elif nodelist[child_id]['type'] == 'file':
            write_file(child_id)

def write_file(node_id):
    global section_id
    node = nodelist[node_id]
    section_id += 1
    out_inc.write(".SECTION \"static data {}\" SLOT \"ROM\" SEMISUPERFREE BANKS 127-0 ALIGN 256\n".format(section_id))
    out_inc.write(".DSTRUCT staticnode_data_{} INSTANCEOF fs_memdev_inode_t VALUES \n".format(node_id))
    out_inc.write("    type .dw FS_INODE_TYPE_FILE\n")
    out_inc.write("    nlink .dw 1\n")
    out_inc.write("    size .dw {}, 0\n".format(node['size']))
    out_inc.write("    inode_next .dw $0000\n")
    # data
    out_inc.write("    file.directData .db \"{}\"\n".format(format_bytes_ascii(node['data'])))
    if len(node['direct']) > 0:
        out_inc.write("    file.directBlocks:\n")
        for i in range(len(node['direct'])):
            out_inc.write("        .dw inode(staticnode_data_{})\n".format(node['direct'][i]))
    # END
    out_inc.write(".ENDST\n")
    out_inc.write(".ENDS\n")
    # iterate subnodes
    for child_id in node['direct']:
        write_direct(child_id)

def write_root(node_id):
    global section_id
    node = nodelist[node_id]
    section_id += 1
    out_inc.write(".SECTION \"static data {}\" BANK $00 SLOT \"ROM\" ORGA $8000 FORCE\n".format(section_id))
    out_inc.write(".DSTRUCT INSTANCEOF fs_memdev_inode_t VALUES \n")
    out_inc.write("    type .dw FS_INODE_TYPE_ROOT\n")
    out_inc.write("    nlink .dw 0\n")
    out_inc.write("    size .dw {}, 0\n".format(len(node['children'])))
    out_inc.write("    inode_next .dw $0000\n")
    out_inc.write("    root.magicnum .db \"MEM\\0\"\n")
    # layout
    out_inc.write("    root.bank_first          .db $80\n")
    out_inc.write("    root.bank_last           .db $FF\n")
    out_inc.write("    root.page_first          .db $80\n")
    out_inc.write("    root.page_last           .db $FF\n")
    out_inc.write("    root.num_blocks_per_bank .db $80\n")
    out_inc.write("    root.num_banks           .db $80\n")
    out_inc.write("    root.num_blocks_total    .dw $4000\n")
    # nodes
    out_inc.write("    root.num_used_inodes  .dw {}\n".format(len(nodelist)))
    out_inc.write("    root.num_total_inodes .dw {}\n".format(0x4000))
    out_inc.write("    root.num_free_inodes  .dw {}\n".format(0x4000-len(nodelist)))
    for i in range(len(node["children"])):
        out_inc.write("    root.entries.{}.blockId .dw inode(staticnode_data_{})\n".format(i+1, node['children'][i]))
        out_inc.write("    root.entries.{}.name .db \"{}\"\n".format(i+1, format_name_ascii(nodelist[node["children"][i]]['name'])))
    if len(node['children']) < MAX_FILES_IN_DIR:
        out_inc.write("    root.entries.{}.blockId .dw 0\n".format(1+len(node['children'])))
    # END
    out_inc.write(".ENDST\n")
    out_inc.write(".ENDS\n")
    # iterate children
    for child_id in node["children"]:
        if nodelist[child_id]['type'] == 'dir':
            write_dir(child_id)
        elif nodelist[child_id]['type'] == 'file':
            write_file(child_id)

write_root(root_node_id)