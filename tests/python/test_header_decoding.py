from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async
from tools.py.block_header import BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun
from starkware.cairo.common.poseidon_hash import poseidon_hash_many, poseidon_hash
from tools.py.utils import bytes_to_8_bytes_chunks, bytes_to_8_bytes_chunks_little, split_128, reverse_endian_256, reverse_endian_bytes, reverse_and_split_256_bytes
from dotenv import load_dotenv
import os


GOERLI = "goerli"
MAINNET = "mainnet"

NETWORK = GOERLI
load_dotenv()
RPC_URL = (
    os.getenv("RPC_URL_GOERLI") if NETWORK == GOERLI else os.getenv("RPC_URL_MAINNET")
)
RPC_URL = "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"

def fetch_header(block_number):
    blocks = fetch_blocks_from_rpc_no_async(block_number + 1, block_number - 1, RPC_URL)
    block = blocks[1]
    assert block.number == block_number, f"Block number mismatch {block.number} != {block_number}"
    return block

def fetch_header_dict(block_number):
    block = fetch_header(block_number)

    print(block)
    block_dict = {
        "rlp": bytes_to_8_bytes_chunks_little(block.raw_rlp()),
    }
   
    # LE
    (low, high) = reverse_and_split_256_bytes(block.parentHash)
    block_dict["parent_hash"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(block.unclesHash)
    block_dict["uncles_hash"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(block.stateRoot)
    block_dict["state_root"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(block.transactionsRoot)
    block_dict["tx_root"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(block.receiptsRoot)
    block_dict["receipts_root"] = {"low": low, "high": high}

    coinbase = bytes_to_8_bytes_chunks_little(block.coinbase)
    block_dict["coinbase"] = coinbase

    block_dict["difficulty"] = block.difficulty
    block_dict["number"] = block.number
    block_dict["gas_limit"] = block.gasLimit
    block_dict["gas_used"] = block.gasUsed
    block_dict["timestamp"] = block.timestamp
    block_dict["nonce"] = int.from_bytes(block.nonce, "big")

    if type(block) is BlockHeader:
        block_dict["type"] = 0
    elif type(block) is BlockHeaderEIP1559:
        block_dict["type"] = 1
    elif type(block) is BlockHeaderShangai:
        block_dict["type"] = 2
    elif type(block) is BlockHeaderDencun:
        block_dict["type"] = 3

    if block_dict["type"] >= 1:
        block_dict["base_fee_per_gas"] = block.baseFeePerGas
    
    if block_dict["type"] >= 2:
        (low, high) = reverse_and_split_256_bytes(block.withdrawalsRoot)
        block_dict["withdrawls_root"] = {"low": low, "high": high}

    if block_dict["type"] >= 3:
        block_dict["blob_gas_used"] = block.blobGasUsed
        block_dict["excess_blob_gas"] = block.excessBlobGas
        (low, high) = reverse_and_split_256_bytes(block.parentBeaconBlockRoot)
        block_dict["parent_beacon_block_root"] = {"low": low, "high": high}

    return block_dict