#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0

import os
import re
import stat
import struct
import sys

TARGET_VERMAGIC = b"4.9.269 SMP preempt mod_unload modversions aarch64"
TARGET_DEPENDS = b"dv_compat_shim"
TARGET_MODNAME = b"dovi5"

STRTAB_OLD = b"unregister_dv_functions"
STRTAB_NEW = b"unregister_dv5shim_func"

RENAME_MAP = {
    b"register_dv_functions": b"register_dv5shim_func",
    b"unregister_dv_functions": b"unregister_dv5shim_func",
}

IDENTITY_IMPORT = b"get_cpu_type_from_media"

TARGET_INIT_OFFSET = 0x158
TARGET_EXIT_OFFSET = 0x300

MIN_KERNEL_EXPORTS = 1000
MAX_MODULE_BYTES = 64 * 1024 * 1024

RC_OK = 0
RC_USAGE = 1
RC_INVALID = 2
RC_UNRESOLVED = 3
RC_IO = 4
RC_INTERNAL = 5

SHT_NOBITS = 8
SHT_SYMTAB = 2
SHT_RELA = 4
SHF_ALLOC = 0x2
ET_REL = 1
EM_AARCH64 = 183
SHDR_SIZE = 64

_changed = []


def fail(msg, rc=RC_IO):
    sys.stdout.flush()
    sys.stderr.write("dv5-patch: ERROR: " + msg + "\n")
    sys.stderr.flush()
    sys.exit(rc)


def note(msg):
    sys.stdout.write(msg + "\n")


MODINFO_SIZE_MAX = 1 << 20


def read_sections(data):
    if len(data) < 0x40 or data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return None
    if struct.unpack_from("<H", data, 0x10)[0] != ET_REL:
        return None
    if struct.unpack_from("<H", data, 0x12)[0] != EM_AARCH64:
        return None
    e_shoff = struct.unpack_from("<Q", data, 0x28)[0]
    e_shentsize = struct.unpack_from("<H", data, 0x3a)[0]
    e_shnum = struct.unpack_from("<H", data, 0x3c)[0]
    e_shstrndx = struct.unpack_from("<H", data, 0x3e)[0]
    if e_shoff == 0 or e_shnum == 0 or e_shstrndx >= e_shnum:
        return None
    if e_shentsize < SHDR_SIZE:
        return None
    if e_shoff + e_shnum * e_shentsize > len(data):
        return None
    secs = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        name, typ, sh_flags, _ad, sh_off, sh_size, sh_link, sh_info = struct.unpack_from(
            "<IIQQQQII", data, off)
        if typ != SHT_NOBITS and sh_off + sh_size > len(data):
            return None
        secs.append({"hdr": off, "name_off": name, "off": sh_off,
                     "size": sh_size, "type": typ, "link": sh_link,
                     "info": sh_info, "flags": sh_flags})
    shstr = secs[e_shstrndx]
    if shstr["type"] == SHT_NOBITS or shstr["size"] == 0:
        return None
    str_off, str_end = shstr["off"], shstr["off"] + shstr["size"]
    for s in secs:
        if s["name_off"] >= shstr["size"]:
            return None
        try:
            end = data.index(b"\x00", str_off + s["name_off"], str_end)
        except ValueError:
            return None
        s["name"] = data[str_off + s["name_off"]:end].decode(errors="replace")
    byname = {}
    for s in secs:
        if s["name"] in byname:
            return None
        byname[s["name"]] = s
    sym = byname.get(".symtab")
    if sym is not None:
        if sym["type"] != SHT_SYMTAB:
            return None
        if sym["link"] == 0 or sym["link"] >= len(secs):
            return None
        byname[".strtab"] = secs[sym["link"]]
    _mi = byname.get(".modinfo")
    if _mi is not None and _mi["size"] > MODINFO_SIZE_MAX:
        return None
    for _n, _f in ((".modinfo", SHF_ALLOC),
                   (".gnu.linkonce.this_module", SHF_ALLOC),
                   ("__versions", SHF_ALLOC)):
        _s = byname.get(_n)
        if _s is not None and not (_s["flags"] & _f):
            return None
    byname[0] = secs
    return byname


