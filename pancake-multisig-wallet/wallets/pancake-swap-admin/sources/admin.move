module pancake_swap_admin::admin {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::coin;

    use pancake_multisig_wallet::multisig_wallet;
    use pancake::swap;

    const MULTISIG_WALLET_ADDRESS: address = @pancake_swap_admin;

    const GRACE_PERIOD: u64 = 14 * 24 * 60 * 60; // in seconds

    struct Capabilities has key {
        signer_cap: account::SignerCapability,
    }

    // Swap specific vars

    const ERROR_NOT_ADMIN: u64 = 0;
    const ERROR_NOT_FEE_TO: u64 = 1;
    const ERROR_WITHDRAW_SWAP_FEE_PAIR_NOT_EXIST: u64 = 2;

    struct SetSwapAdminParams has copy, store {
        admin: address,
    }

    struct SetSwapFeeToParams has copy, store {
        fee_to: address,
    }

    struct WithdrawSwapFeeParams<phantom LPToken0CoinType, phantom LPToken1CoinType> has copy, store {
    }

    struct UpgradeSwapParams has copy, store {
        metadata: vector<u8>,
        code: vector<vector<u8>>,
    }

    fun init_module(sender: &signer) {
        let owners = vector[@pancake_swap_admin_owner1, @pancake_swap_admin_owner2, @pancake_swap_admin_owner3];
        let threshold = 2;
        multisig_wallet::initialize(sender, owners, threshold);

        multisig_wallet::register_multisig_txs<SetSwapAdminParams>(sender);
        multisig_wallet::register_multisig_txs<SetSwapFeeToParams>(sender);
        multisig_wallet::register_multisig_txs<UpgradeSwapParams>(sender);

        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @pancake_swap_admin_dev);
        move_to(sender, Capabilities {
            signer_cap,
        });
    }

    public entry fun register_multisig_txs<ParamsType: copy + store>() acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::register_multisig_txs<ParamsType>(&signer);
    }

    public entry fun register_coin<CoinType>() acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        coin::register<CoinType>(&signer);
    }

    public entry fun init_add_owner(sender: &signer, eta: u64, owner: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_add_owner(sender, &signer, eta, expiration, owner);
    }

    public entry fun init_remove_owner(sender: &signer, eta: u64, owner: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_remove_owner(sender, &signer, eta, expiration, owner);
    }

    public entry fun init_set_threshold(sender: &signer, eta: u64, threshold: u8) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_set_threshold(sender, &signer, eta, expiration, threshold);
    }

    public entry fun init_withdraw<CoinType>(sender: &signer, eta: u64, to: address, amount: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_withdraw<CoinType>(sender, &signer, eta, expiration, to, amount);
    }

    public entry fun approve_add_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_add_owner(sender, &signer, seq_number);
    }

    public entry fun approve_remove_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_remove_owner(sender, &signer, seq_number);
    }

    public entry fun approve_set_threshold(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_set_threshold(sender, &signer, seq_number);
    }

    public entry fun approve_withdraw<CoinType>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_withdraw<CoinType>(sender, &signer, seq_number);
    }

    public entry fun execute_add_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::execute_add_owner(sender, &signer, seq_number);
    }

    public entry fun execute_remove_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::execute_remove_owner(sender, &signer, seq_number);
    }

    public entry fun execute_set_threshold(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::execute_set_threshold(sender, &signer, seq_number);
    }

    public entry fun execute_withdraw<CoinType>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::execute_withdraw<CoinType>(sender, &signer, seq_number);
    }

    // TODO: 5. Define your own init, approve and execute functions for customized multisig transactions
    public entry fun init_set_swap_admin(sender: &signer, eta: u64, admin: address) acquires Capabilities {
        assert!(swap::admin() == MULTISIG_WALLET_ADDRESS, ERROR_NOT_ADMIN);
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetSwapAdminParams>(sender, &signer, eta, expiration, SetSwapAdminParams {
            admin,
        });
    }

    public entry fun init_set_swap_fee_to(sender: &signer, eta: u64, fee_to: address) acquires Capabilities {
        assert!(swap::admin() == MULTISIG_WALLET_ADDRESS, ERROR_NOT_ADMIN);
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetSwapFeeToParams>(sender, &signer, eta, expiration, SetSwapFeeToParams {
            fee_to,
        });
    }

    public entry fun init_withdraw_swap_fee<LPToken0CoinType, LPToken1CoinType>(sender: &signer, eta: u64) acquires Capabilities {
        assert!(swap::fee_to() == MULTISIG_WALLET_ADDRESS, ERROR_NOT_FEE_TO);
        assert!(swap::is_pair_created<LPToken0CoinType, LPToken1CoinType>(), ERROR_WITHDRAW_SWAP_FEE_PAIR_NOT_EXIST);
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType>>(sender, &signer, eta, expiration, WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType> {
        });
    }

    public entry fun init_upgrade_swap(sender: &signer, eta: u64, metadata: vector<u8>, code: vector<vector<u8>>) acquires Capabilities {
        assert!(swap::admin() == MULTISIG_WALLET_ADDRESS, ERROR_NOT_ADMIN);
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpgradeSwapParams>(sender, &signer, eta, expiration, UpgradeSwapParams {
            metadata,
            code,
        });
    }

    public entry fun approve_set_swap_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetSwapAdminParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_swap_fee_to(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetSwapFeeToParams>(sender, &signer, seq_number);
    }

    public entry fun approve_withdraw_swap_fee<LPToken0CoinType, LPToken1CoinType>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType>>(sender, &signer, seq_number);
    }

    public entry fun approve_upgrade_swap(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpgradeSwapParams>(sender, &signer, seq_number);
    }

    public entry fun execute_set_swap_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetSwapAdminParams>(sender, &signer, seq_number);

        let SetSwapAdminParams { admin } = multisig_wallet::multisig_tx_params<SetSwapAdminParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        swap::set_admin(&signer, admin);
    }

    public entry fun execute_set_swap_fee_to(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetSwapFeeToParams>(sender, &signer, seq_number);

        let SetSwapFeeToParams { fee_to } = multisig_wallet::multisig_tx_params<SetSwapFeeToParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        swap::set_fee_to(&signer, fee_to);
    }

    public entry fun execute_withdraw_swap_fee<LPToken0CoinType, LPToken1CoinType, LPToken>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType>>(sender, &signer, seq_number);

        let WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType> {} = multisig_wallet::multisig_tx_params<WithdrawSwapFeeParams<LPToken0CoinType, LPToken1CoinType>>(MULTISIG_WALLET_ADDRESS, seq_number);
        swap::withdraw_fee<LPToken0CoinType, LPToken1CoinType>(&signer);
        let sender_addr = signer::address_of(sender);
        //Transfer LP token to owner account
        swap::check_or_register_coin_store<LPToken>(sender);
        let fee_amount = coin::balance<LPToken>(MULTISIG_WALLET_ADDRESS);
        coin::transfer<LPToken>(&signer, sender_addr, fee_amount);
    }

    public entry fun execute_upgrade_swap(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpgradeSwapParams>(sender, &signer, seq_number);

        let UpgradeSwapParams { metadata, code } = multisig_wallet::multisig_tx_params<UpgradeSwapParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        swap::upgrade_swap(&signer, metadata, code);
    }

    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_framework::managed_coin;

    #[test_only]
    use pancake::router;
    #[test_only]
    use pancake::swap::{LPToken};

    #[test_only]
    const MINUTE_IN_SECONDS: u64 = 60;
    #[test_only]
    const HOUR_IN_SECONDS: u64 = 60 * 60;
    #[test_only]
    const DAY_IN_SECONDS: u64 = 24 * 60 * 60;

    // Please use swap_utils::sort_token_type<X, Y>(): bool to sort the token types.
    // because swap_utils::sort_token_type<TestCAKE, TestBUSD>() is true , so we directlt use LPToken<TestCAKE, TestBUSD>
    // if swap_utils::sort_token_type<X, Y>() is false, we should use LPToken<Y, X>
    #[test_only]
    struct TestCAKE {
    }
    #[test_only]
    struct TestBUSD {
    }

    #[test(
        sender = @pancake_swap_admin_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        pancake_swap_admin_dev = @pancake_swap_admin_dev,
        pancake_swap_admin = @pancake_swap_admin,
        pancake_swap_dev = @dev,
        pancake_swap = @pancake
    )]
    fun init_set_swap_admin_successfully(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        pancake_swap_admin_dev: signer,
        pancake_swap_admin: signer,
        pancake_swap_dev: signer,
        pancake_swap: signer,
    )
    acquires Capabilities {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &pancake_swap_admin_dev,
            &pancake_swap_admin,
            &pancake_swap_dev,
            &pancake_swap
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let new_admin_addr = @0x12345;

        let seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        init_set_swap_admin(&sender, eta, new_admin_addr);

        assert!(multisig_wallet::is_multisig_tx_approved_by<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number, signer::address_of(&sender)), 0);
        assert!(multisig_wallet::num_multisig_tx_approvals<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number) == 1, 0);
        assert!(!multisig_wallet::is_multisig_tx_executed<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number), 0);
    }

    #[test(
        sender = @pancake_swap_admin_owner2,
        initiator = @pancake_swap_admin_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        pancake_swap_admin_dev = @pancake_swap_admin_dev,
        pancake_swap_admin = @pancake_swap_admin,
        pancake_swap_dev = @dev,
        pancake_swap = @pancake
    )]
    fun approve_set_swap_admin_successfully(
        sender: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        pancake_swap_admin_dev: signer,
        pancake_swap_admin: signer,
        pancake_swap_dev: signer,
        pancake_swap: signer,
    )
    acquires Capabilities {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &pancake_swap_admin_dev,
            &pancake_swap_admin,
            &pancake_swap_dev,
            &pancake_swap
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let new_admin_addr = @0x12345;

        let seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        init_set_swap_admin(&initiator, eta, new_admin_addr);
        approve_set_swap_admin(&sender, seq_number);

        assert!(multisig_wallet::is_multisig_tx_approved_by<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number, signer::address_of(&sender)), 0);
        assert!(multisig_wallet::num_multisig_tx_approvals<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number) == 2, 0);
        assert!(!multisig_wallet::is_multisig_tx_executed<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number), 0);
    }

    #[test(
        sender = @pancake_swap_admin_owner3,
        approver = @pancake_swap_admin_owner2,
        initiator = @pancake_swap_admin_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        pancake_swap_admin_dev = @pancake_swap_admin_dev,
        pancake_swap_admin = @pancake_swap_admin,
        pancake_swap_dev = @dev,
        pancake_swap = @pancake
    )]
    fun execute_set_swap_admin_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        pancake_swap_admin_dev: signer,
        pancake_swap_admin: signer,
        pancake_swap_dev: signer,
        pancake_swap: signer,
    )
    acquires Capabilities {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &pancake_swap_admin_dev,
            &pancake_swap_admin,
            &pancake_swap_dev,
            &pancake_swap
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let new_admin_addr = @0x12345;

        let seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        init_set_swap_admin(&initiator, eta, new_admin_addr);
        approve_set_swap_admin(&approver, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_set_swap_admin(&sender, seq_number);

        assert!(multisig_wallet::is_multisig_tx_executed<SetSwapAdminParams>(signer::address_of(&pancake_swap_admin), seq_number), 0);
        assert!(swap::admin() == new_admin_addr, 0);
    }

    #[test(
        sender = @pancake_swap_admin_owner3,
        approver = @pancake_swap_admin_owner2,
        initiator = @pancake_swap_admin_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        pancake_swap_admin_dev = @pancake_swap_admin_dev,
        pancake_swap_admin = @pancake_swap_admin,
        pancake_swap_dev = @dev,
        pancake_swap = @pancake
    )]
    fun execute_set_swap_fee_to_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        pancake_swap_admin_dev: signer,
        pancake_swap_admin: signer,
        pancake_swap_dev: signer,
        pancake_swap: signer,
    )
    acquires Capabilities {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &pancake_swap_admin_dev,
            &pancake_swap_admin,
            &pancake_swap_dev,
            &pancake_swap
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let new_fee_to_addr = signer::address_of(&pancake_swap_admin);

        let seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        init_set_swap_fee_to(&initiator, eta, new_fee_to_addr);
        approve_set_swap_fee_to(&approver, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_set_swap_fee_to(&sender, seq_number);

        assert!(multisig_wallet::is_multisig_tx_executed<SetSwapFeeToParams>(signer::address_of(&pancake_swap_admin), seq_number), 0);
        assert!(swap::fee_to() == new_fee_to_addr, 0);
    }

    #[test(
        sender = @pancake_swap_admin_owner3,
        executor = @pancake_swap_admin_owner3,
        approver = @pancake_swap_admin_owner2,
        initiator = @pancake_swap_admin_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        pancake_swap_admin_dev = @pancake_swap_admin_dev,
        pancake_swap_admin = @pancake_swap_admin,
        pancake_swap_dev = @dev,
        pancake_swap = @pancake
    )]
    fun execute_withdraw_swap_fee_successfully(
        sender: signer,
        executor: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        pancake_swap_admin_dev: signer,
        pancake_swap_admin: signer,
        pancake_swap_dev: signer,
        pancake_swap: signer,
    )
    acquires Capabilities {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &pancake_swap_admin_dev,
            &pancake_swap_admin,
            &pancake_swap_dev,
            &pancake_swap,
        );
        before_withdraw_swap_fee(
            &sender,
            &executor,
            &approver,
            &initiator,
            &pancake_swap_admin,
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;

        let withdraw_swap_fee_seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        multisig_wallet::register_multisig_txs<WithdrawSwapFeeParams<TestBUSD, TestCAKE>>(&pancake_swap_admin);
        init_withdraw_swap_fee<TestBUSD, TestCAKE>(&initiator, eta);
        approve_withdraw_swap_fee<TestBUSD, TestCAKE>(&approver, withdraw_swap_fee_seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_withdraw_swap_fee<TestBUSD, TestCAKE, LPToken<TestBUSD, TestCAKE>>(&sender, withdraw_swap_fee_seq_number);

        assert!(multisig_wallet::is_multisig_tx_executed<WithdrawSwapFeeParams<TestBUSD, TestCAKE>>(signer::address_of(&pancake_swap_admin), withdraw_swap_fee_seq_number), 0);
        let sender_lp_balance = swap::lp_balance<TestBUSD, TestCAKE>(signer::address_of(&sender));
        assert!(sender_lp_balance == 999002960, 0);

        account::create_account_for_test(signer::address_of(&initiator));
         // transfer lp to admin
        swap::check_or_register_coin_store<LPToken<TestBUSD, TestCAKE>>(&pancake_swap_admin);
        coin::transfer<LPToken<TestBUSD, TestCAKE>>(&sender, signer::address_of(&pancake_swap_admin), 100000000);

        let admin_lp_balance = swap::lp_balance<TestBUSD, TestCAKE>(signer::address_of(&pancake_swap_admin));
        assert!(admin_lp_balance == 100000000, 0);

        let withdraw_seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        multisig_wallet::register_multisig_txs<multisig_wallet::WithdrawParams<LPToken<TestBUSD, TestCAKE>>>(&pancake_swap_admin);
        init_withdraw<LPToken<TestBUSD, TestCAKE>>(&initiator, eta, signer::address_of(&initiator), 1 * 100000000);
        approve_withdraw<LPToken<TestBUSD, TestCAKE>>(&approver, withdraw_seq_number);
        coin::register<LPToken<TestBUSD, TestCAKE>>(&initiator);
        execute_withdraw<LPToken<TestBUSD, TestCAKE>>(&sender, withdraw_seq_number);
        let initiator_lp_balance = coin::balance<LPToken<TestBUSD, TestCAKE>>(signer::address_of(&initiator));
        assert!(initiator_lp_balance == 1 * 100000000, 0);
    }

    #[test_only]
    fun before_each_test(
        sender: &signer,
        pancake_multisig_wallet_dev: &signer,
        pancake_multisig_wallet: &signer,
        pancake_swap_admin_dev: &signer,
        pancake_swap_admin: &signer,
        pancake_swap_dev: &signer,
        pancake_swap: &signer
    ) {
        genesis::setup();

        account::create_account_for_test(signer::address_of(sender));
        account::create_account_for_test(signer::address_of(pancake_multisig_wallet_dev));
        account::create_account_for_test(signer::address_of(pancake_swap_admin_dev));
        account::create_account_for_test(signer::address_of(pancake_swap_dev));

        resource_account::create_resource_account(pancake_multisig_wallet_dev, b"pancake_multisig_wallet_v4", x"");
        multisig_wallet::init_module_for_test(pancake_multisig_wallet);

        resource_account::create_resource_account(pancake_swap_admin_dev, b"pancake_swap_admin", x"");
        init_module(pancake_swap_admin);

        resource_account::create_resource_account(pancake_swap_dev, b"pancake", x"");
        // let ra = account::create_resource_address(&signer::address_of(pancake_swap_dev), b"pancake_swap");
        // std::debug::print(&ra);
        swap::initialize(pancake_swap);
         // set new multisign wallet as admin
        let pancake_swap_default_admin_singer = account::create_account_for_test(@default_admin);
        swap::set_admin(&pancake_swap_default_admin_singer, signer::address_of(pancake_swap_admin));
    }

    #[test_only]
    fun before_withdraw_swap_fee(
        _sender: &signer,
        executor: &signer,
        approver: &signer,
        initiator: &signer,
        pancake_swap_admin: &signer,
    )
    acquires Capabilities {
        managed_coin::initialize<TestCAKE>(
            pancake_swap_admin,
            b"Test Cake",
            b"TCAKE",
            8,
            true,
        );
        managed_coin::initialize<TestBUSD>(
            pancake_swap_admin,
            b"Test Binance USD",
            b"TBUSD",
            6,
            true,
        );

        managed_coin::register<TestCAKE>(pancake_swap_admin);
        managed_coin::register<TestBUSD>(pancake_swap_admin);

        managed_coin::mint<TestCAKE>(pancake_swap_admin, signer::address_of(pancake_swap_admin), 1000 * 100000000);
        managed_coin::mint<TestBUSD>(pancake_swap_admin, signer::address_of(pancake_swap_admin), 1000 * 1000000);

        router::add_liquidity<TestCAKE, TestBUSD>(pancake_swap_admin, 100 * 100000000, 100 * 1000000, 0, 0);
        router::swap_exact_input<TestCAKE, TestBUSD>(pancake_swap_admin, 1 * 100000000, 0);
        router::remove_liquidity<TestCAKE, TestBUSD>(pancake_swap_admin, 1000000, 0, 0);

        let seq_number = multisig_wallet::next_seq_number(MULTISIG_WALLET_ADDRESS);
        init_set_swap_fee_to(initiator, timestamp::now_seconds(), signer::address_of(pancake_swap_admin));
        approve_set_swap_fee_to(approver, seq_number);
        execute_set_swap_fee_to(executor, seq_number);
    }
}
