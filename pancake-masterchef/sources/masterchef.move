module pancake_masterchef::masterchef {
    use std::string;
    use std::signer;
    use std::vector;

    use aptos_std::event;
    use aptos_std::math64::{max};
    use aptos_std::type_info;
    use aptos_std::table_with_length::{Self as Table, TableWithLength};

    use aptos_framework::coin;
    use aptos_framework::code;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;

    use pancake_oft::oft::{CakeOFT as Cake };

    //
    // Errors.
    //

    const ERROR_NOT_ADMIN: u64 = 0;
    const ERROR_COIN_NOT_PUBLISHED: u64 = 1;
    const ERROR_INVALID_LP_TOKEN: u64 = 2;
    const ERROR_LP_TOKEN_EXIST: u64 = 3;
    const ERROR_WITHDRAW_INSUFFICIENT: u64 = 4;
    const ERROR_INVALID_CAKE_RATE: u64 = 5;
    const ERROR_PID_NOT_EXIST: u64 = 6;
    const ERROR_COIN_NOT_REGISTERED: u64 = 7;
    const ERROR_CAKE_REWARD_OVERFLOW: u64 = 8;
    const ERROR_INVALID_COIN_DECIMAL: u64 = 9;
    const ERROR_POOL_USER_INFO_NOT_EXIST: u64 = 10;
    const ERROR_ZERO_ACCOUNT: u64 = 11;
    const ERROR_UPKEEP_ELAPSED_OVER_CAP: u64 = 12;

    //
    // CONSTANTS.
    //

    const ADMIN: address = @msterchef_admin;
    const UPKEEP_ADMIN: address = @masterchef_upkeep_operator;
    const UPKEEP_ELAPSED_HARD_CAP: u64 = 30 * 24 * 60 * 60; // 1 month
    const RESOURCE_ORIGIN: address = @masterchef_origin;
    const RESOURCE_ACCOUNT: address = @pancake_masterchef;
    const APTOS_DEFAULT_DECIMAL: u8 = 8;
    const TOTAL_CAKE_RATE_PRECISION: u64 = 100000;
    const INITIAL_REGULAR_CAKE_RATE_PRECISION: u64 = 40000;
    const INITIAL_SPECIAL_CAKE_RATE_PRECISION: u64 = 60000;
    const ACC_CAKE_PRECISION: u128 = 1000000000000;
    const MAX_U64: u128 = 18446744073709551615;
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

    /// Metadata
    struct MasterChef has key {
        /// Resource account signer capability
        signer_cap: account::SignerCapability,
        admin: address,
        upkeep_admin: address,
        lp_to_pid: TableWithLength<string::String, u64>,
        /// Frontend query
        lps: vector<string::String>,
        pool_info: vector<PoolInfo>,
        total_regular_alloc_point: u64,
        total_special_alloc_point: u64,
        cake_per_second: u64,
        cake_rate_to_regular: u64,
        cake_rate_to_special: u64,
        last_upkeep_timestamp: u64,
        end_timestamp: u64
    }

    /*
    * Aptos coin can't transfer more than MAX_U64,when calculating cake reward, in order to ensure the
    * cake reward will not loss precision, many field will be multiplied like 'ACC_CAKE_PRECISION'.
    * To make sure this will not cause overflow problem, we set 'user.amount','reward_debt','acc_cake_pershare'
    * as u128,but when calculating the final cake reward,it still will be cast to u64
    */

    struct PoolUserInfo has key {
        pid_to_user_info: TableWithLength<u64, UserInfo>,
        pids: vector<u64>,
    }

    struct UserInfo has store {
        amount: u128,
        ///   reward_debt is a 'accounting' field used for distribute cake reward to each user in the pool.
        ///
        ///   pending_cake_reward = (user.share * pool.acc_cake_per_share) - user.reward_debt
        ///
        ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        ///   1. 'update_pool': The pool info will be updated, that means 'acc_cake_per_share' and 'last_reward_timestamp' updated
        ///   2. 'settle_pending_cake': Masterchef will send all pending CAKE to the user address.
        ///   3. 'reset reward_debt': user.reward_debt = user.share * pool.acc_cake_per_share
        ///   it means that all the CAKE rewards of the user have been taken away at this moment.
        ///
        reward_debt: u128
    }

    struct PoolInfo has store {
        total_amount: u128,
        acc_cake_per_share: u128,
        last_reward_timestamp: u64,
        alloc_point: u64,
        is_regular: bool
    }

    //
    // Events.
    //

    struct Events has key {
        deposit_events: event::EventHandle<DepositEvent>,
        withdraw_events: event::EventHandle<WithdrawEvent>,
        emergency_withdraw_events: event::EventHandle<EmergencyWithdrawEvent>,
        add_pool_events: event::EventHandle<AddPoolEvent>,
        set_pool_events: event::EventHandle<SetPoolEvent>,
        update_pool_events: event::EventHandle<UpdatePoolEvent>,
        update_cake_rate_events: event::EventHandle<UpdateCakeRateEvent>,
        upkeep_events: event::EventHandle<UpkeepEvent>
    }

    /// Event emitted when coin is deposited into an pool.
    struct DepositEvent has drop, store {
        user: address,
        pid: u64,
        amount: u64
    }

    /// Event emitted when coin is withdrawn from an pool.
    struct WithdrawEvent has drop, store {
        user: address,
        pid: u64,
        amount: u64
    }

    /// Event emitted when coin is withdrawn from an pool without get the rewards.
    struct EmergencyWithdrawEvent has drop, store {
        user: address,
        pid: u64,
        amount: u128
    }

    /// Event emitted when add new farm pool.
    struct AddPoolEvent has drop, store {
        pid: u64,
        alloc_point: u64,
        lp: string::String,
        is_regular: bool
    }

    /// Event emitted when reset farm pool alloc point.
    struct SetPoolEvent has drop, store {
        pid: u64,
        prev_alloc_point: u64,
        alloc_point: u64
    }

    /// Event emitted when any action to farm pool will update acc_cake_per_share info.
    struct UpdatePoolEvent has drop, store {
        pid: u64,
        last_reward_timestamp: u64,
        lp_supply: u128,
        acc_cake_per_share: u128
    }

    /// Event emitted when update cake emission rate.
    struct UpdateCakeRateEvent has drop, store {
        regular_farm_rate: u64,
        special_farm_rate: u64
    }

    /// Event emitted when upkeep
    struct UpkeepEvent has drop, store {
        amount: u64,
        elapsed: u64,
        prev_cake_per_second: u64,
        cake_per_second: u64
    }

    fun init_module(sender: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, RESOURCE_ORIGIN);
        let current_timestamp = timestamp::now_seconds();

        move_to(sender, MasterChef {
            signer_cap,
            admin: ADMIN,
            upkeep_admin: UPKEEP_ADMIN,
            lp_to_pid: Table::new(),
            lps: vector::empty(),
            pool_info: vector::empty<PoolInfo>(),
            total_regular_alloc_point: 0,
            total_special_alloc_point: 0,
            cake_per_second: 0,
            cake_rate_to_regular: INITIAL_REGULAR_CAKE_RATE_PRECISION,
            cake_rate_to_special: INITIAL_SPECIAL_CAKE_RATE_PRECISION,
            last_upkeep_timestamp: current_timestamp,
            end_timestamp: current_timestamp
        });

        move_to(sender, Events {
            deposit_events: account::new_event_handle<DepositEvent>(sender),
            withdraw_events: account::new_event_handle<WithdrawEvent>(sender),
            emergency_withdraw_events: account::new_event_handle<EmergencyWithdrawEvent>(sender),
            add_pool_events: account::new_event_handle<AddPoolEvent>(sender),
            set_pool_events: account::new_event_handle<SetPoolEvent>(sender),
            update_pool_events: account::new_event_handle<UpdatePoolEvent>(sender),
            update_cake_rate_events: account::new_event_handle<UpdateCakeRateEvent>(sender),
            upkeep_events: account::new_event_handle<UpkeepEvent>(sender)
        });
    }

    public entry fun deposit<CoinType>(
        sender: &signer,
        amount: u64
    ) acquires MasterChef, PoolUserInfo, Events {
        let sender_addr = signer::address_of(sender);
        assert!(coin::is_account_registered<CoinType>(sender_addr), ERROR_COIN_NOT_REGISTERED);
        // Auto reigster cake
        if (!coin::is_account_registered<Cake>(sender_addr)) {
            coin::register<Cake>(sender);
        };

        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(Table::contains<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>()), ERROR_INVALID_LP_TOKEN);
        let pid = *Table::borrow<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>());
        update_pool(pid);

        if (!exists<PoolUserInfo>(sender_addr)) {
            move_to(sender, PoolUserInfo {
                pid_to_user_info: Table::new(),
                pids: vector::empty(),
            });
        };

        let pool_user_info = borrow_global_mut<PoolUserInfo>(sender_addr);
        if (!Table::contains(&pool_user_info.pid_to_user_info, pid)) {
            Table::add(&mut pool_user_info.pid_to_user_info, pid, UserInfo {
                amount: 0,
                reward_debt: 0,
            });
            vector::push_back(&mut pool_user_info.pids, pid);
        };

        let user_info = Table::borrow_mut<u64, UserInfo>(&mut pool_user_info.pid_to_user_info, pid);
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let pool_info = vector::borrow_mut<PoolInfo>(&mut master_chef_mut.pool_info, pid);

        if (user_info.amount > 0) {
            let pending = (user_info.amount * pool_info.acc_cake_per_share) / ACC_CAKE_PRECISION - user_info.reward_debt;
            assert!(pending <= MAX_U64, ERROR_CAKE_REWARD_OVERFLOW);
            let resource_signer = account::create_signer_with_capability(&master_chef_mut.signer_cap);
            safe_transfer_cake(&resource_signer, sender_addr, (pending as u64))
        };
        if (amount > 0) {
            // Send coin to resource account
            coin::transfer<CoinType>(sender, RESOURCE_ACCOUNT, amount);
            user_info.amount = user_info.amount + (amount as u128);
            pool_info.total_amount = pool_info.total_amount + (amount as u128);
        };

        user_info.reward_debt = user_info.amount * pool_info.acc_cake_per_share / ACC_CAKE_PRECISION;

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<DepositEvent>(
            &mut events.deposit_events,
            DepositEvent {
                user: sender_addr,
                pid,
                amount
            }
        );
    }

    public entry fun withdraw<CoinType>(
        sender: &signer,
        amount: u64
    ) acquires MasterChef, PoolUserInfo, Events {
        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(Table::contains<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>()), ERROR_INVALID_LP_TOKEN);

        let sender_addr = signer::address_of(sender);
        assert!(exists<PoolUserInfo>(sender_addr), ERROR_POOL_USER_INFO_NOT_EXIST);
        let pid = *Table::borrow<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>());
        let user_info = Table::borrow_mut<u64, UserInfo>(&mut borrow_global_mut<PoolUserInfo>(sender_addr).pid_to_user_info, pid);
        assert!(user_info.amount >= (amount as u128), ERROR_WITHDRAW_INSUFFICIENT);

        update_pool(pid);

        // Send pending cake
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let pool_info = vector::borrow_mut<PoolInfo>(&mut master_chef_mut.pool_info, pid);
        let resource_signer = account::create_signer_with_capability(&master_chef_mut.signer_cap);
        let pending = (user_info.amount * pool_info.acc_cake_per_share) / ACC_CAKE_PRECISION - user_info.reward_debt;
        assert!(pending <= MAX_U64, ERROR_CAKE_REWARD_OVERFLOW);
        safe_transfer_cake(&resource_signer, sender_addr, (pending as u64));

        if (amount > 0) {
            user_info.amount = user_info.amount - (amount as u128);
            coin::transfer<CoinType>(&resource_signer, sender_addr, amount);
        };

        user_info.reward_debt = user_info.amount * pool_info.acc_cake_per_share / ACC_CAKE_PRECISION;
        pool_info.total_amount = pool_info.total_amount - (amount as u128);

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<WithdrawEvent>(
            &mut events.withdraw_events,
            WithdrawEvent {
                user: sender_addr,
                pid,
                amount
            }
        );
    }

    /// Withdraw without caring about the rewards. EMERGENCY ONLY.
    public entry fun emergency_withdraw<CoinType>(sender: &signer) acquires MasterChef, PoolUserInfo, Events {
        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(Table::contains<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>()), ERROR_INVALID_LP_TOKEN);

        let sender_addr = signer::address_of(sender);
        assert!(exists<PoolUserInfo>(sender_addr), ERROR_POOL_USER_INFO_NOT_EXIST);
        let pid = *Table::borrow<string::String, u64>(&master_chef.lp_to_pid, type_info::type_name<CoinType>());
        let user_info = Table::borrow_mut<u64, UserInfo>(&mut borrow_global_mut<PoolUserInfo>(sender_addr).pid_to_user_info, pid);
        assert!(user_info.amount > 0, ERROR_WITHDRAW_INSUFFICIENT);

        let amount = user_info.amount;
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let pool_info = vector::borrow_mut<PoolInfo>(&mut master_chef_mut.pool_info, pid);

        user_info.amount = 0;
        user_info.reward_debt = 0;
        pool_info.total_amount = pool_info.total_amount - amount;

        coin::transfer<CoinType>(&account::create_signer_with_capability(&master_chef_mut.signer_cap), sender_addr, (amount as u64));

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<EmergencyWithdrawEvent>(
            &mut events.emergency_withdraw_events,
            EmergencyWithdrawEvent {
                user: sender_addr,
                pid,
                amount
            }
        );
    }

    public entry fun add_pool<CoinType>(
        sender: &signer,
        alloc_point: u64,
        is_regular: bool,
        with_update: bool
    ) acquires MasterChef, Events {
        assert!(coin::is_coin_initialized<CoinType>(), ERROR_COIN_NOT_PUBLISHED);
        // Coin decimal should <= 8, large coin decial may cause overflow
        assert!(coin::decimals<CoinType>() <= APTOS_DEFAULT_DECIMAL, ERROR_INVALID_COIN_DECIMAL);

        let type_info = type_info::type_name<CoinType>();
        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(signer::address_of(sender) == master_chef.admin, ERROR_NOT_ADMIN);
        assert!(!Table::contains<string::String, u64>(&master_chef.lp_to_pid, type_info), ERROR_LP_TOKEN_EXIST);

        if (!coin::is_account_registered<CoinType>(RESOURCE_ACCOUNT)) {
            coin::register<CoinType>(&account::create_signer_with_capability(&master_chef.signer_cap));
        };
        if (with_update) {
            mass_update_pools();
        };

        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        if (is_regular) {
            master_chef_mut.total_regular_alloc_point =  master_chef_mut.total_regular_alloc_point + alloc_point;
        } else {
            master_chef_mut.total_special_alloc_point =  master_chef_mut.total_special_alloc_point + alloc_point;
        };

        let pid = Table::length<string::String, u64>(&master_chef_mut.lp_to_pid);
        Table::add(&mut master_chef_mut.lp_to_pid, type_info, pid);
        vector::push_back(&mut master_chef_mut.lps, type_info);
        vector::push_back<PoolInfo>(
            &mut master_chef_mut.pool_info,
            PoolInfo {
                total_amount: 0,
                acc_cake_per_share: 0,
                last_reward_timestamp: timestamp::now_seconds(),
                alloc_point,
                is_regular,
            }
        );

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<AddPoolEvent>(
            &mut events.add_pool_events,
            AddPoolEvent {
                pid,
                alloc_point,
                lp: type_info,
                is_regular
            }
        );
    }

    public entry fun set_pool(
        sender: &signer,
        pid: u64,
        alloc_point: u64,
        with_update: bool
    ) acquires MasterChef,  Events {
        assert!(pool_length() > pid, ERROR_PID_NOT_EXIST);
        assert!(signer::address_of(sender) == borrow_global<MasterChef>(RESOURCE_ACCOUNT).admin, ERROR_NOT_ADMIN);

        // No matter with_update is true or false, we need to
        // execute 'update_pool' before set the pool parameters.
        update_pool(pid);

        if (with_update) {
            mass_update_pools();
        };

        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let pool_info = vector::borrow_mut<PoolInfo>(&mut master_chef_mut.pool_info, pid);

        if (pool_info.is_regular) {
            master_chef_mut.total_regular_alloc_point =  master_chef_mut.total_regular_alloc_point - pool_info.alloc_point + alloc_point;
        } else {
            master_chef_mut.total_special_alloc_point =  master_chef_mut.total_special_alloc_point - pool_info.alloc_point + alloc_point;
        };

        let prev_alloc_point = pool_info.alloc_point;
        pool_info.alloc_point = alloc_point;
        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<SetPoolEvent>(
            &mut events.set_pool_events,
            SetPoolEvent {
                pid,
                prev_alloc_point,
                alloc_point
            }
        );
    }

    public entry fun mass_update_pools() acquires MasterChef, Events {
        let i = 0;
        let len = pool_length();
        while (i < len) {
            if (vector::borrow<PoolInfo>(&borrow_global<MasterChef>(RESOURCE_ACCOUNT).pool_info, i).alloc_point != 0) {
                update_pool(i);
            };
            i = i + 1;
        }
    }

    public entry fun update_pool(pid: u64) acquires MasterChef, Events {
        let (cake_reward, acc_cake_per_share) = calc_cake_reward(pid);
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let pool_info = vector::borrow_mut<PoolInfo>(&mut master_chef_mut.pool_info, pid);
        let current_timestamp = timestamp::now_seconds();

        if (cake_reward > 0) {
            pool_info.acc_cake_per_share = acc_cake_per_share;
        };

        if (current_timestamp > pool_info.last_reward_timestamp) {
            // Timestamp will always be updated no matter cake_reward is 0 or not
            pool_info.last_reward_timestamp = current_timestamp;

            let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
            event::emit_event<UpdatePoolEvent>(
                &mut events.update_pool_events,
                UpdatePoolEvent {
                    pid: pid,
                    last_reward_timestamp: current_timestamp,
                    lp_supply: pool_info.total_amount,
                    acc_cake_per_share: pool_info.acc_cake_per_share
                }
            );
        };
    }

    public entry fun update_cake_rate(
        sender: &signer,
        regular_farm_rate: u64,
        special_farm_rate: u64,
        with_update: bool
    ) acquires MasterChef, Events {
        // Farm rate can be zero
        assert!(
            regular_farm_rate + special_farm_rate == TOTAL_CAKE_RATE_PRECISION,
            ERROR_INVALID_CAKE_RATE
        );
        assert!(signer::address_of(sender) == borrow_global<MasterChef>(RESOURCE_ACCOUNT).admin, ERROR_NOT_ADMIN);

        if (with_update) {
            mass_update_pools();
        };

        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        master_chef_mut.cake_rate_to_regular = regular_farm_rate;
        master_chef_mut.cake_rate_to_special = special_farm_rate;

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<UpdateCakeRateEvent>(
            &mut events.update_cake_rate_events,
            UpdateCakeRateEvent {
                regular_farm_rate,
                special_farm_rate
            }
        );
    }

    /// Upkeep is an interface completely different from Masterchef on the BNB chain.
    /// On BNB chain, CAKE is minted by the Masterchef contract at a speed of 40 CAKEs
    /// per block, while on the Aptos chain, the mint of CAKE is completely dependent on
    /// the bridged CAKE numbers from the chain bridge, the caller should be the executor
    /// of the CAKE bridge, automatically and regularly executes transactions, sends the
    /// CAKE tokens to current contract, and then Masterchef distributes it to all pools user.
    /// For more flexibility, we also allow the contract's admin to temporarily call this interface
    public entry fun upkeep(
        sender: &signer,
        amount: u64,
        elapsed: u64,
        with_update: bool,
    ) acquires MasterChef, Events {
        assert!(elapsed <= UPKEEP_ELAPSED_HARD_CAP, ERROR_UPKEEP_ELAPSED_OVER_CAP);

        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(signer::address_of(sender) == master_chef.upkeep_admin || signer::address_of(sender) == master_chef.admin, ERROR_NOT_ADMIN);

        if (!coin::is_account_registered<Cake>(RESOURCE_ACCOUNT)) {
            coin::register<Cake>(&account::create_signer_with_capability(&master_chef.signer_cap));
        };

        coin::transfer<Cake>(sender, RESOURCE_ACCOUNT, amount);

        let current_timestamp = timestamp::now_seconds();
        let new_end_timestamp;
        let new_available_cake = amount;

        if (current_timestamp <= master_chef.end_timestamp) {
            new_end_timestamp = master_chef.end_timestamp + elapsed;
            let remaining_cake = (master_chef.end_timestamp - current_timestamp) * master_chef.cake_per_second;
            new_available_cake = new_available_cake + remaining_cake;
        } else {
            new_end_timestamp = current_timestamp + elapsed;
        };

        let new_cake_per_second = new_available_cake / (new_end_timestamp - current_timestamp);

        if (with_update) {
            mass_update_pools();
        };

        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        let prev_cake_per_second = master_chef_mut.cake_per_second;
        master_chef_mut.cake_per_second = new_cake_per_second;
        master_chef_mut.last_upkeep_timestamp = current_timestamp;
        master_chef_mut.end_timestamp = new_end_timestamp;

        let events = borrow_global_mut<Events>(RESOURCE_ACCOUNT);
        event::emit_event<UpkeepEvent>(
            &mut events.upkeep_events,
            UpkeepEvent {
                amount,
                elapsed,
                prev_cake_per_second,
                cake_per_second: master_chef_mut.cake_per_second,
            }
        );
    }

    public entry fun set_admin(
        sender: &signer,
        new_admin: address
    ) acquires MasterChef {
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        assert!(new_admin != @0x0, ERROR_ZERO_ACCOUNT);
        assert!(signer::address_of(sender) == master_chef_mut.admin, ERROR_NOT_ADMIN);
        master_chef_mut.admin = new_admin;
    }

    public entry fun set_upkeep_admin(
        sender: &signer,
        new_upkeep_admin: address
    ) acquires MasterChef {
        let master_chef_mut = borrow_global_mut<MasterChef>(RESOURCE_ACCOUNT);
        assert!(signer::address_of(sender) == master_chef_mut.admin, ERROR_NOT_ADMIN);
        master_chef_mut.upkeep_admin = new_upkeep_admin;
    }

    public entry fun upgrade_masterchef(sender: &signer, metadata_serialized: vector<u8>,code: vector<vector<u8>>) acquires MasterChef {
        let sender_addr = signer::address_of(sender);
        let masterchef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        assert!(sender_addr == masterchef.admin, ERROR_NOT_ADMIN);
        let resource_signer = account::create_signer_with_capability(&masterchef.signer_cap);
        code::publish_package_txn(&resource_signer, metadata_serialized, code);
    }

    public fun pool_length():u64 acquires MasterChef {
        Table::length<string::String, u64>(&borrow_global<MasterChef>(RESOURCE_ACCOUNT).lp_to_pid)
    }

    public fun pending_cake(
        pid: u64,
        user: address
    ): u64 acquires MasterChef, PoolUserInfo {
        let (_, acc_cake_per_share) = calc_cake_reward(pid);

        assert!(exists<PoolUserInfo>(user), ERROR_POOL_USER_INFO_NOT_EXIST);
        let pool_user_info = borrow_global_mut<PoolUserInfo>(user);
        let user_info = Table::borrow_mut<u64, UserInfo>(&mut pool_user_info.pid_to_user_info, pid);

        ((user_info.amount * acc_cake_per_share / ACC_CAKE_PRECISION - user_info.reward_debt) as u64)
    }

    fun calc_cake_reward(pid: u64): (u64, u128) acquires MasterChef {
        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
	    let pool_info = vector::borrow<PoolInfo>(&master_chef.pool_info, pid);

        let cake_reward:u128 = 0;
        let acc_cake_per_share = pool_info.acc_cake_per_share;
        let current_timestamp = timestamp::now_seconds();

        if (current_timestamp > pool_info.last_reward_timestamp) {
            let total_alloc_point;
            let cake_rate;

            if (pool_info.is_regular) {
                total_alloc_point = master_chef.total_regular_alloc_point;
                cake_rate = master_chef.cake_rate_to_regular;
            } else {
                total_alloc_point = master_chef.total_special_alloc_point;
                cake_rate = master_chef.cake_rate_to_special;
            };

            let supply = pool_info.total_amount;

            let multiplier = if (master_chef.end_timestamp <= pool_info.last_reward_timestamp) {
                0
            } else if (current_timestamp <= master_chef.end_timestamp) {
                // if 'mass_update_pools' is ignored on any function which should be called,like 'upkeep',
                // should choose the max timestamp as 'last_reward_timestamp'.
                current_timestamp - max(pool_info.last_reward_timestamp, master_chef.last_upkeep_timestamp)
            } else {
                master_chef.end_timestamp - max(pool_info.last_reward_timestamp, master_chef.last_upkeep_timestamp)
            };

            if (supply > 0 && total_alloc_point > 0) {
                // Aptos built-in maximum integer type is u128, when calculating cake-reward
                // We must be very careful to the priority of multiply or division
                // As ususal,
                //
                // cake_reward = (multiplier * master_chef.cake_per_second * cake_rate * pool_info.alloc_point) / (total_alloc_point * TOTAL_CAKE_RATE_PRECISION)
                //
                // The numerator maybe overflow, so we change it to:
                //
                // cake_reward = (multiplier * ((master_chef.cake_per_second * cake_rate * pool_info.alloc_point) / total_alloc_point)) / TOTAL_CAKE_RATE_PRECISION
                //
                // Because total alloc point will not be a large number, only because aptos does not support u16 or u32 type,
                // Then we define it as u64, actually a small total alloc point will not lead to loss of precision
                cake_reward = ((multiplier as u128) * (((master_chef.cake_per_second as u128) * (cake_rate as u128) * (pool_info.alloc_point as u128)) / (total_alloc_point as u128))) / (TOTAL_CAKE_RATE_PRECISION as u128);
                acc_cake_per_share = (pool_info.acc_cake_per_share) + (cake_reward * ACC_CAKE_PRECISION) / supply;

                assert!(cake_reward <= MAX_U64 && acc_cake_per_share <= MAX_U128, ERROR_CAKE_REWARD_OVERFLOW);
            };
        };

        ((cake_reward as u64), acc_cake_per_share)
    }

    fun safe_transfer_cake(
        resource_signer: &signer,
        to: address, amount: u64
    ) {
        if (amount > 0) {
            let balance = coin::balance<Cake>(RESOURCE_ACCOUNT);
            if (balance < amount) {
                amount = balance;
            };
            coin::transfer<Cake>(resource_signer, to, amount);
        }
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }

    #[test_only]
    public fun get_metadata_info(): (address, u64, u64, u64, u64, u64) acquires MasterChef {
        let master_chef = borrow_global<MasterChef>(RESOURCE_ACCOUNT);
        (master_chef.admin, master_chef.total_regular_alloc_point, master_chef.total_special_alloc_point, master_chef.cake_per_second, master_chef.cake_rate_to_regular, master_chef.cake_rate_to_special)
    }

    #[test_only]
    public fun get_pool_info(pid: u64): (u128, u128, u64, u64, bool) acquires MasterChef {
        let pool_info = vector::borrow<PoolInfo>(&borrow_global<MasterChef>(RESOURCE_ACCOUNT).pool_info, pid);
        (pool_info.total_amount, pool_info.acc_cake_per_share, pool_info.last_reward_timestamp, pool_info.alloc_point, pool_info.is_regular)
    }

    #[test_only]
    public fun get_user_info(pid: u64, user: address): (u128, u128) acquires PoolUserInfo {
        assert!(exists<PoolUserInfo>(user), ERROR_POOL_USER_INFO_NOT_EXIST);
        let pool_user_info = borrow_global_mut<PoolUserInfo>(user);
        let user_info = Table::borrow_mut<u64, UserInfo>(&mut pool_user_info.pid_to_user_info, pid);
        (user_info.amount, user_info.reward_debt)
    }
}
