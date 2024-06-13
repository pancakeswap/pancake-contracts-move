#[test_only]
module pancake_periphery::periphery_test {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::resource_account;
    use pancake::swap::{Self, LPToken};
    use aptos_std::math64::pow;
    use pancake::swap_utils;
    use pancake_periphery::periphery;
    use pancake_masterchef::masterchef;
    use pancake_oft::oft::{CakeOFT};
    use aptos_framework::aptos_coin::{AptosCoin as APT};

    const MINIMUM_LIQUIDITY: u128 = 1000;
    const PANCAKE_SWAP: address = @pancake;
    const PANCAKE_SWAP_DEV: address = @dev;
    const PANCAKE_MASTERCHEG_DEV: address = @masterchef_origin;
    const PANCAKE_MASTERCHEG: address = @pancake_masterchef;
    const PANCAKE_MASTERCHEG_ADMIN: address = @msterchef_admin;
    const OFT: address = @pancake_oft;
    const APTOS_CORE: address = @0x1;
    const BOB: address = @0xb0b;
    const ALICE: address = @0xa11ce;

    public fun setup_test(dev: &signer, resource_account: &signer) {
        genesis::setup();

        account::create_account_for_test(signer::address_of(dev));
        account::create_account_for_test(signer::address_of(resource_account));
        // initialize coins
        let cake_oft_signer = account::create_account_for_test(OFT);
        init_coins<CakeOFT>(&cake_oft_signer, b"CAKEOFT", b"CAKEOFT");
        let aptos_core_signer = account::create_account_for_test(APTOS_CORE);
        init_coins<APT>(&aptos_core_signer, b"APT", b"APT");

        // mint test coins
        account::create_account_for_test(BOB);
        account::create_account_for_test(ALICE);
        register_and_mint<CakeOFT>(&cake_oft_signer, BOB, 10000 * pow(10, 8));
        register_and_mint<CakeOFT>(&cake_oft_signer, ALICE, 10000 * pow(10, 8));
        register_and_mint<APT>(&aptos_core_signer, BOB, 10000 * pow(10, 8));
        register_and_mint<APT>(&aptos_core_signer, ALICE, 10000 * pow(10, 8));

        // initialize swap
        let pancake_swap_dev_signer = account::create_account_for_test(PANCAKE_SWAP_DEV);
        resource_account::create_resource_account(&pancake_swap_dev_signer, b"pancake", x"");
        let pancake_swap_signer = account::create_account_for_test(PANCAKE_SWAP);
        pancake::swap::initialize(&pancake_swap_signer);
        // create LP coin
        pancake::router::create_pair<CakeOFT, APT>(&pancake_swap_signer);

        // initialize masterchef
        let pancake_masterchef_dev_signer = account::create_account_for_test(PANCAKE_MASTERCHEG_DEV);
        resource_account::create_resource_account(&pancake_masterchef_dev_signer, b"pancake-masterchef", x"");
        let pancake_masterchef_signer = account::create_account_for_test(PANCAKE_MASTERCHEG);
        masterchef::initialize(&pancake_masterchef_signer);
        // add pool in masterchef
        let pancake_masterchef_admin_signer = account::create_account_for_test(PANCAKE_MASTERCHEG_ADMIN);
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef::add_pool<LPToken<CakeOFT, APT>>(&pancake_masterchef_admin_signer, 100, true, true);
        }else{
            masterchef::add_pool<LPToken<APT, CakeOFT>>(&pancake_masterchef_admin_signer, 100, true, true);
        };
        // initialize periphery
        resource_account::create_resource_account(dev, b"pancake-periphery", x"");
        periphery::initialize_for_test(resource_account);

    }

    #[test(dev = @periphery_origin, resource_account = @pancake_periphery)]
    fun test_add_liquidity_and_stake(
        dev: &signer,
        resource_account: &signer,
    ) {
        setup_test(dev, resource_account);

        let bob = &account::create_account_for_test(BOB);
        let alice = &account::create_account_for_test(ALICE);

        let bob_liquidity_APT = 5 * pow(10, 8);
        let bob_liquidity_Cake = 10 * pow(10, 8);
        let alice_liquidity_APT = 2 * pow(10, 8);
        let alice_liquidity_Cake = 4 * pow(10, 8);

        periphery::add_liquidity_and_stake<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);
        let masterchef_LP_balance;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
        };
        assert!(masterchef_LP_balance > 0, 0);

        periphery::add_liquidity_and_stake<APT, CakeOFT>(alice, alice_liquidity_APT, alice_liquidity_Cake, 0, 0);

        let masterchef_LP_balance_after;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance_after = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
        }else{
            masterchef_LP_balance_after = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
        };
        
        assert!(masterchef_LP_balance_after > masterchef_LP_balance, 0);
    }

    #[test(dev = @periphery_origin, resource_account = @pancake_periphery)]
    fun test_add_liquidity_and_stake_all(
        dev: &signer,
        resource_account: &signer,
    ) {
        setup_test(dev, resource_account);

        let bob = &account::create_account_for_test(BOB);
        let alice = &account::create_account_for_test(ALICE);

        let bob_liquidity_APT = 5 * pow(10, 8);
        let bob_liquidity_Cake = 10 * pow(10, 8);
        let alice_liquidity_APT = 2 * pow(10, 8);
        let alice_liquidity_Cake = 4 * pow(10, 8);

        pancake::router::add_liquidity<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);

        let bob_lp_balance_before;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            bob_lp_balance_before = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            bob_lp_balance_before = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(bob_lp_balance_before > 0, 0);

        periphery::add_liquidity_and_stake_all<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);
        let masterchef_LP_balance;
        let bob_lp_balance_after;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(masterchef_LP_balance > bob_lp_balance_before, 0);
        assert!(bob_lp_balance_after == 0, 0);

        // alice add liquidity and stake all
        pancake::router::add_liquidity<APT, CakeOFT>(alice, alice_liquidity_APT, alice_liquidity_Cake, 0, 0);
        let alice_lp_balance_before;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            alice_lp_balance_before = coin::balance<swap::LPToken<CakeOFT, APT>>(ALICE);
        }else{
            alice_lp_balance_before = coin::balance<swap::LPToken<APT, CakeOFT>>(ALICE);
        };
        assert!(alice_lp_balance_before > 0, 0);

        periphery::add_liquidity_and_stake_all<CakeOFT, APT>(alice, alice_liquidity_Cake, alice_liquidity_APT, 0, 0);
        let alice_lp_balance_after;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            alice_lp_balance_after = coin::balance<swap::LPToken<CakeOFT, APT>>(ALICE);
        }else{
            alice_lp_balance_after = coin::balance<swap::LPToken<APT, CakeOFT>>(ALICE);
        };
        assert!(alice_lp_balance_after == 0, 0);
    }


    #[test(dev = @periphery_origin, resource_account = @pancake_periphery)]
    fun test_unstake_and_remove_liquidity(
        dev: &signer,
        resource_account: &signer,
    ) {
        setup_test(dev, resource_account);

        let bob = &account::create_account_for_test(BOB);

        let bob_liquidity_APT = 5 * pow(10, 8);
        let bob_liquidity_Cake = 10 * pow(10, 8);

        pancake::router::add_liquidity<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);

        let bob_lp_balance_before;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            bob_lp_balance_before = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            bob_lp_balance_before = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(bob_lp_balance_before > 0, 0);

        periphery::add_liquidity_and_stake_all<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);
        let masterchef_LP_balance;
        let bob_lp_balance_after;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(masterchef_LP_balance > bob_lp_balance_before, 0);
        assert!(bob_lp_balance_after == 0, 0);

        let bob_APT_balance_before = coin::balance<CakeOFT>(BOB);
        let bob_Cake_balance_before = coin::balance<APT>(BOB);

        // bob unstake and remove liquidity
        periphery::unstake_and_remove_liquidity<CakeOFT, APT>(bob, masterchef_LP_balance, 0, 0);

        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
        };
        assert!(masterchef_LP_balance == 0, 0);

        let bob_APT_balance_after = coin::balance<CakeOFT>(BOB);
        let bob_Cake_balance_after = coin::balance<APT>(BOB);
        assert!(bob_APT_balance_after > bob_APT_balance_before, 0);
        assert!(bob_Cake_balance_after > bob_Cake_balance_before, 0);
    }


    #[test(dev = @periphery_origin, resource_account = @pancake_periphery)]
    fun test_unstake_and_remove_all_liquidity(
        dev: &signer,
        resource_account: &signer,
    ) {
        setup_test(dev, resource_account);

        let bob = &account::create_account_for_test(BOB);

        let bob_liquidity_APT = 5 * pow(10, 8);
        let bob_liquidity_Cake = 10 * pow(10, 8);

        pancake::router::add_liquidity<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);

        let bob_lp_balance_before;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            bob_lp_balance_before = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            bob_lp_balance_before = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(bob_lp_balance_before > 0, 0);

        periphery::add_liquidity_and_stake<CakeOFT, APT>(bob, bob_liquidity_APT, bob_liquidity_Cake, 0, 0);
        let masterchef_LP_balance;
        let bob_lp_balance_after;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_after = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(masterchef_LP_balance > 0, 0);
        assert!(bob_lp_balance_after == bob_lp_balance_before, 0);

        let bob_APT_balance_before = coin::balance<CakeOFT>(BOB);
        let bob_Cake_balance_before = coin::balance<APT>(BOB);

        // bob unstake and remove liquidity
        periphery::unstake_and_remove_all_liquidity<CakeOFT, APT>(bob, masterchef_LP_balance, 0, 0);

        let bob_lp_balance_now;
        if(swap_utils::sort_token_type<CakeOFT, APT>()){
            masterchef_LP_balance = coin::balance<swap::LPToken<CakeOFT, APT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_now = coin::balance<swap::LPToken<CakeOFT, APT>>(BOB);
        }else{
            masterchef_LP_balance = coin::balance<swap::LPToken<APT, CakeOFT>>(PANCAKE_MASTERCHEG);
            bob_lp_balance_now = coin::balance<swap::LPToken<APT, CakeOFT>>(BOB);
        };
        assert!(masterchef_LP_balance == 0, 0);
        assert!(bob_lp_balance_now == 0, 0);

        let bob_APT_balance_after = coin::balance<CakeOFT>(BOB);
        let bob_Cake_balance_after = coin::balance<APT>(BOB);
        assert!(bob_APT_balance_after > bob_APT_balance_before, 0);
        assert!(bob_Cake_balance_after > bob_Cake_balance_before, 0);
    }

    public fun init_coins<CoinType>(account: &signer, name: vector<u8>, symbol: vector<u8>) {
        managed_coin::initialize<CoinType>(
            account,
            name,
            symbol,
            8,
            true,
        );
    }

    public fun register_and_mint<CoinType>(account: &signer, to: address, amount: u64) {
        let to_signer = account::create_account_for_test(to); 
        managed_coin::register<CoinType>(&to_signer);
        managed_coin::mint<CoinType>(account, to, amount)
    }
}