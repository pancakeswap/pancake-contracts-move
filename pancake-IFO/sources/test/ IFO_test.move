#[test_only]
module pancake_IFO::IFO_test {
    use std::signer;
    use std::bcs;
    
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_std::aptos_hash::keccak256;

    use pancake_IFO::IFO_utils;
    use pancake_IFO::IFO;
    use pancake_phantom_types::uints;

    #[test(
        ifo_dev=@IFO_dev,
        admin=@IFO_default_admin,
        resource_account=@pancake_IFO,
        user=@0x5678
    )]
    public fun test_IFO(ifo_dev: &signer, admin: &signer, resource_account: &signer, user: &signer) {
        use aptos_framework::genesis;

        genesis::setup();

        account::create_account_for_test(signer::address_of(ifo_dev));
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user));

        // init IFO
        let rainsing_amount: u64 = 100000000;
        let offering_amount: u64 = 100000000;
        init_and_set_pool(ifo_dev, admin, resource_account, rainsing_amount, offering_amount, true);
        managed_coin::register<CoinA>(user);
        managed_coin::mint<CoinA>(resource_account, signer::address_of(user), 10000000000);

        // deposit
        timestamp::fast_forward_seconds(3601);
        let deposit_amount: u64 = 2 * rainsing_amount;
        IFO::deposit<CoinA, CoinB, uints::U0>(user, deposit_amount);

        let (amount, _) = IFO::get_user_info_of_pool<CoinA, CoinB, uints::U0>(signer::address_of(user));
        assert!(amount == deposit_amount, 0);
        let (oa, ra, _) = IFO::get_user_offering_refund_and_tax_amount<CoinA, CoinB, uints::U0>(signer::address_of(user));
        assert!(oa == offering_amount, 1);
        assert!(ra == (deposit_amount-offering_amount)*995/1000, 2); // refund has 0.5% tax

        // harvest
        timestamp::fast_forward_seconds(7*3600);
        managed_coin::register<CoinB>(user);
        assert!(coin::balance<CoinB>(signer::address_of(user)) == 0, 3);
        IFO::harvest_pool<CoinA, CoinB, uints::U0>(user);
        assert!(
            coin::balance<CoinB>(signer::address_of(user)) == offering_amount/2,
            3
        ); // vesting percentage 50%

        // check vesting schedule
        let vesting_id = IFO_utils::compute_vesting_schedule_id(signer::address_of(user), 0);
        let (beneficiary, pid, amount_pool, amount_release) = IFO::get_vesting_schedule_by_id<CoinA, CoinB>(vesting_id);
        assert!(beneficiary == signer::address_of(user), 4);
        assert!(pid == 0, 4);
        assert!(amount_pool == offering_amount/2, 4);
        assert!(amount_release == 0, 4);

        // check release
        timestamp::fast_forward_seconds(2*3600);
        IFO::release<CoinA, CoinB, uints::U0>(user, vesting_id);
        assert!(
            coin::balance<CoinB>(signer::address_of(user)) == offering_amount*9/14,
            5
        );
    }

    #[test_only]
    use aptos_framework::managed_coin;

    #[test_only]
    struct CoinA has key {}
    #[test_only]
    struct CoinB has key {}
    #[test_only]
    fun init_and_set_pool(
        ifo_dev: &signer,
        admin: &signer,
        resource_account: &signer,
        raising_amount: u64,
        offering_amount: u64,
        has_tax: bool
    ) {
        resource_account::create_resource_account(ifo_dev, b"pancakeIFO", x"");
        IFO::initialize(resource_account);
        deploy_test_coin(resource_account);
        managed_coin::register<CoinB>(admin);
        managed_coin::mint<CoinB>(resource_account, signer::address_of(admin), 10000000000);

        let start_time = timestamp::now_seconds() + 3600;
        let end_time = timestamp::now_seconds() + 8*3600;
        IFO::initialize_pool<CoinA, CoinB>(admin, start_time, end_time);

        let limit_per_user: u64 = 0;
        let vesting_percentage: u64 = 50;
        let vesting_cliff: u64 = 3600;
        let vesting_duration: u64 = 7*3600;
        let vesting_slice_per_seconds: u64 = 3600;
        IFO::set_pool<CoinA, CoinB, uints::U0>(
            admin,
            raising_amount,
            offering_amount,
            limit_per_user,
            has_tax,
            vesting_percentage,
            vesting_cliff,
            vesting_duration,
            vesting_slice_per_seconds
        );
        IFO::deposit_offering_coin<CoinA, CoinB, uints::U0>(admin, offering_amount);

        // assert!(IFO::is_pool_set<CoinA, CoinB, uints::U0>(), ERROR_POOL_NOT_SET);
        // let metadata = borrow_global<IFOMetadata<CoinA, CoinB>>(RESOURCE_ACCOUNT);
        // assert!(coin::value(&metadata.offering_coin_store) == offering_amount, ERROR_POOL_NOT_SET);
    }

    #[test_only]
    fun deploy_test_coin(admin: &signer) {
        managed_coin::initialize<CoinA>(
            admin,
            b"Coin A",
            b"A",
            8,
            false
        );

        managed_coin::initialize<CoinB>(
            admin,
            b"Coin B",
            b"B",
            8,
            false
        );
    }

    #[test]
    public fun test_keccak256() {
        use aptos_std::debug;

        let test_addr = @0xd3eec05e74ab99a4529bc0930056f2adeecbdef195b61b05248008a8c5762984;
        let bytes_addr = bcs::to_bytes<address>(&test_addr);
        debug::print(&bytes_addr);
        debug::print(&keccak256(bytes_addr));

        let bytes_index = bcs::to_bytes<u64>(&0);
        debug::print(&bytes_index);
    }
}