def modinfo_get(buf, base, size, key):
    pos = base
    limit = base + size
    prefix = key + b"="
    while pos < limit:
        end = buf.find(b"\x00", pos, limit)
        if end < 0:
            break
        if buf.find(prefix, pos, end) == pos:
            return bytes(buf[pos + len(prefix):end]), pos, end - pos
        pos = end + 1
    return None, None, None


def patch_modinfo_kv(buf, base, size, key, newval, required=True):
    old, at, full_len = modinfo_get(buf, base, size, key)
    if old is None:
        if required:
            fail("%s= not found in .modinfo" % key.decode(), RC_INVALID)
        return None
    if old == newval:
        note("%s: already %r" % (key.decode(), newval.decode(errors="replace")))
        return old
    repl = key + b"=" + newval
    if len(repl) > full_len:
        fail("new %s too long (%d > %d)" % (key.decode(), len(repl), full_len), RC_INVALID)
    buf[at:at + full_len] = repl + b"\x00" * (full_len - len(repl))
    note("%s: %r -> %r" % (key.decode(), old.decode(errors="replace"),
                           newval.decode(errors="replace")))
    _changed.append(key.decode())
    return old


def module_name(buf, byname):
    sec = byname.get(".gnu.linkonce.this_module")
    if not sec:
        return None, None, None
    lo, hi = sec["off"], sec["off"] + sec["size"]
    m = re.search(rb"[ -~]{3,}", memoryview(buf)[lo:hi])
    if not m:
        return None, None, None
    return m.group(), lo + m.start(), len(m.group())


def patch_module_name(buf, byname, newname):
    old, start, length = module_name(buf, byname)
    if old is None:
        note("module-name: .gnu.linkonce.this_module absent (skip)")
        return
    if old == newname:
        note("module-name: already %r" % newname.decode())
        return
    if len(newname) > length:
        fail("new module name longer than slot (%d > %d)" % (len(newname), length), RC_INVALID)
    buf[start:start + length] = newname + b"\x00" * (length - len(newname))
    note("module-name: %r -> %r (struct module .name)" % (old.decode(), newname.decode()))
    _changed.append("module-name")


