module pancake_IFO::IFO_utils {
    use std::vector;
    use std::bcs;
    use std::signer;

    use aptos_std::aptos_hash::keccak256;
    use aptos_framework::coin;

    public fun calculate_tax_overflow(total_amount: u64, raising_amount: u64): u128 {
        let ratio_overflow = total_amount / raising_amount;
        if (ratio_overflow >= 1500) {
            250000000 // 0.025%
        } else if (ratio_overflow >= 1000) {
            500000000 // 0.05%
        } else if (ratio_overflow >= 500) {
            1000000000 // 0.1%
        } else if (ratio_overflow >= 250) {
            1250000000 // 0.125%
        } else if (ratio_overflow >= 100) {
            1500000000 // 0.15%
        } else if (ratio_overflow >= 50) {
            2500000000 // 0.25%
        } else {
            5000000000 // 0.5%
        }
    }

    public fun get_user_allocation(pool_total_amount: u64, user_amount: u64): u128 {
        if (pool_total_amount > 0) {
            // 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
            ((user_amount as u128) * 1000000000000000000)
                / ((pool_total_amount as u128) * 1000000)
        } else {
            0
        }
    }

    public fun compute_vesting_schedule_id(beneficiary: address, index: u64): vector<u8> {
        let bytes = bcs::to_bytes<address>(&beneficiary);
        vector::append(&mut bytes, bcs::to_bytes<u64>(&index));
        keccak256(bytes)
    }

    public fun check_or_register_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };
    }
}