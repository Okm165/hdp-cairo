from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_single, poseidon_hash, poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountState, SlotState
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.uint256 import Uint256



struct MemAction {
    key: felt,
    value: felt,
}

namespace HeaderMemorizer {
    func initialize{}() -> (header_reads: MemAction*, header_writes: MemAction*){
        let (header_writes: MemAction*) = alloc();
        let (header_reads: MemAction*) = alloc();

        %{
            headers = {}
        %}

        return (header_reads=header_reads, header_writes=header_writes);
    }

    func write{
        header_writes: MemAction*,
    }(key: felt, value: felt){
        assert [header_writes] = MemAction(key=key, value=value);
        let header = [header_writes];

        %{
            headers[ids.key] = ids.value
        %}

        let header_writes = header_writes + MemAction.SIZE;
        return ();
    }

    func read{
        header_reads: MemAction*,
    }(key: felt) -> (value: felt){
        alloc_locals;
        local value: felt;

        %{
            value = headers[ids.key]
            ids.value = value
        %}

        assert [header_reads] = MemAction(key=key, value=value);
        let header_reads = header_reads + MemAction.SIZE;

        return (value=value);
    }

    // ensure that all reads correspond to writes
    func validate_reads{
        header_writes: MemAction*,
        writes_start: MemAction*,
        header_reads: MemAction*,
        reads_start: MemAction*,
    }(){
        alloc_locals;
        local reads_len = (header_reads - reads_start) / MemAction.SIZE;

        %{
            # map write key to its cairo index
            write_indices = {}
            for i in range(len(headers)):
                write_key = memory[ids.writes_start.address_ + ids.MemAction.SIZE * i]
                write_indices[write_key] = i
            
            # for each read, find the corresponding write index and add to array        
            read_to_write_indices = []
            for i in range(ids.reads_len):
                key = memory[ids.reads_start.address_ + ids.MemAction.SIZE * i]
                read_to_write_indices.append(write_indices[key])
        %}

        validate_reads_inner{
            writes_start=writes_start,
            reads_start=reads_start,
        }(reads_len=reads_len);
        
        return ();
    }

    func validate_reads_inner{
        writes_start: MemAction*,
        reads_start: MemAction*,
    }(reads_len: felt) {
        alloc_locals;
        if (reads_len == 0) {
            return ();
        }

        let read_action = reads_start[reads_len - 1];
        local write_idx: felt;
        
        // there is only one valid index for each element, so reading form hint is ok
        %{ ids.write_idx = read_to_write_indices[ids.reads_len - 1] %}

        let write_action = writes_start[write_idx];

        assert 0 = read_action.key - write_action.key;
        assert 0 = read_action.value - write_action.value;

        return validate_reads_inner{
            writes_start=writes_start,
            reads_start=reads_start,
        }(reads_len=reads_len-1);
    }
}

func main{}() {
    alloc_locals;

    let (header_reads, header_writes) = HeaderMemorizer.initialize{}();
    tempvar reads_start = header_reads;
    tempvar writes_start = header_writes;

    HeaderMemorizer.write{header_writes=header_writes}(key=111, value=222);

    let (value) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (value) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);
    let (val2) = HeaderMemorizer.read{header_reads=header_reads}(key=111);

    HeaderMemorizer.validate_reads{header_writes=header_writes, writes_start=writes_start, header_reads=header_reads, reads_start=reads_start}();

    return ();
    
}