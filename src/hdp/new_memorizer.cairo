from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_single, poseidon_hash, poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountState, SlotState
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

struct LogItem {
    key: felt,
    value: felt,
}

namespace HeaderMemorizer {
    func initialize{}() -> (read_log: LogItem*, write_log: LogItem*){
        let (write_log: LogItem*) = alloc();
        let (read_log: LogItem*) = alloc();

        %{
            headers = {}
        %}

        return (read_log=read_log, write_log=write_log);
    }

    func write{
        write_log: LogItem*,
    }(key: felt, value: felt){
        assert [write_log] = LogItem(key=key, value=value);
        let header = [write_log];

        %{  
            assert ids.key not in headers, f"Duplicate key! {ids.key} already exists"
            print(f"Writing: {ids.key} -> {ids.value}")
            headers[ids.key] = ids.value
        %}

        let write_log = write_log + LogItem.SIZE;
        return ();
    }

    // Read from memorizer
    func read{
        read_log: LogItem*,
    }(key: felt) -> (value: felt){
        alloc_locals;
        local value: felt;

        %{
            value = headers[ids.key]
            ids.value = value
        %}

        assert [read_log] = LogItem(key=key, value=value);
        let read_log = read_log + LogItem.SIZE;

        return (value=value);
    }

    // ensure that all reads correspond to writes
    func validate_reads{
        write_log: LogItem*,
        write_log_start: LogItem*,
        read_log: LogItem*,
        read_log_start: LogItem*,
    }(){
        alloc_locals;
        // compute in cairo, so we cant skip any reads
        let reads_len = (read_log - read_log_start) / LogItem.SIZE;

        %{
            # map write key to its cairo index
            write_segment_offsets = {}
            for i in range(len(headers)):
                write_address = ids.write_log_start.address_ + ids.LogItem.SIZE * i
                write_key = memory[write_address]
                write_segment_offsets[write_key] = write_address.offset
            
            # for each read, find the corresponding write index and add to array        
            read_to_write_offset = []
            for i in range(ids.reads_len):
                key = memory[ids.read_log_start.address_ + ids.LogItem.SIZE * i]
                read_to_write_offset.append(write_segment_offsets[key])
                
        %}

        validate_reads_inner{
            write_log_start=write_log_start,
        }( read_log=read_log-LogItem.SIZE, reads_len=reads_len);

        return ();
    }

    func validate_reads_inner{
        write_log_start: LogItem*,
    }(read_log: LogItem*, reads_len: felt) {
        alloc_locals;

        local write_key: felt;
        local write_value: felt;
        %{ 
            # Is the correct memory segment enforced here? Or could an attacker point us to a different one?
            ids.write_key = memory[ids.write_log_start.address_ + read_to_write_offset[ids.reads_len - 1]]
            ids.write_value = memory[ids.write_log_start.address_ + read_to_write_offset[ids.reads_len - 1] + 1]
        %}

        let read_action = cast(read_log, LogItem*);

        assert read_action.key = write_key;
        assert read_action.value = write_value;

        // once the last read is validated, we are done
        if (reads_len == 1) {
            return ();
        }

        return validate_reads_inner{
            write_log_start=write_log_start,
        }(read_log=read_log - LogItem.SIZE, reads_len=reads_len-1);
    }
}

func main{}() {
    alloc_locals;

    let (read_log, write_log) = HeaderMemorizer.initialize{}();
    tempvar read_log_start = read_log;
    tempvar write_log_start = write_log;

    HeaderMemorizer.write{write_log=write_log}(key=111, value=333);
    HeaderMemorizer.write{write_log=write_log}(key=222, value=334);
    HeaderMemorizer.write{write_log=write_log}(key=333, value=335);

    let (value) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (value) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);

    let (value) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (value) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);

    let (value) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (value) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=333);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=222);
    let (val2) = HeaderMemorizer.read{read_log=read_log}(key=111);

    HeaderMemorizer.validate_reads{write_log=write_log, write_log_start=write_log_start, read_log=read_log, read_log_start=read_log_start}();

    return ();
    
}