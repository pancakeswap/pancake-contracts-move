module pancake::smart_chef {
    use aptos_std::event::{EventHandle, emit_event};
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_std::type_info;
    use aptos_std::math128;
    use aptos_framework::code;
    use std::signer;
    use std::string;
    use pancake::u256;
    use pancake_phantom_types::uints::get_number;

    const DEFAULT_ADMIN: address = @pancake_smart_chef_default_admin;
    const RESOURCE_ACCOUNT: address = @pancake;
    const DEV: address = @pancake_smart_chef_dev;

    // error
    const ERROR_ONLY_ADMIN: u64 = 0;
    const ERROR_POOL_EXIST: u64 = 1;
    const ERROR_COIN_NOT_EXIST: u64 = 2;
    const ERROR_PASS_START_TIME: u64 = 3;
    const ERROR_MUST_BE_INFERIOR_TO_TWENTY: u64 = 4;
    const ERROR_POOL_LIMIT_ZERO: u64 = 5;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 6;
    const ERROR_POOL_NOT_EXIST: u64 = 7;
    const ERROR_STAKE_ABOVE_LIMIT: u64 = 8;
    const ERROR_NO_STAKE: u64 = 9;
    const ERROR_NO_LIMIT_SET: u64 = 10;
    const ERROR_LIMIT_MUST_BE_HIGHER: u64 = 11;
    const ERROR_POOL_STARTED: u64 = 12;
    const ERROR_END_TIME_EARLIER_THAN_START_TIME: u64 = 13;
    const ERROR_POOL_END: u64 = 14;
    const ERROR_REWARD_MAX: u64 = 16;
    const ERROR_WRONG_UID: u64 = 17;
    const ERROR_SAME_TOKEN: u64 = 18;

    struct SmartChefMetadata has key {
        signer_cap: account::SignerCapability,
        admin: address,
        uid: u64,
        create_pool_event: EventHandle<CreatePoolEvent>
    }

    struct PoolInfo<phantom StakeToken, phantom RewardToken, phantom UID> has key {
        total_staked_token: coin::Coin<StakeToken>,
        total_reward_token: coin::Coin<RewardToken>,
        reward_per_second: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        last_reward_timestamp: u64,
        seconds_for_user_limit: u64,
        pool_limit_per_user: u64,
        acc_token_per_share: u128,
        precision_factor: u128,
        emergency_withdraw_reward_event: EventHandle<EmergencyWithdrawRewardEvent<StakeToken, RewardToken, UID>>,
        stop_reward_event: EventHandle<StopRewardEvent<StakeToken, RewardToken, UID>>,
        new_pool_limit_event: EventHandle<NewPoolLimitEvent<StakeToken, RewardToken, UID>>,
        new_reward_per_second_event: EventHandle<NewRewardPerSecondEvent<StakeToken, RewardToken, UID>>,
        new_start_and_end_timestamp_event: EventHandle<NewStartAndEndTimestampEvent<StakeToken, RewardToken, UID>>,
    }

    struct UserInfo<phantom StakeToken, phantom RewardToken, phantom UID> has key, store {
        amount: u64,
        reward_debt: u128,
        deposit_event: EventHandle<DepositEvent<StakeToken, RewardToken, UID>>,
        withdraw_event: EventHandle<WithdrawEvent<StakeToken, RewardToken, UID>>,
        emergency_withdraw_event: EventHandle<EmergencyWithdrawEvent<StakeToken, RewardToken, UID>>,
    }

    struct CreatePoolEvent has drop, store {
        user: address,
        stake_token_info: string::String,
        reward_token_info: string::String,
        uid_info: string::String,
    }

    struct DepositEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        amount: u64,
    }

    struct WithdrawEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        amount: u64,
    }

    struct EmergencyWithdrawEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        amount: u64,
    }

    struct EmergencyWithdrawRewardEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        admin: address,
        amount: u64,
    }

    struct StopRewardEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        timestamp: u64
    }

    struct NewPoolLimitEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        pool_limit_per_user: u64
    }

    struct NewRewardPerSecondEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        reward_per_second: u64
    }

    struct NewStartAndEndTimestampEvent<phantom StakeToken, phantom RewardToken, phantom UID>  has drop, store {
        start_timestamp: u64,
        end_timestamp: u64,
    }

    fun init_module(sender: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, DEV);
        let resource_signer = account::create_signer_with_capability(&signer_cap);
        move_to(&resource_signer, SmartChefMetadata {
            signer_cap,
            uid: 0,
            admin: DEFAULT_ADMIN,
            create_pool_event: account::new_event_handle<CreatePoolEvent>(&resource_signer),
        })
    }

    public entry fun create_pool<StakeToken, RewardToken, UID>(
        admin: &signer,
        reward_per_second: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        pool_limit_per_user: u64,
        seconds_for_user_limit: u64
    ) acquires SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global_mut<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(!exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_EXIST);
        assert!(coin::is_coin_initialized<StakeToken>(), ERROR_COIN_NOT_EXIST);
        assert!(coin::is_coin_initialized<RewardToken>(), ERROR_COIN_NOT_EXIST);
        assert!(start_timestamp > timestamp::now_seconds(), ERROR_PASS_START_TIME);
        assert!(start_timestamp < end_timestamp, ERROR_END_TIME_EARLIER_THAN_START_TIME);
        assert!(type_info::type_name<StakeToken>() != type_info::type_name<RewardToken>(), ERROR_SAME_TOKEN);
        assert!(get_number<UID>() == metadata.uid, ERROR_WRONG_UID);
        let resource_signer = account::create_signer_with_capability(&metadata.signer_cap);

        if (seconds_for_user_limit > 0) {
            assert!(pool_limit_per_user > 0, ERROR_POOL_LIMIT_ZERO);
        };

        let reward_token_decimal = coin::decimals<RewardToken>();
        assert!(reward_token_decimal < 20, ERROR_MUST_BE_INFERIOR_TO_TWENTY);
        let precision_factor = math128::pow(10u128, ((20 - reward_token_decimal) as u128));

        move_to(&resource_signer,
            PoolInfo<StakeToken, RewardToken, UID> {
                total_staked_token: coin::zero<StakeToken>(),
                total_reward_token: coin::zero<RewardToken>(),
                reward_per_second,
                last_reward_timestamp: start_timestamp,
                start_timestamp,
                end_timestamp,
                seconds_for_user_limit,
                pool_limit_per_user,
                acc_token_per_share: 0,
                precision_factor,
                emergency_withdraw_reward_event: account::new_event_handle<EmergencyWithdrawRewardEvent<StakeToken, RewardToken, UID>>(&resource_signer),
                stop_reward_event: account::new_event_handle<StopRewardEvent<StakeToken, RewardToken, UID>>(&resource_signer),
                new_pool_limit_event: account::new_event_handle<NewPoolLimitEvent<StakeToken, RewardToken, UID>>(&resource_signer),
                new_reward_per_second_event: account::new_event_handle<NewRewardPerSecondEvent<StakeToken, RewardToken, UID>>(&resource_signer),
                new_start_and_end_timestamp_event: account::new_event_handle<NewStartAndEndTimestampEvent<StakeToken, RewardToken, UID>>(&resource_signer),
            });

        metadata.uid = metadata.uid + 1;

        emit_event<CreatePoolEvent>(
            &mut metadata.create_pool_event,
            CreatePoolEvent {
                user: admin_address,
                stake_token_info: type_info::type_name<StakeToken>(),
                reward_token_info: type_info::type_name<RewardToken>(),
                uid_info: type_info::type_name<UID>(),
            }
        )
    }

    public entry fun add_reward<StakeToken, RewardToken, UID>(
        admin: &signer,
        amount: u64
    ) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);

        transfer_in(&mut pool_info.total_reward_token, admin, amount);
    }

    public entry fun deposit<StakeToken, RewardToken, UID>(
        account: &signer,
        amount: u64
    ) acquires PoolInfo, UserInfo {
        let account_address = signer::address_of(account);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        let now = timestamp::now_seconds();
        assert!(pool_info.end_timestamp > now, ERROR_POOL_END);
        if (!exists<UserInfo<StakeToken, RewardToken, UID>>(account_address)) {
            move_to(account, UserInfo<StakeToken, RewardToken, UID> {
                amount: 0,
                reward_debt: 0,
                deposit_event: account::new_event_handle<DepositEvent<StakeToken, RewardToken, UID>>(account),
                withdraw_event: account::new_event_handle<WithdrawEvent<StakeToken, RewardToken, UID>>(account),
                emergency_withdraw_event: account::new_event_handle<EmergencyWithdrawEvent<StakeToken, RewardToken, UID>>(account),
            })
        };

        update_pool(pool_info);

        let user_info = borrow_global_mut<UserInfo<StakeToken, RewardToken, UID>>(account_address);
        assert!(((user_info.amount + amount) <= pool_info.pool_limit_per_user) || (now >= (pool_info.start_timestamp + pool_info.seconds_for_user_limit)), ERROR_STAKE_ABOVE_LIMIT);

        if (user_info.amount > 0) {
            let pending_reward = cal_pending_reward(user_info.amount, user_info.reward_debt, pool_info.acc_token_per_share, pool_info.precision_factor);
            if (pending_reward > 0) transfer_out<RewardToken>(&mut pool_info.total_reward_token, account, pending_reward)
        };

        if (amount > 0) {
            transfer_in<StakeToken>(&mut pool_info.total_staked_token, account, amount);
            user_info.amount = user_info.amount + amount;
        };

        user_info.reward_debt = reward_debt(user_info.amount, pool_info.acc_token_per_share, pool_info.precision_factor);

        emit_event<DepositEvent<StakeToken, RewardToken, UID>>(
            &mut user_info.deposit_event,
            DepositEvent {
                amount
            }
        )
    }

    public entry fun withdraw<StakeToken, RewardToken, UID>(
        account: &signer,
        amount: u64,
    ) acquires PoolInfo, UserInfo {
        let account_address = signer::address_of(account);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);

        update_pool(pool_info);

        assert!(exists<UserInfo<StakeToken, RewardToken, UID>>(account_address), ERROR_NO_STAKE);
        let user_info = borrow_global_mut<UserInfo<StakeToken, RewardToken, UID>>(account_address);
        assert!(user_info.amount >= amount, ERROR_INSUFFICIENT_BALANCE);

        let pending_reward = cal_pending_reward(user_info.amount, user_info.reward_debt, pool_info.acc_token_per_share, pool_info.precision_factor);

        if (amount > 0) {
            user_info.amount = user_info.amount - amount;
            transfer_out<StakeToken>(&mut pool_info.total_staked_token, account, amount);
        };

        if (pending_reward > 0) {
            transfer_out<RewardToken>(&mut pool_info.total_reward_token, account, pending_reward);
        };

        user_info.reward_debt = reward_debt(user_info.amount, pool_info.acc_token_per_share, pool_info.precision_factor);

        emit_event<WithdrawEvent<StakeToken, RewardToken, UID>>(
            &mut user_info.withdraw_event,
            WithdrawEvent {
                amount
            }
        )
    }

    public entry fun emergency_withdraw<StakeToken, RewardToken, UID>(account: &signer) acquires PoolInfo, UserInfo {
        let account_address = signer::address_of(account);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        assert!(exists<UserInfo<StakeToken, RewardToken, UID>>(account_address), ERROR_NO_STAKE);
        let user_info = borrow_global_mut<UserInfo<StakeToken, RewardToken, UID>>(account_address);
        let amount = user_info.amount;
        assert!(amount > 0, ERROR_INSUFFICIENT_BALANCE);

        user_info.amount = 0;
        user_info.reward_debt = 0;

        transfer_out<StakeToken>(&mut pool_info.total_staked_token, account, amount);

        emit_event<EmergencyWithdrawEvent<StakeToken, RewardToken, UID>>(
            &mut user_info.emergency_withdraw_event,
            EmergencyWithdrawEvent {
                amount
            }
        )
    }

    public entry fun emergency_reward_withdraw<StakeToken, RewardToken, UID>(admin: &signer) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        let reward = coin::value(&pool_info.total_reward_token);
        assert!(reward > 0, ERROR_INSUFFICIENT_BALANCE);

        transfer_out<RewardToken>(&mut pool_info.total_reward_token, admin, reward);

        emit_event<EmergencyWithdrawRewardEvent<StakeToken, RewardToken, UID>>(
            &mut pool_info.emergency_withdraw_reward_event,
            EmergencyWithdrawRewardEvent {
                admin: admin_address,
                amount: reward,
            }
        )
    }

    public entry fun stop_reward<StakeToken, RewardToken, UID>(admin: &signer) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let now = timestamp::now_seconds();
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        pool_info.end_timestamp = now;

        emit_event<StopRewardEvent<StakeToken, RewardToken, UID>>(
            &mut pool_info.stop_reward_event,
            StopRewardEvent {
                timestamp: now,
            }
        )
    }

    public entry fun update_pool_limit_per_user<StakeToken, RewardToken, UID>(admin: &signer, seconds_for_user_limit: bool, pool_limit_per_user: u64) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        assert!((pool_info.seconds_for_user_limit > 0) && (timestamp::now_seconds() < (pool_info.start_timestamp + pool_info.seconds_for_user_limit)), ERROR_NO_LIMIT_SET);
        if (seconds_for_user_limit) {
            assert!(pool_limit_per_user > pool_info.pool_limit_per_user, ERROR_LIMIT_MUST_BE_HIGHER);
            pool_info.pool_limit_per_user = pool_limit_per_user
        }else {
            pool_info.seconds_for_user_limit = 0;
            pool_info.pool_limit_per_user = 0
        };

        emit_event<NewPoolLimitEvent<StakeToken, RewardToken, UID>>(
            &mut pool_info.new_pool_limit_event,
            NewPoolLimitEvent {
                pool_limit_per_user: pool_info.pool_limit_per_user
            }
        )
    }

    public entry fun update_reward_per_second<StakeToken, RewardToken, UID>(admin: &signer, reward_per_second: u64) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);

        assert!(timestamp::now_seconds() < pool_info.start_timestamp, ERROR_POOL_STARTED);
        pool_info.reward_per_second = reward_per_second;

        emit_event<NewRewardPerSecondEvent<StakeToken, RewardToken, UID>>(
            &mut pool_info.new_reward_per_second_event,
            NewRewardPerSecondEvent {
                reward_per_second
            }
        )
    }

    public entry fun update_start_and_end_timestamp<StakeToken, RewardToken, UID>(admin: &signer, start_timestamp: u64, end_timestamp: u64) acquires PoolInfo, SmartChefMetadata {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        let now = timestamp::now_seconds();
        assert!(now < pool_info.start_timestamp, ERROR_POOL_STARTED);
        assert!(start_timestamp < end_timestamp, ERROR_END_TIME_EARLIER_THAN_START_TIME);
        assert!(now < start_timestamp, ERROR_PASS_START_TIME);

        pool_info.start_timestamp = start_timestamp;
        pool_info.end_timestamp = end_timestamp;

        pool_info.last_reward_timestamp = start_timestamp;

        emit_event<NewStartAndEndTimestampEvent<StakeToken, RewardToken, UID>>(
            &mut pool_info.new_start_and_end_timestamp_event,
            NewStartAndEndTimestampEvent {
                start_timestamp,
                end_timestamp
            }
        )
    }

    public entry fun set_admin(sender: &signer, new_admin: address) acquires SmartChefMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global_mut<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        metadata.admin = new_admin;
    }

    public fun get_pool_info<StakeToken, RewardToken, UID>(): (u64, u64, u64, u64, u64, u64, u64) acquires PoolInfo {
        assert!(exists<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_EXIST);
        let pool_info = borrow_global<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        (
            coin::value(&pool_info.total_staked_token),
            coin::value(&pool_info.total_reward_token),
            pool_info.reward_per_second,
            pool_info.start_timestamp,
            pool_info.end_timestamp,
            pool_info.seconds_for_user_limit,
            pool_info.pool_limit_per_user,
        )
    }

    public fun get_user_stake_amount<StakeToken, RewardToken, UID>(account: address): u64 acquires UserInfo {
        let user_info = borrow_global<UserInfo<StakeToken, RewardToken, UID>>(account);
        user_info.amount
    }

    public fun get_pending_reward<StakeToken, RewardToken, UID>(account: address): u64 acquires PoolInfo, UserInfo {
        let pool_info = borrow_global<PoolInfo<StakeToken, RewardToken, UID>>(RESOURCE_ACCOUNT);
        let user_info = borrow_global<UserInfo<StakeToken, RewardToken, UID>>(account);
        let acc_token_per_share = if (coin::value(&pool_info.total_staked_token) == 0 || timestamp::now_seconds() < pool_info.last_reward_timestamp) {
            pool_info.acc_token_per_share
        } else {
            cal_acc_token_per_share(
                pool_info.acc_token_per_share,
                coin::value(&pool_info.total_staked_token),
                pool_info.end_timestamp,
                pool_info.reward_per_second,
                pool_info.precision_factor,
                pool_info.last_reward_timestamp
            )
        };
        cal_pending_reward(user_info.amount, user_info.reward_debt, acc_token_per_share, pool_info.precision_factor)
    }

    fun update_pool<StakeToken, RewardToken, UID>(pool_info: &mut PoolInfo<StakeToken, RewardToken, UID>) {
        let now = timestamp::now_seconds();
        if (now <= pool_info.last_reward_timestamp) return;

        if (coin::value(&pool_info.total_staked_token) == 0) {
            pool_info.last_reward_timestamp = now;
            return
        };

        let new_acc_token_per_share = cal_acc_token_per_share(
            pool_info.acc_token_per_share,
            coin::value(&pool_info.total_staked_token),
            pool_info.end_timestamp,
            pool_info.reward_per_second,
            pool_info.precision_factor,
            pool_info.last_reward_timestamp
        );

        if (pool_info.acc_token_per_share == new_acc_token_per_share) return;
        pool_info.acc_token_per_share = new_acc_token_per_share;
        pool_info.last_reward_timestamp = now;
    }

    fun cal_acc_token_per_share(last_acc_token_per_share: u128, total_staked_token: u64, end_timestamp: u64, reward_per_second: u64, precision_factor: u128, last_reward_timestamp: u64): u128 {
        let multiplier = get_multiplier(last_reward_timestamp, timestamp::now_seconds(), end_timestamp);
        let reward = u256::from_u128((reward_per_second as u128) * (multiplier as u128));
        if (multiplier == 0) return last_acc_token_per_share;
        // acc_token_per_share = acc_token_per_share + (reward * precision_factor) / total_stake;
        let acc_token_per_share_u256 = u256::add(
            u256::from_u128(last_acc_token_per_share),
            u256::div(
                u256::mul(reward, u256::from_u128(precision_factor)),
                u256::from_u64(total_staked_token)
            )
        );
        u256::as_u128(acc_token_per_share_u256)
    }

    fun cal_pending_reward(amount: u64, reward_debt: u128, acc_token_per_share: u128, precision_factor: u128): u64 {
        // pending = (user_info::amount * pool_info.acc_token_per_share) / pool_info.precision_factor - user_info.reward_debt
        u256::as_u64(
            u256::sub(
                u256::div(
                    u256::mul(
                        u256::from_u64(amount),
                        u256::from_u128(acc_token_per_share)
                    ), u256::from_u128(precision_factor)
                ), u256::from_u128(reward_debt))
        )
    }

    fun reward_debt(amount: u64, acc_token_per_share: u128, precision_factor: u128): u128 {
        // user.reward_debt = (user_info.amount * pool_info.acc_token_per_share) / pool_info.precision_factor;
        u256::as_u128(
            u256::div(
                u256::mul(
                    u256::from_u64(amount),
                    u256::from_u128(acc_token_per_share)
                ),
                u256::from_u128(precision_factor)
            )
        )
    }

    fun get_multiplier(from_timestamp: u64, to_timestamp: u64, end_timestamp: u64): u64 {
        if (to_timestamp <= end_timestamp) {
            to_timestamp - from_timestamp
        }else if (from_timestamp >= end_timestamp) {
            0
        } else {
            end_timestamp - from_timestamp
        }
    }

    fun check_or_register_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };
    }

    fun transfer_in<CoinType>(own_coin: &mut coin::Coin<CoinType>, account: &signer, amount: u64) {
        let coin = coin::withdraw<CoinType>(account, amount);
        coin::merge(own_coin, coin);
    }

    fun transfer_out<CoinType>(own_coin: &mut coin::Coin<CoinType>, receiver: &signer, amount: u64) {
        check_or_register_coin_store<CoinType>(receiver);
        let extract_coin = coin::extract<CoinType>(own_coin, amount);
        coin::deposit<CoinType>(signer::address_of(receiver), extract_coin);
    }

    public entry fun upgrade_contract(sender: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires SmartChefMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        let resource_signer = account::create_signer_with_capability(&metadata.signer_cap);
        code::publish_package_txn(&resource_signer, metadata_serialized, code);
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}