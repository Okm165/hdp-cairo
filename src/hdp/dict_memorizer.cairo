%builtins range_check poseidon

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_single, poseidon_hash, poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountState, SlotState
from starkware.cairo.common.uint256 import Uint256

const MEMORIZER_DEFAULT = 100000000; // An arbitrary large number. We need to ensure each memorizer never contains >= number of elements.

namespace HeaderMemorizer {
    func initialize{}() -> (header_dict: DictAccess*, header_dict_start: DictAccess*){
        let (header_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar header_dict_start = header_dict;

        return (header_dict=header_dict, header_dict_start=header_dict_start);
    }

    func write{
        header_dict: DictAccess*,
        poseidon_ptr: PoseidonBuiltin*,
    }(key: felt, value: felt){
        
        dict_write{dict_ptr=header_dict}(key=key, new_value=value);
        return ();
    }

    func read{
        header_dict: DictAccess*,
        poseidon_ptr: PoseidonBuiltin*,
    }(key: felt) -> (value: felt){
        let (index) = dict_read{dict_ptr=header_dict}(key);

        return (value=index);
    }
}

func main{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*
}() {
    alloc_locals;

    let (header_dict, header_dict_start) = HeaderMemorizer.initialize();

    HeaderMemorizer.write{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111, value=222);

    let (value) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);
    let (val2) = HeaderMemorizer.read{header_dict=header_dict, poseidon_ptr=poseidon_ptr}(key=111);

    // HeaderMemorizer.validate_reads{header_writes=header_writes, writes_start=writes_start, header_reads=header_reads, reads_start=reads_start}();

    default_dict_finalize(header_dict_start, header_dict, MEMORIZER_DEFAULT);


    return ();
    
}
