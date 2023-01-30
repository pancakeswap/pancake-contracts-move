#[test_only]
module pancake::smart_chef_test {

    use aptos_framework::genesis;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_std::math64::pow;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use std::signer;
    use pancake_phantom_types::uints::{U0, U2};
    use pancake::smart_chef::{initialize, create_pool, add_reward, update_reward_per_second, deposit, get_pool_info, withdraw, emergency_reward_withdraw, stop_reward, emergency_withdraw, get_user_stake_amount, update_pool_limit_per_user, update_start_and_end_timestamp, set_admin, get_pending_reward};
    use test_coin::test_coins::{Self, TestCAKE, TestBUSD, Test30DEC, TestUSDC};

    fun setup_test(dev: &signer, admin: &signer, treasury: &signer, resource_account: &signer) {
        genesis::setup();
        account::create_account_for_test(signer::address_of(dev));
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(treasury));
        resource_account::create_resource_account(dev, b"pancake_smart_chef", x"");
        initialize(resource_account);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_pool_all_in_one(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestBUSD>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestBUSD>(&coin_owner, bob, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let pool_limit_per_user = 0;
        let time_for_user_limit = 0;
        let reward_per_second = 10;
        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 53;
        let total_reward = 530;
        let total_stake_token = 0;
        let total_reward_token = 0;
        let alice_earn_token = 0;
        let bob_earn_token = 0;

        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);

        // add 10 percent reward first
        add_reward<TestCAKE, TestBUSD, U0>(admin, (total_reward * 10 / 100));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_reward_token = total_reward_token + (total_reward * 10 / 100);
        assert!(expected_total_reward_token == total_reward_token, 99);

        // 3 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 3);
        add_reward<TestCAKE, TestBUSD, U0>(admin, (total_reward * 90 / 100));
        total_reward_token = total_reward_token + (total_reward * 90 / 100);

        let (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_total_reward_token == total_reward_token, 98);
        assert!(expected_total_stake_token == total_stake_token, 97);

        // 4 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 4);
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, 1);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 1;

        assert!(alice_cake_before_balance - alice_cake_after_balance == 1, 96);
        assert!(expected_total_stake_token == total_stake_token, 95);
        assert!(expected_total_reward_token == total_reward_token, 94);

        // 6 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 6);
        let bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        deposit<TestCAKE, TestBUSD, U0>(bob, 2);
        let bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 2;

        assert!(bob_cake_before_balance - bob_cake_after_balance == 2, 93);
        assert!(expected_total_stake_token == total_stake_token, 92);
        assert!(expected_total_reward_token == total_reward_token, 91);