def symbols(buf, byname):
    sym = byname.get(".symtab")
    strt = byname.get(".strtab")
    if not sym or not strt:
        return []
    out = []
    for i in range(sym["size"] // 24):
        off = sym["off"] + i * 24
        st_name, st_info, _o, st_shndx, _v, _s = struct.unpack_from("<IBBHQQ", buf, off)
        if not st_name or st_name >= strt["size"]:
            continue
        try:
            end = buf.index(b"\x00", strt["off"] + st_name,
                            strt["off"] + strt["size"])
        except ValueError:
            continue
        out.append((bytes(buf[strt["off"] + st_name:end]), st_shndx))
    return out


def undefined_symbols(buf, byname):
    return sorted({n for n, shndx in symbols(buf, byname) if shndx == 0})


def exported_symbols(buf, byname):
    out = set()
    for n, shndx in symbols(buf, byname):
        if shndx != 0 and n.startswith(b"__ksymtab_"):
            out.add(n[len(b"__ksymtab_"):])
    return out


def _symtab_name(buf, byname, idx):
    sym = byname.get(".symtab")
    strt = byname.get(".strtab")
    if not sym or not strt:
        return None
    if idx >= sym["size"] // 24:
        return None
    if sym["off"] + idx * 24 + 24 > len(buf):
        return None
    st_name = struct.unpack_from("<I", buf, sym["off"] + idx * 24)[0]
    if st_name >= strt["size"]:
        return None
    try:
        end = buf.index(b"\x00", strt["off"] + st_name,
                        strt["off"] + strt["size"])
    except ValueError:
        return None
    return bytes(buf[strt["off"] + st_name:end])


def this_module_relocs(buf, byname):
    rela = byname.get(".rela.gnu.linkonce.this_module")
    if not rela:
        return []
    secs = byname.get(0) or []
    tm = byname.get(".gnu.linkonce.this_module")
    sym = byname.get(".symtab")
    if rela["type"] != SHT_RELA:
        return []
    if rela["link"] >= len(secs) or secs[rela["link"]] is not sym:
        return []
    if tm is None or rela["info"] >= len(secs) or secs[rela["info"]] is not tm:
        return []
    tm_idx = secs.index(tm)
    if sum(1 for x in secs if x["type"] == SHT_RELA and x["info"] == tm_idx) != 1:
        return []
    out = []
    for i in range(rela["size"] // 24):
        ent = rela["off"] + i * 24
        r_offset, r_info = struct.unpack_from("<QQ", buf, ent)
        out.append((ent, r_offset, _symtab_name(buf, byname, r_info >> 32)))
    return out


def patch_struct_offsets(buf, byname, init_off, exit_off):
    tm = byname.get(".gnu.linkonce.this_module")
    if tm is None or tm["type"] == SHT_NOBITS:
        fail("no usable .gnu.linkonce.this_module to relocate", RC_INVALID)
    want = {b"init_module": init_off, b"cleanup_module": exit_off}
    for _nm, _off in want.items():
        if _off % 8 or _off + 8 > tm["size"]:
            fail("%s reloc offset 0x%x does not fit .gnu.linkonce.this_module "
                 "(size 0x%x)" % (_nm.decode(), _off, tm["size"]), RC_INVALID)
    for ent, r_offset, name in this_module_relocs(buf, byname):
        if name in want and want[name] != r_offset:
            struct.pack_into("<Q", buf, ent, want[name])
            note("this_module %s reloc: r_offset 0x%x -> 0x%x"
                 % (name.decode(), r_offset, want[name]))
            _changed.append("reloc-" + name.decode())


def load(path, rc=RC_INVALID):
    try:
        st = os.stat(path)
    except OSError as e:
        fail("cannot stat %s: %s" % (path, e), rc)
    if not stat.S_ISREG(st.st_mode):
        fail("%s is not a regular file" % path, rc)
    size = st.st_size
    if size > MAX_MODULE_BYTES:
        fail("%s is %d bytes, over the %d-byte kernel-module limit"
             % (path, size, MAX_MODULE_BYTES), rc)
    try:
        with open(path, "rb") as f:
            data = bytearray(f.read(MAX_MODULE_BYTES + 1))
    except OSError as e:
        fail("cannot read %s: %s" % (path, e), rc)
    except MemoryError:
        fail("out of memory reading %s (%d bytes)" % (path, size), rc)
    if len(data) > MAX_MODULE_BYTES:
        fail("%s exceeds the %d-byte kernel-module limit"
             % (path, MAX_MODULE_BYTES), rc)
    return data


def reference_targets(path):
    buf = load(path, RC_IO)
    byname = read_sections(buf)
    if not byname:
        fail("reference %s is not a usable ELF64 object (bad header, section table, "
             "or duplicate section name)" % path)
    for n in (".modinfo", ".symtab", ".strtab"):
        if n not in byname or byname[n]["type"] == SHT_NOBITS:
            fail("reference %s has no usable %s" % (path, n))
    rela = byname.get(".rela.gnu.linkonce.this_module")
    if rela is None or rela["type"] == SHT_NOBITS or rela["size"] == 0:
        fail("reference %s has no usable this_module relocation section" % path)
    mi = byname.get(".modinfo")
    vm = None
    if mi:
        vm, _, _ = modinfo_get(buf, mi["off"], mi["size"], b"vermagic")
    if not vm:
        fail("no vermagic in reference %s" % path)
    if any(b < 0x20 or b > 0x7e for b in vm):
        fail("reference %s has a corrupt vermagic" % path)
    if not re.match(rb"^[0-9]+\.[0-9]+\.[0-9]+[^ ]* ", vm):
        fail("reference %s vermagic %r is not a kernel vermagic"
             % (path, vm.decode(errors="replace")))
    if not re.match(rb"^[0-9A-Za-z._+-]+( [0-9A-Za-z._+-]+)+$", vm):
        fail("reference %s vermagic %r is malformed"
             % (path, vm.decode(errors="replace")))
    if vm.split()[-1] != TARGET_VERMAGIC.split()[-1]:
        fail("reference %s vermagic %r does not end in the expected arch %r"
             % (path, vm.decode(errors="replace"),
                TARGET_VERMAGIC.split()[-1].decode()))
    if b"mod_unload" not in vm.split():
        fail("reference %s vermagic %r lacks mod_unload"
             % (path, vm.decode(errors="replace")))
    init_off = exit_off = None
    for _e, r_offset, name in this_module_relocs(buf, byname):
        if name == b"init_module":
            init_off = r_offset
        elif name == b"cleanup_module":
            exit_off = r_offset
    if init_off is None or exit_off is None:
        fail("reference %s lacks an init_module or cleanup_module relocation" % path)
    rtm = byname.get(".gnu.linkonce.this_module")
    if rtm is None or rtm["type"] == SHT_NOBITS or rtm["size"] == 0:
        fail("reference %s has no usable .gnu.linkonce.this_module" % path)
    for _nm, _off in ((b"init_module", init_off), (b"cleanup_module", exit_off)):
        if _off % 8 or _off + 8 > rtm["size"]:
            fail("reference %s has an out-of-range %s offset 0x%x (section size 0x%x)"
                 % (path, _nm.decode(), _off, rtm["size"]))
    return vm, init_off, exit_off, exported_symbols(buf, byname)


def kernel_exports(path):
    out = set()
    try:
        if not stat.S_ISREG(os.stat(path).st_mode):
            return set()
    except OSError:
        return set()
    try:
        with open(path, "r", errors="replace") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 3 and parts[2].startswith("__ksymtab_"):
                    out.add(parts[2][len("__ksymtab_"):].encode())
    except OSError:
        return set()
    return out


def count_between(buf, needle, lo, hi):
    n = 0
    i = buf.find(needle, lo, hi)
    while i != -1:
        n += 1
        i = buf.find(needle, i + 1, hi)
    return n


def identity(buf, byname):
    if byname is None:
        return "not a usable ELF64 object (bad header or section table, duplicate section name, or a required section not allocated)"
    if ".modinfo" not in byname:
        return ".modinfo section missing"
    if ".symtab" not in byname or ".strtab" not in byname:
        return "symbol table missing"
    for n in (".modinfo", ".symtab", ".strtab"):
        if byname[n]["type"] == SHT_NOBITS:
            return "%s has no file data" % n
    rela = byname.get(".rela.gnu.linkonce.this_module")
    if not rela or rela["type"] == SHT_NOBITS or rela["size"] == 0:
        return "this_module relocations missing"
    names = [n for _e, _r, n in this_module_relocs(buf, byname)]
    for want in (b"init_module", b"cleanup_module"):
        if want not in names:
            return "no %s relocation" % want.decode()
    st = byname[".strtab"]
    n_old = count_between(buf, STRTAB_OLD, st["off"], st["off"] + st["size"])
    n_new = count_between(buf, STRTAB_NEW, st["off"], st["off"] + st["size"])
    if n_old == 0 and n_new == 0:
        return "no Dolby Vision registration symbol in .strtab"
    if n_old > 1:
        return "multiple %r in .strtab" % STRTAB_OLD.decode()
    if IDENTITY_IMPORT not in undefined_symbols(buf, byname):
        return "does not import %s" % IDENTITY_IMPORT.decode()
    tm = byname.get(".gnu.linkonce.this_module")
    if tm is None or tm["type"] == SHT_NOBITS or tm["size"] == 0:
        return ".gnu.linkonce.this_module missing or empty"
    if module_name(buf, byname)[0] is None:
        return "no readable module name in .gnu.linkonce.this_module"
    for _e, _ro, _nm in this_module_relocs(buf, byname):
        if _nm in (b"init_module", b"cleanup_module") and _ro + 8 > tm["size"]:
            return ("%s relocation at 0x%x lies outside .gnu.linkonce.this_module "
                    "(size 0x%x)" % (_nm.decode(), _ro, tm["size"]))
    mi = byname[".modinfo"]
    if modinfo_get(buf, mi["off"], mi["size"], b"vermagic")[0] is None:
        return "no vermagic in .modinfo"
    return None


def is_patched(buf, byname, vermagic, init_off, exit_off):
    mi = byname[".modinfo"]
    vm, _, _ = modinfo_get(buf, mi["off"], mi["size"], b"vermagic")
    dep, _, _ = modinfo_get(buf, mi["off"], mi["size"], b"depends")
    if vm != vermagic or dep != TARGET_DEPENDS:
        return False
    nm, _o, _l2 = modinfo_get(buf, mi["off"], mi["size"], b"name")
    if nm is not None and nm != TARGET_MODNAME:
        return False
    name, _s, _l = module_name(buf, byname)
    if name != TARGET_MODNAME:
        return False
    st = byname[".strtab"]
    if (count_between(buf, STRTAB_OLD, st["off"], st["off"] + st["size"]) != 0 or
            count_between(buf, STRTAB_NEW, st["off"], st["off"] + st["size"]) < 1):
        return False
    ver = byname.get("__versions")
    if ver and ver["size"] != 0:
        return False
    if surviving_old_names(buf, byname):
        return False
    want = {b"init_module": init_off, b"cleanup_module": exit_off}
    for _ent, r_offset, name in this_module_relocs(buf, byname):
        if name in want and want[name] != r_offset:
            return False
    return True


def surviving_old_names(buf, byname):
    return [s.decode(errors="replace")
            for s in undefined_symbols(buf, byname) if s in RENAME_MAP]


def resolve(buf, byname, allowed):
    missing = []
    for s in undefined_symbols(buf, byname):
        if RENAME_MAP.get(s, s) not in allowed:
            missing.append(RENAME_MAP.get(s, s).decode(errors="replace"))
    return missing


def do_patch(buf, byname, vermagic, init_off, exit_off):
    mi = byname[".modinfo"]
    patch_modinfo_kv(buf, mi["off"], mi["size"], b"vermagic", vermagic)
    patch_modinfo_kv(buf, mi["off"], mi["size"], b"depends", TARGET_DEPENDS)
    patch_modinfo_kv(buf, mi["off"], mi["size"], b"name", TARGET_MODNAME, required=False)
    patch_module_name(buf, byname, TARGET_MODNAME)

    st = byname[".strtab"]
    lo, hi = st["off"], st["off"] + st["size"]
    idx = buf.find(STRTAB_OLD, lo, hi)
    if idx < 0:
        if count_between(buf, STRTAB_NEW, lo, hi) >= 1:
            note("strtab: already %r" % STRTAB_NEW.decode())
        else:
            fail("%r not found in .strtab" % STRTAB_OLD.decode(), RC_INVALID)
    else:
        if buf.find(STRTAB_OLD, idx + len(STRTAB_OLD), hi) >= 0:
            fail("multiple %r in .strtab; aborting (suffix-share assumption broken)"
                 % STRTAB_OLD.decode(), RC_INVALID)
        buf[idx:idx + len(STRTAB_NEW)] = STRTAB_NEW
        note("strtab: %r -> %r at 0x%x; shared register symbol -> %r"
             % (STRTAB_OLD.decode(), STRTAB_NEW.decode(), idx, STRTAB_NEW[2:].decode()))
        _changed.append("strtab")

    ver = byname.get("__versions")
    if not ver:
        note("__versions: section absent (nothing to zero)")
    elif ver["size"] == 0:
        note("__versions: already 0")
    else:
        struct.pack_into("<Q", buf, ver["hdr"] + 0x20, 0)
        note("__versions: sh_size %d -> 0" % ver["size"])
        _changed.append("__versions")

    patch_struct_offsets(buf, byname, init_off, exit_off)


def parse_opts(argv):
    ref = None

    ksyms = "/proc/kallsyms"
    rest = []
    i = 0
    while i < len(argv):
        if argv[i] == "--ref" and i + 1 < len(argv):
            ref = argv[i + 1]
            if not ref:
                usage()
            i += 2
        elif argv[i] == "--ksyms" and i + 1 < len(argv):
            ksyms = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    return ref, ksyms, rest


def allowed_set(ref, ksyms):
    vermagic, init_off, exit_off = TARGET_VERMAGIC, TARGET_INIT_OFFSET, TARGET_EXIT_OFFSET
    shim = set()
    if ref:
        vermagic, init_off, exit_off, shim = reference_targets(ref)
        note("reference: %s" % ref)
    kern = kernel_exports(ksyms) if os.path.exists(ksyms) else set()
    if len(kern) < MIN_KERNEL_EXPORTS:
        note("symbols: only %d kernel exports readable from %s; link check skipped"
             % (len(kern), ksyms))
        return vermagic, init_off, exit_off, None, len(shim), len(kern)
    return vermagic, init_off, exit_off, shim | kern, len(shim), len(kern)


def usage():
    sys.stderr.write(
        "usage: dv5-patch-dovi.py check <blob> [--ref <shim.ko>] [--ksyms <path>]\n"
        "       dv5-patch-dovi.py patch <in.ko> <out.ko> [--ref <shim.ko>] [--ksyms <path>]\n"
        "exit: 0 ok, 1 usage, 2 invalid module, 3 unresolved symbols,\n"
        "      4 io or malformed argument, 5 internal error\n")
    sys.exit(RC_USAGE)


def main():
    ref, ksyms, args = parse_opts(sys.argv[1:])
    if len(args) < 2:
        usage()
    cmd = args[0]

    if cmd == "check" and len(args) == 2:
        buf = load(args[1])
        byname = read_sections(buf)
        bad = identity(buf, byname)
        if bad:
            note("STATUS=invalid")
            note("REASON=%s" % bad)
            sys.exit(RC_INVALID)
        vermagic, init_off, exit_off, allowed, n_shim, n_kern = allowed_set(ref, ksyms)
        note("symbols: %d from shim + %d from kernel" % (n_shim, n_kern))
        missing = resolve(buf, byname, allowed) if allowed else []
        if missing:
            note("STATUS=unresolved")
            note("REASON=missing symbols: %s" % " ".join(missing))
            sys.exit(RC_UNRESOLVED)
        patched = is_patched(buf, byname, vermagic, init_off, exit_off)
        note("STATUS=%s" % ("patched" if patched else "unpatched"))
        sys.exit(RC_OK)

    if cmd == "patch" and len(args) == 3:
        buf = load(args[1])
        byname = read_sections(buf)
        bad = identity(buf, byname)
        if bad:
            fail(bad, RC_INVALID)
        vermagic, init_off, exit_off, allowed, n_shim, n_kern = allowed_set(ref, ksyms)
        do_patch(buf, byname, vermagic, init_off, exit_off)
        byname = read_sections(buf)
        bad = identity(buf, byname)
        if bad:
            fail("post-patch validation: %s" % bad, RC_INVALID)
        left = surviving_old_names(buf, byname)
        if left:
            fail("post-patch validation: old symbol names survive the rename: %s"
                 % " ".join(left), RC_INVALID)
        if not is_patched(buf, byname, vermagic, init_off, exit_off):
            fail("post-patch validation: markers still incomplete", RC_INVALID)
        if allowed:
            missing = resolve(buf, byname, allowed)
            if missing:
                fail("post-patch validation: unresolved symbols: %s" % " ".join(missing),
                     RC_UNRESOLVED)
            note("post-patch: all imports resolve (%d shim + %d kernel)" % (n_shim, n_kern))
        tmp = "%s.tmp.%d" % (args[2], os.getpid())
        try:
            mode = None
            try:
                mode = os.stat(args[2]).st_mode & 0o7777
            except OSError:
                pass
            with open(tmp, "wb") as f:
                f.write(buf)
                f.flush()
                os.fsync(f.fileno())
            if os.path.getsize(tmp) != len(buf):
                raise OSError("short write")
            if mode is not None:
                os.chmod(tmp, mode)
            os.replace(tmp, args[2])
            d = os.open(os.path.dirname(os.path.abspath(args[2])), os.O_RDONLY)
            try:
                os.fsync(d)
            finally:
                os.close(d)
        except OSError as e:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            fail("cannot write %s: %s" % (args[2], e))
        note("wrote %s (%d bytes, %d fields changed)" % (args[2], len(buf), len(_changed)))
        sys.exit(RC_OK)

    usage()


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        try:
            _stream.reconfigure(errors="replace")
        except (AttributeError, OSError):
            pass
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        sys.stdout.flush()
        sys.stderr.write("dv5-patch: ERROR: internal: %r\n" % (exc,))
        sys.exit(RC_INTERNAL)
