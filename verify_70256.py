"""Read-only input verification and in-memory patch simulation for 7.0.256.
Usage: python verify_70256.py path/to/Arc-mobile-or.ipa
Optional deeper inspection: pip install lief
The input is never written; no dylib or iOS execution is involved.
"""
import contextlib
import hashlib
import io
import pathlib
import struct
import sys
import tempfile
import zipfile
import inject


def main():
    path = pathlib.Path(sys.argv[1])
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            names = [n for n in z.namelist() if n.endswith('.app/Arc-mobile')]
            if len(names) != 1:
                raise RuntimeError('expected exactly one Arc-mobile executable')
            original = z.read(names[0])
    else:
        original = path.read_bytes()
    expected = 'fb91157e7c90ede63be3d0051ed2208dcc600c64e1ca53ffece25d267345416f'
    if hashlib.sha256(original).hexdigest() != expected:
        raise RuntimeError('input differs from the original sample; full simulation requires that sample')
    base = inject.validate_target(original)
    inject.validate_sites(original, base)
    patched = bytearray(original)
    inject.patch_judge_stub(patched)
    inject.patch_brk_hooks(patched, None)
    inject.insert_load_commands_inplace(patched, 0)
    with tempfile.TemporaryDirectory() as tmp:
        output = pathlib.Path(tmp) / 'patched.macho'
        def check(raw):
            output.write_bytes(raw)
            with contextlib.redirect_stdout(io.StringIO()):
                return inject.check_binary(str(output))
        assert check(patched) == 0
        damaged = bytearray(patched)
        damaged[inject.STUB_ENTRY_FILE] ^= 1
        assert check(damaged) == 2
        damaged = bytearray(patched)
        damaged[inject.STUB_TRAMP_FILE + 28] ^= 1
        assert check(damaged) == 2
        restored = bytearray(patched)
        inject.patch_brk_hooks(restored, set())
        for name, va, replay, expected in inject.BRK_HOOKS:
            off = va - 0x100000000
            assert restored[off:off + 4].hex() == expected, name
            if replay:
                branch_pc = replay + 4
                word = struct.unpack_from('<I', patched, branch_pc - 0x100000000)[0]
                assert word & 0xFC000000 == 0x14000000
                imm = word & 0x3FFFFFF
                if imm & 0x2000000: imm -= 0x4000000
                assert branch_pc + imm * 4 == va + 4
        assert patched[0x1654000:] == original[0x1650000:]
        print('PASS: original identity, 40 sites, replay targets, corruption rejection, restore, LINKEDIT bytes')
        try:
            import lief
        except ImportError:
            print('LIEF not installed; independent parser verification skipped')
        else:
            pristine = pathlib.Path(tmp) / 'original.macho'
            pristine.write_bytes(original)
            output.write_bytes(patched)
            before = lief.MachO.parse(str(pristine)).at(0)
            after = lief.MachO.parse(str(output)).at(0)
            assert lief.MachO.check_layout(after)[0]
            assert [(x.name, x.value) for x in before.symbols] == [(x.name, x.value) for x in after.symbols]
            assert [(x.address, x.type) for x in before.relocations] == [(x.address, x.type) for x in after.relocations]
            assert [(x.address, x.symbol.name) for x in before.bindings] == [(x.address, x.symbol.name) for x in after.bindings]
            assert [(x.name, x.virtual_address, x.size) for x in before.sections] == [(x.name, x.virtual_address, x.size) for x in after.sections]
            print('PASS: independent LIEF layout, symbols, relocations, bindings and sections')
    print('Static simulation only. The input was not modified. iOS build and device testing remain outstanding.')


if __name__ == '__main__':
    main()