        // 15 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 15);
        let alice_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, 1);
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 1;
        total_reward_token = total_reward_token - 50;
        alice_earn_token = alice_earn_token + 50;

        assert!(alice_pending_reward == 50, 90);
        assert!(alice_cake_after_balance - alice_cake_before_balance == 1, 89);
        assert!(alice_busd_after_balance - alice_busd_before_balance == 50, 88);
        assert!(expected_total_stake_token == total_stake_token, 87);
        assert!(expected_total_reward_token == total_reward_token, 86);

        // 18 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 18);
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, 2);
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 2;

        assert!(alice_pending_reward == 0, 85);
        assert!(alice_cake_before_balance - alice_cake_after_balance == 2, 84);
        assert!(expected_total_stake_token == total_stake_token, 83);
        assert!(expected_total_reward_token == total_reward_token, 82);

        // 20 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 20);
        alice_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, 2);
        alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 2;
        total_reward_token = total_reward_token - 10;
        alice_earn_token = alice_earn_token + 10;

        assert!(alice_pending_reward == 10, 93);
        assert!(alice_cake_after_balance - alice_cake_before_balance == 2, 81);
        assert!(alice_busd_after_balance - alice_busd_before_balance == 10, 80);
        assert!(expected_total_stake_token == total_stake_token, 79);
        assert!(expected_total_reward_token == total_reward_token, 78);

        // 21 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 21);
        let bob_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        let bob_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(bob));
        withdraw<TestCAKE, TestBUSD, U0>(bob, 2);
        let bob_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 2;
        total_reward_token = total_reward_token - 110;
        bob_earn_token = bob_earn_token + 110;

        assert!(bob_pending_reward == 110, 93);
        assert!(bob_cake_after_balance - bob_cake_before_balance == 2, 77);
        assert!(bob_busd_after_balance - bob_busd_before_balance == 110, 76);
        assert!(expected_total_stake_token == total_stake_token, 75);
        assert!(expected_total_reward_token == total_reward_token, 74);

        // 24 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 24);
        bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        deposit<TestCAKE, TestBUSD, U0>(bob, 1);
        bob_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(bob));
        bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 1;

        assert!(bob_pending_reward == 0, 73);
        assert!(bob_cake_before_balance - bob_cake_after_balance == 1, 72);
        assert!(expected_total_stake_token == total_stake_token, 71);
        assert!(expected_total_reward_token == total_reward_token, 70);

        // 25 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 25);
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, 2);
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 2;

        assert!(alice_pending_reward == 0, 69);
        assert!(alice_cake_before_balance - alice_cake_after_balance == 2, 68);
        assert!(expected_total_stake_token == total_stake_token, 67);
        assert!(expected_total_reward_token == total_reward_token, 66);

        // 28 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 28);
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        alice_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, 0);
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_reward_token = total_reward_token - 20;
        alice_earn_token = alice_earn_token + 20;

        assert!(alice_pending_reward == 20, 65);
        assert!(alice_cake_before_balance - alice_cake_after_balance == 0, 64);
        assert!(alice_busd_after_balance - alice_busd_before_balance == 20, 63);
        assert!(expected_total_stake_token == total_stake_token, 62);
        assert!(expected_total_reward_token == total_reward_token, 61);

        // 35 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 35);
        alice_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, 1);
        alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 1;
        total_reward_token = total_reward_token - 46;
        alice_earn_token = alice_earn_token + 46;

        assert!(alice_pending_reward == 46, 60);
        assert!(get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice)) == 1, 59);
        assert!(alice_cake_after_balance - alice_cake_before_balance == 1, 58);
        assert!(alice_busd_after_balance - alice_busd_before_balance == 46, 57);
        assert!(expected_total_stake_token == total_stake_token, 56);
        assert!(expected_total_reward_token == total_reward_token, 55);

        // 37 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 37);
        bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        bob_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(bob));
        deposit<TestCAKE, TestBUSD, U0>(bob, 2);
        bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        bob_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 2;
        total_reward_token = total_reward_token - 53;
        bob_earn_token = bob_earn_token + 53;

        assert!(bob_pending_reward == 53, 54);
        assert!(get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(bob)) == 3, 53);
        assert!(bob_cake_before_balance - bob_cake_after_balance == 2, 52);
        assert!(bob_busd_after_balance - bob_busd_before_balance == 53, 51);
        assert!(expected_total_stake_token == total_stake_token, 50);
        assert!(expected_total_reward_token == total_reward_token, 49);

        // 45 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 45);
        alice_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        alice_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, 1);
        alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 1;
        total_reward_token = total_reward_token - 30;
        alice_earn_token = alice_earn_token + 30;

        assert!(alice_pending_reward == 30, 60);
        assert!(get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice)) == 0, 48);
        assert!(alice_cake_after_balance - alice_cake_before_balance == 1, 47);
        assert!(alice_busd_after_balance - alice_busd_before_balance == 30, 46);
        assert!(expected_total_stake_token == total_stake_token, 45);
        assert!(expected_total_reward_token == total_reward_token, 44);

        // 46 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 46);
        bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        bob_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(bob));
        deposit<TestCAKE, TestBUSD, U0>(bob, 2);
        bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        bob_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token + 2;
        total_reward_token = total_reward_token - 70;
        bob_earn_token = bob_earn_token + 70;

        assert!(bob_pending_reward == 70, 54);
        assert!(get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(bob)) == 5, 43);
        assert!(bob_cake_before_balance - bob_cake_after_balance == 2, 42);
        assert!(bob_busd_after_balance - bob_busd_before_balance == 70, 41);
        assert!(expected_total_stake_token == total_stake_token, 40);
        assert!(expected_total_reward_token == total_reward_token, 39);

        // 53 seconds after start time
        timestamp::update_global_time_for_test_secs(start_time + 53);
        bob_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        bob_pending_reward = get_pending_reward<TestCAKE, TestBUSD, U0>(signer::address_of(bob));
        withdraw<TestCAKE, TestBUSD, U0>(bob, 5);
        bob_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        bob_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(bob));
        (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        total_stake_token = total_stake_token - 5;
        total_reward_token = total_reward_token - 70;
        bob_earn_token = bob_earn_token + 70;

        assert!(bob_pending_reward == 70, 38);
        assert!(bob_cake_after_balance - bob_cake_before_balance == 5, 37);
        assert!(bob_busd_after_balance - bob_busd_before_balance == 70, 36);
        assert!(expected_total_stake_token == total_stake_token, 35);
        assert!(expected_total_stake_token == 0, 34);
        assert!(expected_total_reward_token == total_reward_token, 33);
        // have left over
        assert!(expected_total_reward_token > 0, 30);

        assert!(alice_earn_token == 156, 31);
        assert!(bob_earn_token == 303, 310);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_pool_rapid_deposit_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 20000000000 * pow(10, 8));
        test_coins::register_and_mint<TestBUSD>(&coin_owner, alice, 20000000000 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 20000000000 * pow(10, 8));
        test_coins::register_and_mint<TestBUSD>(&coin_owner, bob, 20000000000 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 20000000000 * pow(10, 8));

        let pool_limit_per_user = 0;
        let time_for_user_limit = 0;
        let reward_per_second = 1000000000;
        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 53;
        let total_reward = reward_per_second * (end_time - start_time);

        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);

        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);

        deposit<TestCAKE, TestBUSD, U0>(bob, 100000000000000000);
        deposit<TestCAKE, TestBUSD, U0>(alice, 20);
        timestamp::update_global_time_for_test_secs(start_time + 1);

        deposit<TestCAKE, TestBUSD, U0>(alice, 0);
        timestamp::update_global_time_for_test_secs(start_time + 2);
        deposit<TestCAKE, TestBUSD, U0>(alice, 0);
        timestamp::update_global_time_for_test_secs(start_time + 3);
        deposit<TestCAKE, TestBUSD, U0>(alice, 0);
        timestamp::update_global_time_for_test_secs(start_time + 4);
        deposit<TestCAKE, TestBUSD, U0>(alice, 0);
        timestamp::update_global_time_for_test_secs(start_time + 5);

        let bob_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(bob));
        deposit<TestCAKE, TestBUSD, U0>(bob, 0);
        let bob_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(bob));

        assert!((bob_busd_after_balance - bob_busd_before_balance) == 4999500000, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_create_pool(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let pool_limit_per_user = 0;
        let time_for_user_limit = 0;
        let reward_per_second = 1;
        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let (expected_total_stake_token, expected_total_reward_token, expected_reward_per_second, expected_start_timestamp, expected_end_timestamp, expected_time_for_user_limit, expected_pool_limit_per_user) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_stake_token == 0, 99);
        assert!(expected_total_reward_token == 0, 98);
        assert!(expected_reward_per_second == reward_per_second, 97);
        assert!(expected_start_timestamp == start_time, 96);
        assert!(expected_end_timestamp == end_time, 95);
        assert!(expected_time_for_user_limit == time_for_user_limit, 92);
        assert!(expected_pool_limit_per_user == pool_limit_per_user, 91);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_create_pool_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(dev, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 2)]
    fun test_create_pool_stake_token_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<U0, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 2)]
    fun test_create_pool_reward_token_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, U0, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 1)]
    fun test_create_pool_already_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 0);
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 18)]
    fun test_create_pool_stake_and_reward_same_token(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestCAKE, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 3)]
    fun test_create_pool_pass_start_time(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        timestamp::update_global_time_for_test_secs((start_time + 10));
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 13)]
    fun test_create_pool_pass_end_time_earlier_than_start_time(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = timestamp::now_seconds() + 5;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 0);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_create_pool_with_limits(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let pool_limit_per_user = 100;
        let time_for_user_limit = 1000;
        let reward_per_second = 1;
        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let (expected_total_stake_token, expected_total_reward_token, expected_reward_per_second, expected_start_timestamp, expected_end_timestamp, expected_time_for_user_limit, expected_pool_limit_per_user) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_stake_token == 0, 99);
        assert!(expected_total_reward_token == 0, 98);
        assert!(expected_reward_per_second == reward_per_second, 97);
        assert!(expected_start_timestamp == start_time, 96);
        assert!(expected_end_timestamp == end_time, 95);
        assert!(expected_time_for_user_limit == time_for_user_limit, 92);
        assert!(expected_pool_limit_per_user == pool_limit_per_user, 91);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 5)]
    fun test_create_pool_zero_pool_limits(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 0, 1000);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 17)]
    fun test_create_pool_wrong_uid(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 100, 1000);
        create_pool<TestCAKE, TestBUSD, U2>(admin, 1, start_time, end_time, 100, 1000);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 4)]
    fun test_create_pool_unreasonable_token_decimal(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let _ = test_coins::init_coins();

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, Test30DEC, U0>(admin, 1, start_time, end_time, 10, 1000);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_add_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));


        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        add_reward<TestCAKE, TestBUSD, U0>(admin, reward);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_reward_token == reward, 99);
        assert!(admin_busd_before_balance - admin_busd_after_balance == reward, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_add_reward_multiple_times(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));


        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward = 50;
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        add_reward<TestCAKE, TestBUSD, U0>(admin, reward);
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_reward_token == reward, 99);
        add_reward<TestCAKE, TestBUSD, U0>(admin, reward);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_reward_token == reward * 2, 98);
        assert!(admin_busd_before_balance - admin_busd_after_balance == reward * 2, 97);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_add_reward_after_reward_change(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let first_reward = 50;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        add_reward<TestCAKE, TestBUSD, U0>(admin, first_reward);
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_reward_token == first_reward, 99);
        let second_reward = 52;
        update_reward_per_second<TestCAKE, TestBUSD, U0>(admin, 10);
        add_reward<TestCAKE, TestBUSD, U0>(admin, second_reward);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        assert!(expected_total_reward_token == first_reward + second_reward, 98);
        assert!(admin_busd_before_balance - admin_busd_after_balance == first_reward + second_reward, 97);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_add_reward_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestBUSD>(&coin_owner, dev, 200 * pow(10, 8));


        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        add_reward<TestCAKE, TestBUSD, U0>(dev, 100);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 65542)]
    fun test_add_reward_not_enough_balance(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 90 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 10 * pow(10, 8), start_time, end_time, 10, 1000);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100 * pow(10, 8));
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_add_reward_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 90 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        add_reward<TestCAKE, TestUSDC, U0>(admin, 100);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_deposit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));


        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 1000);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == stake_amount, 99);
        assert!(alice_cake_before_balance - alice_cake_after_balance == stake_amount, 98);
        assert!(expected_total_stake_token == stake_amount, 97)
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_deposit_after_time_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let first_stake_amount = pool_limit_per_user;
        let second_stake_amount = 1000;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, first_stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        deposit<TestCAKE, TestBUSD, U0>(alice, second_stake_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        let (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward_total = time_for_user_limit * reward_per_second;
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == first_stake_amount + second_stake_amount, 99);
        assert!(alice_cake_before_balance - alice_cake_after_balance == first_stake_amount + second_stake_amount, 98);
        assert!(expected_total_stake_token == first_stake_amount + second_stake_amount, 97);
        assert!(alice_busd_after_balance == total_earn_reward_total, 96);
        assert!(total_reward - expected_total_reward_token == total_earn_reward_total, 95);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_deposit_after_update_pool_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let first_stake_amount = pool_limit_per_user;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, first_stake_amount);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, true, new_pool_limit_per_user);
        let second_stake_amount = new_pool_limit_per_user - pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit - 1);
        deposit<TestCAKE, TestBUSD, U0>(alice, second_stake_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        let (expected_total_stake_token, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward_total = (time_for_user_limit - 1) * reward_per_second;
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == first_stake_amount + second_stake_amount, 99);
        assert!(alice_cake_before_balance - alice_cake_after_balance == first_stake_amount + second_stake_amount, 98);
        assert!(expected_total_stake_token == first_stake_amount + second_stake_amount, 97);
        assert!(alice_busd_after_balance == total_earn_reward_total, 96);
        assert!(total_reward - expected_total_reward_token == total_earn_reward_total, 95);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 65542)]
    fun test_deposit_not_enough_balance(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 10);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100);

        timestamp::update_global_time_for_test_secs(start_time + 10);
        let stake_amount = 1000 * pow(10, 8);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_deposit_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 10);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 100;
        deposit<TestCAKE, TestBUSD, U2>(alice, stake_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_deposit_no_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 10);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        assert!((alice_cake_before_balance - alice_cake_after_balance) == stake_amount, 99);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 14)]
    fun test_deposit_pass_end_time(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 10);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);

        timestamp::update_global_time_for_test_secs(end_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_deposit_after_emergency_reward_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, 1, start_time, end_time, 10, 10);
        add_reward<TestCAKE, TestBUSD, U0>(admin, 100);

        timestamp::update_global_time_for_test_secs(start_time);
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        let stake_amount = 10;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));

        assert!((alice_cake_before_balance - alice_cake_after_balance) == stake_amount, 99);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 14)]
    fun test_deposit_after_stop_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        stop_reward<TestCAKE, TestBUSD, U0>(admin);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let withdraw_amount = stake_amount;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == 0, 99);
        assert!(alice_cake_after_balance - alice_cake_before_balance == stake_amount, 99);
        assert!(expected_total_stake_token == stake_amount - withdraw_amount, 96);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_withdraw_partial_after_time_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let withdraw_amount = stake_amount / 2;
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward = time_for_user_limit * reward_per_second;
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == stake_amount - withdraw_amount, 99);
        assert!(alice_cake_after_balance - alice_cake_before_balance == withdraw_amount, 98);
        assert!(alice_busd_after_balance == total_earn_reward, 97);
        assert!(expected_total_stake_token == stake_amount - withdraw_amount, 96);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_withdraw_after_pool_end(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(end_time + time_for_user_limit);
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let withdraw_amount = stake_amount;
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward = (end_time - start_time) * reward_per_second;
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == 0, 99);
        assert!(alice_cake_after_balance - alice_cake_before_balance == withdraw_amount, 98);
        assert!(alice_busd_after_balance == total_earn_reward, 97);
        assert!(expected_total_stake_token == stake_amount - withdraw_amount, 96);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 65542)]
    fun test_withdraw_after_emergency_reward_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let withdraw_amount = stake_amount;
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_withdraw_after_stop_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let withdraw_amount = stake_amount;
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        stop_reward<TestCAKE, TestBUSD, U0>(admin);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit + 10);
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let alice_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward = time_for_user_limit * reward_per_second;
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(user_stake_amount == 0, 99);
        assert!(alice_cake_after_balance - alice_cake_before_balance == withdraw_amount, 98);
        assert!(alice_busd_after_balance == total_earn_reward, 97);
        assert!(expected_total_stake_token == stake_amount - withdraw_amount, 96);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_withdraw_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let withdraw_amount = stake_amount;
        withdraw<TestCAKE, TestBUSD, U2>(alice, withdraw_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 9)]
    fun test_withdraw_no_stake(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let withdraw_amount = stake_amount;
        withdraw<TestCAKE, TestBUSD, U0>(bob, withdraw_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 6)]
    fun test_withdraw_not_enough_balance(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        let stake_amount = pool_limit_per_user;
        timestamp::update_global_time_for_test_secs(start_time);
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        let withdraw_amount = stake_amount + 1;
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_emergency_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let alice_cake_before_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        emergency_withdraw<TestCAKE, TestBUSD, U0>(alice);
        let alice_cake_after_balance = coin::balance<TestCAKE>(signer::address_of(alice));
        let (expected_total_stake_token, _, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let user_stake_amount = get_user_stake_amount<TestCAKE, TestBUSD, U0>(signer::address_of(alice));

        assert!(alice_cake_after_balance - alice_cake_before_balance == stake_amount, 99);
        assert!(user_stake_amount == 0, 98);
        assert!(expected_total_stake_token == 0, 97);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_emergency_withdraw_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_withdraw<TestCAKE, TestBUSD, U2>(alice);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 9)]
    fun test_emergency_withdraw_no_stake(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_withdraw<TestCAKE, TestBUSD, U0>(bob);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 6)]
    fun test_emergency_withdraw_again(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_withdraw<TestCAKE, TestBUSD, U0>(alice);
        emergency_withdraw<TestCAKE, TestBUSD, U0>(alice);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_emergency_reward_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(admin_busd_after_balance - admin_busd_before_balance == total_reward, 99);
        assert!(expected_total_reward_token == 0, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_emergency_reward_withdraw_after_user_withdraw(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        let withdraw_amount = stake_amount;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward = time_for_user_limit * reward_per_second;

        assert!(admin_busd_after_balance - admin_busd_before_balance == total_reward - total_earn_reward, 99);
        assert!(expected_total_reward_token == 0, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_emergency_reward_withdraw_after_stop_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        let withdraw_amount = stake_amount;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        stop_reward<TestCAKE, TestBUSD, U0>(admin);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit + 20);
        withdraw<TestCAKE, TestBUSD, U0>(alice, withdraw_amount);
        let admin_busd_before_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        let admin_busd_after_balance = coin::balance<TestBUSD>(signer::address_of(admin));
        let (_, expected_total_reward_token, _, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();
        let total_earn_reward = time_for_user_limit * reward_per_second;

        assert!(admin_busd_after_balance - admin_busd_before_balance == total_reward - total_earn_reward, 99);
        assert!(expected_total_reward_token == 0, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_emergency_reward_withdraw_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(alice);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_emergency_reward_withdraw_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_reward_withdraw<TestCAKE, TestBUSD, U2>(admin);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 6)]
    fun test_emergency_reward_withdraw_again(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
        emergency_reward_withdraw<TestCAKE, TestBUSD, U0>(admin);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_stop_reward(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        stop_reward<TestCAKE, TestBUSD, U0>(admin);
        let (_, _, _, _, expected_end_timestamp, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_end_timestamp == start_time + time_for_user_limit, 99);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_stop_reward_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        stop_reward<TestCAKE, TestBUSD, U0>(alice);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_stop_reward_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        let total_reward = 100;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        add_reward<TestCAKE, TestBUSD, U0>(admin, total_reward);

        timestamp::update_global_time_for_test_secs(start_time);
        let stake_amount = 10;
        deposit<TestCAKE, TestBUSD, U0>(alice, stake_amount);
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        stop_reward<TestCAKE, TestBUSD, U2>(admin);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_update_pool_limit_per_user(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, true, new_pool_limit_per_user);

        let (_, _, _, _, _, expected_time_for_user_limit, expected_pool_limit_per_user) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_pool_limit_per_user == new_pool_limit_per_user, 99);
        assert!(expected_time_for_user_limit == time_for_user_limit, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_update_pool_limit_false_time_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, false, new_pool_limit_per_user);

        let (_, _, _, _, _, expected_time_for_user_limit, expected_pool_limit_per_user) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_pool_limit_per_user == 0, 99);
        assert!(expected_time_for_user_limit == 0, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_update_pool_limit_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(alice, false, new_pool_limit_per_user);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_update_pool_limit_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U2>(admin, false, new_pool_limit_per_user);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 11)]
    fun test_update_pool_limit_lower_than_old_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user - 1;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, true, new_pool_limit_per_user);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 10)]
    fun test_update_pool_limit_false_time_limit_twice(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, false, new_pool_limit_per_user);
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, false, new_pool_limit_per_user);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 10)]
    fun test_update_pool_limit_pass_time_limit(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_pool_limit_per_user = pool_limit_per_user + 10;
        timestamp::update_global_time_for_test_secs(start_time + time_for_user_limit);
        update_pool_limit_per_user<TestCAKE, TestBUSD, U0>(admin, false, new_pool_limit_per_user);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_update_reward_per_second(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_reward_per_second = 2;
        update_reward_per_second<TestCAKE, TestBUSD, U0>(admin, new_reward_per_second);

        let (_, _, expected_reward_per_second, _, _, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_reward_per_second == new_reward_per_second, 99);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_update_reward_per_second_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_reward_per_second = 2;
        update_reward_per_second<TestCAKE, TestBUSD, U0>(alice, new_reward_per_second);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_update_reward_per_second_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_reward_per_second = 2;
        update_reward_per_second<TestCAKE, TestBUSD, U2>(admin, new_reward_per_second);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 12)]
    fun test_update_reward_per_second_pool_started(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_reward_per_second = 2;
        timestamp::update_global_time_for_test_secs(start_time);
        update_reward_per_second<TestCAKE, TestBUSD, U0>(admin, new_reward_per_second);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_update_start_and_end_timestamp(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_start_time = start_time + 10;
        let new_end_time = end_time + 10;
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U0>(admin, new_start_time, new_end_time);

        let (_, _, _, expected_start_time, expected_end_time, _, _) = get_pool_info<TestCAKE, TestBUSD, U0>();

        assert!(expected_start_time == new_start_time, 99);
        assert!(expected_end_time == new_end_time, 98);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_update_start_and_end_timestamp_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_start_time = start_time + 10;
        let new_end_time = end_time + 10;
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U0>(alice, new_start_time, new_end_time);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 7)]
    fun test_update_start_and_end_timestamp_pool_not_exist(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_start_time = start_time + 10;
        let new_end_time = end_time + 10;
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U2>(admin, new_start_time, new_end_time);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 12)]
    fun test_update_start_and_end_timestamp_pass_start_time(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_start_time = start_time + 10;
        let new_end_time = end_time + 10;
        timestamp::update_global_time_for_test_secs(start_time);
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U0>(admin, new_start_time, new_end_time);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 13)]
    fun test_update_start_and_end_timestamp_end_time_earlier_than_start_time(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        let new_start_time = start_time + 10;
        let new_end_time = new_start_time;
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U0>(admin, new_start_time, new_end_time);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 3)]
    fun test_update_start_and_end_timestamp_start_time_pass(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        let start_time = timestamp::now_seconds() + 10;
        let end_time = start_time + 100;
        let reward_per_second = 1;
        let time_for_user_limit = 20;
        let pool_limit_per_user = 10;
        create_pool<TestCAKE, TestBUSD, U0>(admin, reward_per_second, start_time, end_time, pool_limit_per_user, time_for_user_limit);
        timestamp::update_global_time_for_test_secs(start_time - 1);
        let new_start_time = start_time - 2;
        let new_end_time = new_start_time + 10;
        update_start_and_end_timestamp<TestCAKE, TestBUSD, U0>(admin, new_start_time, new_end_time);
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_set_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        set_admin(admin, signer::address_of(alice));
    }

    #[test(dev = @pancake_smart_chef_dev, admin = @pancake_smart_chef_default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    #[expected_failure(abort_code = 0)]
    fun test_set_admin_not_admin(
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer,
    ) {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));

        setup_test(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();
        test_coins::register_and_mint<TestBUSD>(&coin_owner, admin, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, alice, 200 * pow(10, 8));
        test_coins::register_and_mint<TestCAKE>(&coin_owner, bob, 200 * pow(10, 8));

        set_admin(bob, signer::address_of(alice));
    }
}