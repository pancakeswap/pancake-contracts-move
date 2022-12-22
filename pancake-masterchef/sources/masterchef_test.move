#[test_only]
module pancake_masterchef::masterchef_test {
    use std::signer;
    use std::math64::pow;

    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::genesis;
    use aptos_framework::managed_coin;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp::fast_forward_seconds;

    use pancake_masterchef::masterchef;
    use pancake_cake_token::pancake::{Self, Cake};

    //
    // CONSTANTS.
    //

    const DEFAULT_COIN_DECIMALS: u8 = 8;
    const BASE_APTOS: u64 = 100000000;
    const DEFAULT_COIN_MONITOR_SUPPLY: bool = false;
    const DEFAULT_ERROR_CODE: u64 = 100;

    //
    // STRUCTS.
    //

    struct TestCAKE {}
    struct TestBUSD {}
    struct TestUSDC {}
    struct TestBNB {}

    #[test(dev = @masterchef_dev, admin= @admin, upkeep_admin=@upkeep_admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345, user3 = @0x3456, user4 = @0x4567)]
    fun test_all_in_one_upkeep(dev: &signer, admin: &signer, upkeep_admin: &signer, resource_account: &signer, user1: &signer, user2: &signer, user3: &signer, user4: &signer) {
        before_each(dev, admin, resource_account);
        if (!account::exists_at(signer::address_of(upkeep_admin))){
            account::create_account_for_test(signer::address_of(upkeep_admin));
        };
        init_coins<TestCAKE>(resource_account, b"CAKE", b"CAKE");
        init_coins<TestBUSD>(resource_account, b"BUSD", b"BUSD");
        init_coins<TestUSDC>(resource_account, b"USDC", b"USDC");
        init_coins<TestBNB>(resource_account, b"BNB", b"BNB");
        // regular pool user
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        // special pool user
        account::create_account_for_test(signer::address_of(user3));
        account::create_account_for_test(signer::address_of(user4));
        // user1 prepare
        register_and_mint<TestCAKE>(resource_account, user1, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user1, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user1);
        // user2 prepare
        register_and_mint<TestCAKE>(resource_account, user2, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user2, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user2);
        // user3 prepare
        register_and_mint<TestUSDC>(resource_account, user3, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user3, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user3);
        // user4 prepare
        register_and_mint<TestUSDC>(resource_account, user4, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user4, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user4);

        // mint CAKE for upkeep admin
        managed_coin::register<Cake>(upkeep_admin);
        pancake::mint(resource_account, 100000 * BASE_APTOS);
        pancake::transfer(resource_account, signer::address_of(upkeep_admin), 100000 * BASE_APTOS);

        // C admin upkeep elapsed 30s with 120 CAKE
        masterchef::upkeep(upkeep_admin, 120 * BASE_APTOS, 30, true);
        fast_forward_seconds(1);

        // D admin add regular pool, pid = 0, alloc point = 1
        masterchef::add_pool<TestCAKE>(admin, 1, true, true);
        fast_forward_seconds(1);

        // E admin add regular pool, pid = 1, alloc point = 3
        masterchef::add_pool<TestBUSD>(admin, 3, true, true);
        fast_forward_seconds(1);

        // F user1 deposit 1 to pool 0
        masterchef::deposit<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // G user1 deposit 2 to pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // H user2 deposit 2 to pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // I admin add special pool, pid = 2, alloc point = 1
        masterchef::add_pool<TestUSDC>(admin, 1, false, true);
        fast_forward_seconds(1);

        // J user2 deposit 1 to pool 1
        masterchef::deposit<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // K admin set pool 0 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 0, 3, true);
        fast_forward_seconds(1);

        // L admin add special pool, pid = 3, alloc point = 1
        masterchef::add_pool<TestBNB>(admin, 1, false, true);
        fast_forward_seconds(1);

        // M user3 stake 1 in pool 2
        masterchef::deposit<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // N user4 stake 1 in pool 3
        masterchef::deposit<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // O admin set pool 2 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 2, 3, true);
        fast_forward_seconds(1);

        // P user2 stake in pool 1
        masterchef::deposit<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Q user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // R admin set pool 1 alloc point to 0
        masterchef::set_pool(admin, 1, 0, true);
        fast_forward_seconds(1);

        // S user2 withdraw 1 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // T user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // U admin set pool 1 alloc point to 2
        masterchef::set_pool(admin, 1, 2, true);
        fast_forward_seconds(1);

        // V user1 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // W user2 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // X user1 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Y user2 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Z user2 stake 1 in pool 0
        masterchef::deposit<TestCAKE>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AA user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AB user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AC admin update cake rate to 30% 70%
        masterchef::update_cake_rate(admin, 30000, 70000, true);
        fast_forward_seconds(1);

        // AD user2 stake 10 in pool 1
        masterchef::deposit<TestBUSD>(user2, 10 * BASE_APTOS);
        fast_forward_seconds(1);

        // AE admin upkeep elapsed 30s with 90 CAKE
        masterchef::upkeep(upkeep_admin, 90 * BASE_APTOS, 30, true);
        fast_forward_seconds(1);

        // AF no action
        fast_forward_seconds(1);

        // AG no action
        fast_forward_seconds(1);

        // AH no action
        fast_forward_seconds(1);

        // AI user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AJ no action
        fast_forward_seconds(1);

        // AK user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AL mass update pools
        masterchef::mass_update_pools();
        fast_forward_seconds(1);

        // AM user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AN no action
        fast_forward_seconds(1);

        // AO user1 withdraw 4 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 4 * BASE_APTOS);
        fast_forward_seconds(1);

        // AP admin set pool 2 alloc point to 0
        masterchef::set_pool(admin, 2, 0, true);
        fast_forward_seconds(1);

        // AQ user2 withdraw 0 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 0 * BASE_APTOS);
        fast_forward_seconds(1);

        // AR no action
        fast_forward_seconds(1);

        // AS no action
        fast_forward_seconds(1);

        // AT user1 stake 3 in pool 1
        masterchef::deposit<TestBUSD>(user1, 3 * BASE_APTOS);
        fast_forward_seconds(1);

        // AU user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AV user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AW no action
        fast_forward_seconds(1);

        // AX admin set pool 2 alloc point to 2
        masterchef::set_pool(admin, 2, 2, true);
        fast_forward_seconds(1);

        // AY user4 withdraw 1 from pool 3
        masterchef::withdraw<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AZ user3 withdraw 1 from pool 2
        masterchef::withdraw<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // BA no action
        fast_forward_seconds(1);

        // BB no action
        fast_forward_seconds(1);

        let user1_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user1)) +
            masterchef::pending_cake(1, signer::address_of(user1)) +
            coin::balance<Cake>(signer::address_of(user1))
        );
        let user2_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user2)) +
            masterchef::pending_cake(1, signer::address_of(user2)) +
            coin::balance<Cake>(signer::address_of(user2))
        );
        let user3_balance_plus_pending = (
            masterchef::pending_cake(2, signer::address_of(user3)) +
            coin::balance<Cake>(signer::address_of(user3))
        );
        let user4_balance_plus_pending = (
            masterchef::pending_cake(3, signer::address_of(user4)) +
            coin::balance<Cake>(signer::address_of(user4))
        );

        assert!(user1_balance_plus_pending / 100 == 21683685, DEFAULT_ERROR_CODE);
        assert!(user2_balance_plus_pending / 100 == 33566314, DEFAULT_ERROR_CODE);
        assert!(user3_balance_plus_pending / 100 == 52344270, DEFAULT_ERROR_CODE);
        assert!(user4_balance_plus_pending / 100 == 34759895, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, upkeep_admin=@upkeep_admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345, user3 = @0x3456, user4 = @0x4567)]
    fun test_all_in_one_delayed_upkeep(dev: &signer, admin: &signer, upkeep_admin: &signer, resource_account: &signer, user1: &signer, user2: &signer, user3: &signer, user4: &signer) {
        before_each(dev, admin, resource_account);
        if (!account::exists_at(signer::address_of(upkeep_admin))){
            account::create_account_for_test(signer::address_of(upkeep_admin));
        };
        init_coins<TestCAKE>(resource_account, b"CAKE", b"CAKE");
        init_coins<TestBUSD>(resource_account, b"BUSD", b"BUSD");
        init_coins<TestUSDC>(resource_account, b"USDC", b"USDC");
        init_coins<TestBNB>(resource_account, b"BNB", b"BNB");
        // regular pool user
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        // special pool user
        account::create_account_for_test(signer::address_of(user3));
        account::create_account_for_test(signer::address_of(user4));
        // user1 prepare
        register_and_mint<TestCAKE>(resource_account, user1, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user1, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user1);
        // user2 prepare
        register_and_mint<TestCAKE>(resource_account, user2, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user2, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user2);
        // user3 prepare
        register_and_mint<TestUSDC>(resource_account, user3, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user3, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user3);
        // user4 prepare
        register_and_mint<TestUSDC>(resource_account, user4, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user4, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user4);

        // mint CAKE for upkeep admin
        managed_coin::register<Cake>(upkeep_admin);
        pancake::mint(resource_account, 100000 * BASE_APTOS);
        pancake::transfer(resource_account, signer::address_of(upkeep_admin), 100000 * BASE_APTOS);

        // C admin upkeep elapsed 30s with 120 CAKE
        masterchef::upkeep(upkeep_admin, 120 * BASE_APTOS, 30, true);
        fast_forward_seconds(1);

        // D admin add regular pool, pid = 0, alloc point = 1
        masterchef::add_pool<TestCAKE>(admin, 1, true, true);
        fast_forward_seconds(1);

        // E admin add regular pool, pid = 1, alloc point = 3
        masterchef::add_pool<TestBUSD>(admin, 3, true, true);
        fast_forward_seconds(1);

        // F user1 deposit 1 to pool 0
        masterchef::deposit<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // G user1 deposit 2 to pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // H user2 deposit 2 to pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // I admin add special pool, pid = 2, alloc point = 1
        masterchef::add_pool<TestUSDC>(admin, 1, false, true);
        fast_forward_seconds(1);

        // J user2 deposit 1 to pool 1
        masterchef::deposit<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // K admin set pool 0 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 0, 3, true);
        fast_forward_seconds(1);

        // L admin add special pool, pid = 3, alloc point = 1
        masterchef::add_pool<TestBNB>(admin, 1, false, true);
        fast_forward_seconds(1);

        // M user3 stake 1 in pool 2
        masterchef::deposit<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // N user4 stake 1 in pool 3
        masterchef::deposit<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // O admin set pool 2 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 2, 3, true);
        fast_forward_seconds(1);

        // P user2 stake in pool 1
        masterchef::deposit<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Q user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // R admin set pool 1 alloc point to 0
        masterchef::set_pool(admin, 1, 0, true);
        fast_forward_seconds(1);

        // S user2 withdraw 1 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // T user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // U admin set pool 1 alloc point to 2
        masterchef::set_pool(admin, 1, 2, true);
        fast_forward_seconds(1);

        // V user1 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // W user2 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // X user1 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Y user2 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Z user2 stake 1 in pool 0
        masterchef::deposit<TestCAKE>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AA user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AB user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AC admin update cake rate to 30% 70%
        masterchef::update_cake_rate(admin, 30000, 70000, true);
        fast_forward_seconds(1);

        // AD user2 stake 10 in pool 1
        masterchef::deposit<TestBUSD>(user2, 10 * BASE_APTOS);
        fast_forward_seconds(1);

        // AE no action
        fast_forward_seconds(1);

        // AF no action
        fast_forward_seconds(1);

        // AG no action
        fast_forward_seconds(1);

        // AH no action
        fast_forward_seconds(1);

        // AI user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AJ admin upkeep elapsed 30s with 90 CAKE
        masterchef::upkeep(upkeep_admin, 90 * BASE_APTOS, 30, true);
        fast_forward_seconds(1);

        // AK user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AL mass update pools
        masterchef::mass_update_pools();
        fast_forward_seconds(1);

        // AM user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AN no action
        fast_forward_seconds(1);

        // AO user1 withdraw 4 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 4 * BASE_APTOS);
        fast_forward_seconds(1);

        // AP admin set pool 2 alloc point to 0
        masterchef::set_pool(admin, 2, 0, true);
        fast_forward_seconds(1);

        // AQ user2 withdraw 0 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 0 * BASE_APTOS);
        fast_forward_seconds(1);

        // AR no action
        fast_forward_seconds(1);

        // AS no action
        fast_forward_seconds(1);

        // AT user1 stake 3 in pool 1
        masterchef::deposit<TestBUSD>(user1, 3 * BASE_APTOS);
        fast_forward_seconds(1);

        // AU user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AV user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AW no action
        fast_forward_seconds(1);

        // AX admin set pool 2 alloc point to 2
        masterchef::set_pool(admin, 2, 2, true);
        fast_forward_seconds(1);

        // AY user4 withdraw 1 from pool 3
        masterchef::withdraw<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AZ user3 withdraw 1 from pool 2
        masterchef::withdraw<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // BA no action
        fast_forward_seconds(1);

        // BB no action
        fast_forward_seconds(1);

        let user1_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user1)) +
            masterchef::pending_cake(1, signer::address_of(user1)) +
            coin::balance<Cake>(signer::address_of(user1))
        );
        let user2_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user2)) +
            masterchef::pending_cake(1, signer::address_of(user2)) +
            coin::balance<Cake>(signer::address_of(user2))
        );
        let user3_balance_plus_pending = (
            masterchef::pending_cake(2, signer::address_of(user3)) +
            coin::balance<Cake>(signer::address_of(user3))
        );
        let user4_balance_plus_pending = (
            masterchef::pending_cake(3, signer::address_of(user4)) +
            coin::balance<Cake>(signer::address_of(user4))
        );

        assert!(user1_balance_plus_pending / 100 == 20548644, DEFAULT_ERROR_CODE);
        assert!(user2_balance_plus_pending / 100 == 32151355, DEFAULT_ERROR_CODE);
        assert!(user3_balance_plus_pending / 100 == 48250000, DEFAULT_ERROR_CODE);
        assert!(user4_balance_plus_pending / 100 == 33050000, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, upkeep_admin=@upkeep_admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345, user3 = @0x3456, user4 = @0x4567)]
    fun test_all_in_one_never_upkeep(dev: &signer, admin: &signer, upkeep_admin: &signer, resource_account: &signer, user1: &signer, user2: &signer, user3: &signer, user4: &signer) {
       before_each(dev, admin, resource_account);
        if (!account::exists_at(signer::address_of(upkeep_admin))){
            account::create_account_for_test(signer::address_of(upkeep_admin));
        };
        init_coins<TestCAKE>(resource_account, b"CAKE", b"CAKE");
        init_coins<TestBUSD>(resource_account, b"BUSD", b"BUSD");
        init_coins<TestUSDC>(resource_account, b"USDC", b"USDC");
        init_coins<TestBNB>(resource_account, b"BNB", b"BNB");
        // regular pool user
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        // special pool user
        account::create_account_for_test(signer::address_of(user3));
        account::create_account_for_test(signer::address_of(user4));
        // user1 prepare
        register_and_mint<TestCAKE>(resource_account, user1, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user1, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user1);
        // user2 prepare
        register_and_mint<TestCAKE>(resource_account, user2, 1000 * BASE_APTOS);
        register_and_mint<TestBUSD>(resource_account, user2, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user2);
        // user3 prepare
        register_and_mint<TestUSDC>(resource_account, user3, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user3, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user3);
        // user4 prepare
        register_and_mint<TestUSDC>(resource_account, user4, 1000 * BASE_APTOS);
        register_and_mint<TestBNB>(resource_account, user4, 1000 * BASE_APTOS);
        managed_coin::register<Cake>(user4);

        // mint CAKE for upkeep admin
        managed_coin::register<Cake>(upkeep_admin);
        pancake::mint(resource_account, 100000 * BASE_APTOS);
        pancake::transfer(resource_account, signer::address_of(upkeep_admin), 100000 * BASE_APTOS);

        // C admin upkeep elapsed 30s with 120 CAKE
        masterchef::upkeep(upkeep_admin, 120 * BASE_APTOS, 30, true);
        fast_forward_seconds(1);

        // D admin add regular pool, pid = 0, alloc point = 1
        masterchef::add_pool<TestCAKE>(admin, 1, true, true);
        fast_forward_seconds(1);

        // E admin add regular pool, pid = 1, alloc point = 3
        masterchef::add_pool<TestBUSD>(admin, 3, true, true);
        fast_forward_seconds(1);

        // F user1 deposit 1 to pool 0
        masterchef::deposit<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // G user1 deposit 2 to pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // H user2 deposit 2 to pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // I admin add special pool, pid = 2, alloc point = 1
        masterchef::add_pool<TestUSDC>(admin, 1, false, true);
        fast_forward_seconds(1);

        // J user2 deposit 1 to pool 1
        masterchef::deposit<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // K admin set pool 0 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 0, 3, true);
        fast_forward_seconds(1);

        // L admin add special pool, pid = 3, alloc point = 1
        masterchef::add_pool<TestBNB>(admin, 1, false, true);
        fast_forward_seconds(1);

        // M user3 stake 1 in pool 2
        masterchef::deposit<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // N user4 stake 1 in pool 3
        masterchef::deposit<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // O admin set pool 2 alloc point to 3, with_update = true
        masterchef::set_pool(admin, 2, 3, true);
        fast_forward_seconds(1);

        // P user2 stake in pool 1
        masterchef::deposit<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Q user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // R admin set pool 1 alloc point to 0
        masterchef::set_pool(admin, 1, 0, true);
        fast_forward_seconds(1);

        // S user2 withdraw 1 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // T user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // U admin set pool 1 alloc point to 2
        masterchef::set_pool(admin, 1, 2, true);
        fast_forward_seconds(1);

        // V user1 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // W user2 withdraw 2 from pool 0
        masterchef::withdraw<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // X user1 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Y user2 withdraw 2 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // Z user2 stake 1 in pool 0
        masterchef::deposit<TestCAKE>(user2, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AA user1 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AB user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AC admin update cake rate to 30% 70%
        masterchef::update_cake_rate(admin, 30000, 70000, true);
        fast_forward_seconds(1);

        // AD user2 stake 10 in pool 1
        masterchef::deposit<TestBUSD>(user2, 10 * BASE_APTOS);
        fast_forward_seconds(1);

        // AE no action
        fast_forward_seconds(1);
        // fast_forward_seconds(1);

        // AF no action
        fast_forward_seconds(1);

        // AG no action
        fast_forward_seconds(1);

        // AH no action
        fast_forward_seconds(1);

        // AI user1 stake 2 in pool 1
        masterchef::deposit<TestBUSD>(user1, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AJ no action
        fast_forward_seconds(1);

        // AK user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AL mass update pools
        masterchef::mass_update_pools();
        fast_forward_seconds(1);

        // AM user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AN no action
        fast_forward_seconds(1);

        // AO user1 withdraw 4 from pool 1
        masterchef::withdraw<TestBUSD>(user1, 4 * BASE_APTOS);
        fast_forward_seconds(1);

        // AP admin set pool 2 alloc point to 0
        masterchef::set_pool(admin, 2, 0, true);
        fast_forward_seconds(1);

        // AQ user2 withdraw 0 from pool 1
        masterchef::withdraw<TestBUSD>(user2, 0 * BASE_APTOS);
        fast_forward_seconds(1);

        // AR no action
        fast_forward_seconds(1);

        // AS no action
        fast_forward_seconds(1);

        // AT user1 stake 3 in pool 1
        masterchef::deposit<TestBUSD>(user1, 3 * BASE_APTOS);
        fast_forward_seconds(1);

        // AU user1 withdraw 1 from pool 0
        masterchef::withdraw<TestCAKE>(user1, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AV user2 stake 2 in pool 0
        masterchef::deposit<TestCAKE>(user2, 2 * BASE_APTOS);
        fast_forward_seconds(1);

        // AW no action
        fast_forward_seconds(1);

        // AX admin set pool 2 alloc point to 2
        masterchef::set_pool(admin, 2, 2, true);
        fast_forward_seconds(1);

        // AY user4 withdraw 1 from pool 3
        masterchef::withdraw<TestBNB>(user4, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // AZ user3 withdraw 1 from pool 2
        masterchef::withdraw<TestUSDC>(user3, 1 * BASE_APTOS);
        fast_forward_seconds(1);

        // BA no action
        fast_forward_seconds(1);

        // BB no action
        fast_forward_seconds(1);

        let user1_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user1)) +
            masterchef::pending_cake(1, signer::address_of(user1)) +
            coin::balance<Cake>(signer::address_of(user1))
        );
        let user2_balance_plus_pending = (
            masterchef::pending_cake(0, signer::address_of(user2)) +
            masterchef::pending_cake(1, signer::address_of(user2)) +
            coin::balance<Cake>(signer::address_of(user2))
        );
        let user3_balance_plus_pending = (
            masterchef::pending_cake(2, signer::address_of(user3)) +
            coin::balance<Cake>(signer::address_of(user3))
        );
        let user4_balance_plus_pending = (
            masterchef::pending_cake(3, signer::address_of(user4)) +
            coin::balance<Cake>(signer::address_of(user4))
        );

        assert!(user1_balance_plus_pending / 100 == 17306666, DEFAULT_ERROR_CODE);
        assert!(user2_balance_plus_pending / 100 == 18293333, DEFAULT_ERROR_CODE);
        assert!(user3_balance_plus_pending / 100 == 36000000, DEFAULT_ERROR_CODE);
        assert!(user4_balance_plus_pending / 100 == 12400000, DEFAULT_ERROR_CODE);
    }

    // #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345, user3 = @0x3456, user4 = @0x4567)]
    // fun test_all_in_one(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer, user2: &signer, user3: &signer, user4: &signer) {
    //     before_each(dev, admin, resource_account);
    //     init_coins<TestCAKE>(resource_account, b"CAKE", b"CAKE");
    //     init_coins<TestBUSD>(resource_account, b"BUSD", b"BUSD");
    //     init_coins<TestUSDC>(resource_account, b"USDC", b"USDC");
    //     init_coins<TestBNB>(resource_account, b"BNB", b"BNB");
    //     // regular pool user
    //     account::create_account_for_test(signer::address_of(user1));
    //     account::create_account_for_test(signer::address_of(user2));
    //     // special pool user
    //     account::create_account_for_test(signer::address_of(user3));
    //     account::create_account_for_test(signer::address_of(user4));
    //     // user1 prepare
    //     register_and_mint<TestCAKE>(resource_account, user1, 1000 * BASE_APTOS);
    //     register_and_mint<TestBUSD>(resource_account, user1, 1000 * BASE_APTOS);
    //     managed_coin::register<Cake>(user1);
    //     // user2 prepare
    //     register_and_mint<TestCAKE>(resource_account, user2, 1000 * BASE_APTOS);
    //     register_and_mint<TestBUSD>(resource_account, user2, 1000 * BASE_APTOS);
    //     managed_coin::register<Cake>(user2);
    //     // user3 prepare
    //     register_and_mint<TestUSDC>(resource_account, user3, 1000 * BASE_APTOS);
    //     register_and_mint<TestBNB>(resource_account, user3, 1000 * BASE_APTOS);
    //     managed_coin::register<Cake>(user3);
    //     // masterchef::update_whitelist(admin, signer::address_of(user3), true);
    //     // user4 prepare
    //     register_and_mint<TestUSDC>(resource_account, user4, 1000 * BASE_APTOS);
    //     register_and_mint<TestBNB>(resource_account, user4, 1000 * BASE_APTOS);
    //     managed_coin::register<Cake>(user4);
    //     // masterchef::update_whitelist(admin, signer::address_of(user4), true);

    //     // D admin add regular pool, pid = 0, alloc point = 1
    //     masterchef::add_pool<TestCAKE>(admin, 1, true, true);
    //     fast_forward_seconds(1);

    //     // E admin add regular pool, pid = 1, alloc point = 3
    //     masterchef::add_pool<TestBUSD>(admin, 3, true, true);
    //     fast_forward_seconds(1);

    //     // F user1 deposit 1 to pool 0
    //     masterchef::deposit<TestCAKE>(user1, 0, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // G user1 deposit 2 to pool 1
    //     masterchef::deposit<TestBUSD>(user1, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // H user2 deposit 2 to pool 0
    //     masterchef::deposit<TestCAKE>(user2, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // I admin add special pool, pid = 2, alloc point = 1
    //     masterchef::add_pool<TestUSDC>(admin, 1, false, true);
    //     fast_forward_seconds(1);

    //     // J user2 deposit 1 to pool 1
    //     masterchef::deposit<TestBUSD>(user2, 1, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // K admin set pool 0 alloc point to 3, with_update = true
    //     masterchef::set_pool(admin, 0, 3, true);
    //     fast_forward_seconds(1);

    //     // L admin add special pool, pid = 3, alloc point = 1
    //     masterchef::add_pool<TestBNB>(admin, 1, false, true);
    //     fast_forward_seconds(1);

    //     // M user3 stake 1 in pool 2
    //     masterchef::deposit<TestUSDC>(user3, 2, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // N user4 stake 1 in pool 3
    //     masterchef::deposit<TestBNB>(user4, 3, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // O admin set pool 2 alloc point to 3, with_update = true
    //     masterchef::set_pool(admin, 2, 3, true);
    //     fast_forward_seconds(1);

    //     // P user2 stake in pool 1
    //     masterchef::deposit<TestBUSD>(user2, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // Q user1 withdraw 1 from pool 0
    //     masterchef::withdraw<TestCAKE>(user1, 0, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // R admin set pool 1 alloc point to 0
    //     masterchef::set_pool(admin, 1, 0, true);
    //     fast_forward_seconds(1);

    //     // S user2 withdraw 1 from pool 1
    //     masterchef::withdraw<TestBUSD>(user2, 1, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // T user1 stake 2 in pool 0
    //     masterchef::deposit<TestCAKE>(user1, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // U admin set pool 1 alloc point to 2
    //     masterchef::set_pool(admin, 1, 2, true);
    //     fast_forward_seconds(1);

    //     // V user1 withdraw 2 from pool 0
    //     masterchef::withdraw<TestCAKE>(user1, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // W user2 withdraw 2 from pool 0
    //     masterchef::withdraw<TestCAKE>(user2, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // X user1 withdraw 2 from pool 1
    //     masterchef::withdraw<TestBUSD>(user1, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // Y user2 withdraw 2 from pool 1
    //     masterchef::withdraw<TestBUSD>(user2, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // Z user2 stake 1 in pool 0
    //     masterchef::deposit<TestCAKE>(user2, 0, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AA user1 stake 2 in pool 0
    //     masterchef::deposit<TestCAKE>(user1, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AB user1 stake 2 in pool 1
    //     masterchef::deposit<TestBUSD>(user1, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AC admin update cake rate to 30% 70%
    //     masterchef::update_cake_rate(admin, 30000, 70000, true);
    //     fast_forward_seconds(1);

    //     // AD user2 stake 10 in pool 1
    //     masterchef::deposit<TestBUSD>(user2, 1, 10 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AE admin update cake per second to 2
    //     masterchef::update_cake_per_second(admin, 2 * BASE_APTOS, true);
    //     fast_forward_seconds(1);

    //     // AF no action
    //     fast_forward_seconds(1);

    //     // AG no action
    //     fast_forward_seconds(1);

    //     // AH no action
    //     fast_forward_seconds(1);

    //     // AI user1 stake 2 in pool 1
    //     masterchef::deposit<TestBUSD>(user1, 1, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AJ no action
    //     fast_forward_seconds(1);

    //     // AK user1 withdraw 1 from pool 0
    //     masterchef::withdraw<TestCAKE>(user1, 0, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AL mass update pools
    //     masterchef::mass_update_pools();
    //     fast_forward_seconds(1);

    //     // AM user2 stake 2 in pool 0
    //     masterchef::deposit<TestCAKE>(user2, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AN admin update cake per second to 4
    //     masterchef::update_cake_per_second(admin, 4 * BASE_APTOS, true);
    //     fast_forward_seconds(1);

    //     // AO user1 withdraw 4 from pool 1
    //     masterchef::withdraw<TestBUSD>(user1, 1, 4 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AP admin set pool 2 alloc point to 0
    //     masterchef::set_pool(admin, 2, 0, true);
    //     fast_forward_seconds(1);

    //     // AQ user2 withdraw 0 from pool 1
    //     masterchef::withdraw<TestBUSD>(user2, 1, 0 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AR no action
    //     fast_forward_seconds(1);

    //     // AS no action
    //     fast_forward_seconds(1);

    //     // AT user1 stake 3 in pool 1
    //     masterchef::deposit<TestBUSD>(user1, 1, 3 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AU user1 withdraw 1 from pool 0
    //     masterchef::withdraw<TestCAKE>(user1, 0, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AV user2 stake 2 in pool 0
    //     masterchef::deposit<TestCAKE>(user2, 0, 2 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AW no action
    //     fast_forward_seconds(1);

    //     // AX admin set pool 2 alloc point to 2
    //     masterchef::set_pool(admin, 2, 2, true);
    //     fast_forward_seconds(1);

    //     // AY user4 withdraw 1 from pool 3
    //     masterchef::withdraw<TestBNB>(user4, 3, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // AZ user3 withdraw 1 from pool 2
    //     masterchef::withdraw<TestUSDC>(user3, 2, 1 * BASE_APTOS);
    //     fast_forward_seconds(1);

    //     // BA no action
    //     fast_forward_seconds(1);

    //     // BB no action
    //     fast_forward_seconds(1);

    //     let user1_balance_plus_pending = (
    //         masterchef::pending_cake(0, signer::address_of(user1)) +
    //         masterchef::pending_cake(1, signer::address_of(user1)) +
    //         coin::balance<Cake>(signer::address_of(user1))
    //     );
    //     let user2_balance_plus_pending = (
    //         masterchef::pending_cake(0, signer::address_of(user2)) +
    //         masterchef::pending_cake(1, signer::address_of(user2)) +
    //         coin::balance<Cake>(signer::address_of(user2))
    //     );
    //     let user3_balance_plus_pending = (
    //         masterchef::pending_cake(2, signer::address_of(user3)) +
    //         coin::balance<Cake>(signer::address_of(user3))
    //     );
    //     let user4_balance_plus_pending = (
    //         masterchef::pending_cake(3, signer::address_of(user4)) +
    //         coin::balance<Cake>(signer::address_of(user4))
    //     );

    //     assert!(user1_balance_plus_pending / 100 == 20973589, DEFAULT_ERROR_CODE);
    //     assert!(user2_balance_plus_pending / 100 == 35626409, DEFAULT_ERROR_CODE);
    //     assert!(user3_balance_plus_pending / 100 == 49183333, DEFAULT_ERROR_CODE);
    //     assert!(user4_balance_plus_pending / 100 == 38883333, DEFAULT_ERROR_CODE);
    // }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345)]
    fun test_deposit(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer, user2: &signer) {
        before_each(dev, admin, resource_account);
        // pid = 0
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        // pid = 1
        before_add_pool<TestBUSD>(resource_account, admin, b"BUSD", b"BUSD", 1000, true, true);

        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));

        managed_coin::register<Cake>(user1);
        managed_coin::register<Cake>(user2);

        register_and_mint<TestCAKE>(resource_account, user1, 100 * pow(10, 8));
        register_and_mint<TestCAKE>(resource_account, user2, 100 * pow(10, 8));
        register_and_mint<TestBUSD>(resource_account, user1, 100 * pow(10, 8));
        register_and_mint<TestBUSD>(resource_account, user2, 100 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 50);
        // one user deposit multiple times in same pool
        masterchef::deposit<TestCAKE>(user1, 50);
        masterchef::deposit<TestCAKE>(user2, 100);

        masterchef::deposit<TestBUSD>(user1, 100);
        masterchef::deposit<TestBUSD>(user2, 100);

        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 200, DEFAULT_ERROR_CODE);
        let (total_amount, _, _, _, _) = masterchef::get_pool_info(1);
        assert!(total_amount == 200, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(1, signer::address_of(user1));
        assert!(amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(1, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);

        masterchef::deposit<TestCAKE>(user1, 100);

        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 300, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 200, DEFAULT_ERROR_CODE);

        // check user 1 CAKE balance
        assert!(coin::balance<TestCAKE>(signer::address_of(user1)) == 9999999800, DEFAULT_ERROR_CODE);
        // check user 2 CAKE balance
        assert!(coin::balance<TestCAKE>(signer::address_of(user2)) == 9999999900, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 2)]
    fun test_deposit_wrong_lp_token(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        init_coins<TestBUSD>(resource_account, b"BUSD", b"BUSD");

        account::create_account_for_test(signer::address_of(user1));

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));
        register_and_mint<TestBUSD>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::deposit<TestBUSD>(user1, 100);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 7)]
    fun test_deposit_coin_not_registered(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        masterchef::deposit<TestCAKE>(user1, 100);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    fun test_deposit_auto_register_cake(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));

        register_and_mint<TestCAKE>(resource_account, user1, 100 * pow(10, 8));
        // auto-register-cake
        masterchef::deposit<TestCAKE>(user1, 100);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345)]
    fun test_withdraw(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer, user2: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);

        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        managed_coin::register<Cake>(user1);
        managed_coin::register<Cake>(user2);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));
        register_and_mint<TestCAKE>(resource_account, user2, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 200);
        masterchef::deposit<TestCAKE>(user2, 200);

        masterchef::withdraw<TestCAKE>(user1, 50);
        masterchef::withdraw<TestCAKE>(user1, 50);
        masterchef::withdraw<TestCAKE>(user2, 100);

        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 200, DEFAULT_ERROR_CODE);

        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);

        masterchef::withdraw<TestCAKE>(user1, 100);
        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 100, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 0, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);

        // check user 1 CAKE balance
        assert!(coin::balance<TestCAKE>(signer::address_of(user1)) == 100000000000, DEFAULT_ERROR_CODE);
        // check user 2 CAKE balance
        assert!(coin::balance<TestCAKE>(signer::address_of(user2)) == 99999999900 , DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 10)]
    fun test_withdraw_user_not_exist(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::withdraw<TestCAKE>(user1, 100);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 2)]
    fun test_withdraw_wrong_lp_token(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 100);
        masterchef::withdraw<TestBUSD>(user1, 100);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 4)]
    fun test_withdraw_insufficient_amount(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 100);
        masterchef::withdraw<TestCAKE>(user1, 100);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 0, DEFAULT_ERROR_CODE);
        masterchef::withdraw<TestCAKE>(user1, 1);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234, user2 = @0x2345)]
    fun test_emergency_withdraw(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer, user2: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);

        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));
        managed_coin::register<Cake>(user1);
        managed_coin::register<Cake>(user2);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));
        register_and_mint<TestCAKE>(resource_account, user2, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 200);
        masterchef::deposit<TestCAKE>(user2, 200);

        masterchef::emergency_withdraw<TestCAKE>(user1);
        masterchef::withdraw<TestCAKE>(user2, 100);

        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 100, DEFAULT_ERROR_CODE);

        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 0, DEFAULT_ERROR_CODE);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user2));
        assert!(amount == 100, DEFAULT_ERROR_CODE);

        masterchef::emergency_withdraw<TestCAKE>(user2);
        let (total_amount, _, _, _, _) = masterchef::get_pool_info(0);
        assert!(total_amount == 0, DEFAULT_ERROR_CODE);

        assert!(coin::balance<TestCAKE>(signer::address_of(user1)) == 100000000000, DEFAULT_ERROR_CODE);
        assert!(coin::balance<TestCAKE>(signer::address_of(user2)) == 100000000000, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 10)]
    fun test_emergency_withdraw_user_not_exist(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::emergency_withdraw<TestCAKE>(user1);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 2)]
    fun test_emergency_withdraw_wrong_lp_token(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 100);
        masterchef::emergency_withdraw<TestBUSD>(user1);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, user1 = @0x1234)]
    #[expected_failure(abort_code = 4)]
    fun test_emergency_withdraw_insufficient_amount(dev: &signer, admin: &signer, resource_account: &signer, user1: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        account::create_account_for_test(signer::address_of(user1));
        managed_coin::register<Cake>(user1);

        register_and_mint<TestCAKE>(resource_account, user1, 1000 * pow(10, 8));

        masterchef::deposit<TestCAKE>(user1, 100);
        masterchef::withdraw<TestCAKE>(user1, 100);
        let (amount, _) = masterchef::get_user_info(0, signer::address_of(user1));
        assert!(amount == 0, DEFAULT_ERROR_CODE);
        masterchef::emergency_withdraw<TestCAKE>(user1);
    }

    #[test_only]
    fun before_add_pool<CoinType>(resource_account: &signer, admin: &signer,name: vector<u8>, symbol: vector<u8>, alloc_point: u64, is_regular: bool, with_update: bool) {
        init_coins<CoinType>(resource_account, name, symbol);
        masterchef::add_pool<CoinType>(admin, alloc_point, is_regular, with_update);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    fun before_add_multiple_pool(dev: &signer, resource_account: &signer, admin: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, true, true);
        before_add_pool<TestBUSD>(resource_account, admin, b"BUSD", b"BUSD", 1000, true, true);
        before_add_pool<TestUSDC>(resource_account, admin, b"USDC", b"USDC", 1000, true, false);
        before_add_pool<TestBNB>(resource_account, admin, b"BNB", b"BNB", 1000, false, true);

        assert!(masterchef::pool_length() == 4, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 1)]
    fun test_add_pool_not_publish(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        masterchef::add_pool<TestCAKE>(admin, 1000, true, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 0)]
    fun test_add_pool_not_admin(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        // init coins
        managed_coin::initialize<TestCAKE>(
            resource_account,
            b"CAKE",
            b"CAKE",
            DEFAULT_COIN_DECIMALS,
            DEFAULT_COIN_MONITOR_SUPPLY,
        );

        let random = account::create_account_for_test(@0x12345678);
        masterchef::add_pool<TestCAKE>(&random, 1000, true, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 3)]
    fun test_add_pool_exist_token(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        // init coins
        managed_coin::initialize<TestCAKE>(
            resource_account,
            b"CAKE",
            b"CAKE",
            DEFAULT_COIN_DECIMALS,
            DEFAULT_COIN_MONITOR_SUPPLY,
        );

        masterchef::add_pool<TestCAKE>(admin, 1000, true, true);
        masterchef::add_pool<TestCAKE>(admin, 1000, true, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 9)]
    fun test_add_pool_wrong_decimal(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        // init coins
        managed_coin::initialize<TestCAKE>(
            resource_account,
            b"CAKE",
            b"CAKE",
            10,
            DEFAULT_COIN_MONITOR_SUPPLY,
        );

        masterchef::add_pool<TestCAKE>(admin, 1000, true, true);
    }

    // #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    // fun test_update_cake_per_second(dev: &signer, admin: &signer, resource_account: &signer) {
    //     before_each(dev, admin, resource_account);
    //     before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, false, true);

    //     masterchef::update_cake_per_second(admin, 1000000000, true);

    //     let (_, _, _, cake_per_second, _, _) = masterchef::get_metadata_info();
    //     assert!(cake_per_second == 1000000000, DEFAULT_ERROR_CODE);
    // }

    // #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    // #[expected_failure(abort_code = 0)]
    // fun test_update_cake_per_second_not_admin(dev: &signer, admin: &signer, resource_account: &signer) {
    //     before_each(dev, admin, resource_account);
    //     // dev(not admin) updae cake per second
    //     masterchef::update_cake_per_second(dev, 1000000000, true);

    // }

    // #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    // #[expected_failure(abort_code = 6)]
    // fun test_update_cake_per_second_exceed_limit(dev: &signer, admin: &signer, resource_account: &signer) {
    //     before_each(dev, admin, resource_account);
    //     let max_per_second = 1000000000000;
    //     masterchef::update_cake_per_second(admin, max_per_second + 1, true);
    // }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    fun test_update_cake_rate(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, false, true);

        let regular_rate = 60000;
        let special_rate = 40000;
        masterchef::update_cake_rate(admin, regular_rate, special_rate, true);

        let (_, _, _, _, _regular_rate, _special_rate) =  masterchef::get_metadata_info();
        assert!(_regular_rate == regular_rate, DEFAULT_ERROR_CODE);
        assert!(_special_rate == special_rate, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 0)]
    fun test_update_cake_rate_not_admin(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);

        let regular_rate = 60000;
        let special_rate = 40000;
         // dev(not admin) set pool
        masterchef::update_cake_rate(dev, regular_rate, special_rate, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 5)]
    fun test_update_cake_rate_invalid_rate(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);

        let regular_rate = 60000;
        let special_rate = 40001;
        let total_cake_rate = 100000;

        assert!(regular_rate + special_rate != total_cake_rate, DEFAULT_ERROR_CODE);
        masterchef::update_cake_rate(dev, regular_rate, special_rate, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    fun test_set_pool(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, false, true);

        masterchef::set_pool(admin, 0, 1000, true);

        let (_, _, _, alloc_point, _) =  masterchef::get_pool_info(0);
        assert!(alloc_point == 1000, DEFAULT_ERROR_CODE);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 0)]
    fun test_set_pool_not_admin(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        before_add_pool<TestCAKE>(resource_account, admin, b"CAKE", b"CAKE", 1000, false, true);
        // dev(not admin) set pool
        masterchef::set_pool(dev, 0, 1000, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 6)]
    fun test_set_pool_pid_not_exsit(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);

        masterchef::set_pool(admin, 0, 1000, true);
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, new_admin = @0x1234)]
    fun test_set_admin(dev: &signer, admin: &signer, resource_account: &signer, new_admin: &signer) {
        before_each(dev, admin, resource_account);

        let (current_admin, _, _, _, _, _) =  masterchef::get_metadata_info();
        assert!(current_admin == signer::address_of(admin), DEFAULT_ERROR_CODE);

        account::create_account_for_test(signer::address_of(new_admin));

        // set new_admin as admin
        masterchef::set_admin(admin, signer::address_of(new_admin));
        let (current_admin, _, _, _, _, _) =  masterchef::get_metadata_info();
        assert!(current_admin == signer::address_of(new_admin), DEFAULT_ERROR_CODE);
        masterchef::set_admin(new_admin, signer::address_of(admin));
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef, new_admin = @0x1234)]
    #[expected_failure(abort_code = 0)]
    fun test_set_admin_not_admin(dev: &signer, admin: &signer, resource_account: &signer, new_admin: &signer) {
        before_each(dev, admin, resource_account);

        account::create_account_for_test(signer::address_of(new_admin));

        // dev(not admin) new_admin as admin
        masterchef::set_admin(dev, signer::address_of(new_admin));
    }

    #[test(dev = @masterchef_dev, admin= @admin, resource_account = @pancake_masterchef)]
    #[expected_failure(abort_code = 11)]
    fun test_set_admin_with_zero_account(dev: &signer, admin: &signer, resource_account: &signer) {
        before_each(dev, admin, resource_account);
        masterchef::set_admin(dev, @0x0);
    }

    #[test_only]
    public fun before_each(dev: &signer, admin: &signer, masterchef: &signer) {
        genesis::setup();
        account::create_account_for_test(signer::address_of(dev));
        if (!account::exists_at(signer::address_of(admin))){
             account::create_account_for_test(signer::address_of(admin));
        };
        resource_account::create_resource_account(dev, b"pancake-swap-masterchef", x"");
        masterchef::initialize(masterchef);
        // CAKE token initialize
        pancake::initialize(dev);
        pancake::transfer_ownership(dev, signer::address_of(masterchef));
    }

    #[test_only]
    public fun register_and_mint<CoinType>(account: &signer, to: &signer, amount: u64) {
      managed_coin::register<CoinType>(to);
      managed_coin::mint<CoinType>(account, signer::address_of(to), amount)
    }

    #[test_only]
    public fun init_coins<CoinType>(account: &signer, name: vector<u8>, symbol: vector<u8>) {
        managed_coin::initialize<CoinType>(
            account,
            name,
            symbol,
            DEFAULT_COIN_DECIMALS,
            DEFAULT_COIN_MONITOR_SUPPLY
        );
    }
}
