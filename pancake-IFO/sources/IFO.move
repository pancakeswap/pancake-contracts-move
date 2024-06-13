module pancake_IFO::IFO {
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;

    use aptos_framework::account::{Self, new_event_handle};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{emit_event, EventHandle};
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_framework::code;

    use pancake_IFO::IFO_utils;
    use pancake_phantom_types::uints;
    
    const DEFAULT_ADMIN: address = @IFO_default_admin;
    const IFO_DEV: address = @IFO_dev;
    const RESOURCE_ACCOUNT: address = @pancake_IFO;

    // Default config
    const DEFAULT_MAX_BUFFER_TIME: u64 = 7*24*3600; // 7 days in seconds
    const DEFAULT_NUM_POOLS: u64 = 2;

    // List of errors
    const ERROR_ONLY_ADMIN: u64 = 1;
    const ERROR_POOL_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_POOL_NOT_INITIALIZED: u64 = 3;
    const ERROR_SAME_TOKENS: u64 = 4;
    const ERROR_TOO_LONG_DURATION: u64 = 5;
    const ERROR_TIME_ORDER: u64 = 6;
    const ERROR_START_TIME: u64 = 7;
    const ERROR_POOL_NOT_SET: u64 = 8;
    const ERROR_IFO_NOT_EXIST: u64 = 9;
    const ERROR_INVALID_POOL_ID: u64 = 10;
    const ERROR_DEPOSIT_TOO_EARLY: u64 = 11;
    const ERROR_DEPOSIT_TOO_LATE: u64 = 12;
    const ERROR_DEPOSIT_ZERO: u64 = 13;
    const ERROR_NOT_QUALIFIED: u64 = 14;
    const ERROR_EXCEED_LIMIT: u64 = 15;
    const ERROR_HARVEST_TOO_EARLY: u64 = 16;
    const ERROR_USER_NOT_PARTICIPATE: u64 = 17;
    const ERROR_ALREADY_CLAIMED: u64 = 18;
    const ERROR_INSUFFCIENT_OFFERING_COIN: u64 = 19;
    const ERROR_EXISTING_VESTING_ID: u64 = 20;
    const ERROR_NOT_ENOUGH_RAISING_COIN: u64 = 21;
    const ERROR_NOT_ENOUGH_OFFERING_COIN: u64 = 22;
    const ERROR_IFO_STARTED: u64 = 23;
    const ERROR_IFO_ENDED: u64 = 24;
    const ERROR_INVALID_VESTING_PERCENTAGE: u64 = 25;
    const ERROR_INVALID_VESTING_DURATION: u64 = 26;
    const ERROR_INVALID_VESTING_SLICE_PERIOD: u64 = 27;
    const ERROR_INDEX_OUT_OF_BOUND: u64 = 28;
    const ERROR_VESTING_SCHEDULE_NOT_EXIST: u64 = 29;
    const ERROR_ONLY_ADMIN_OR_BENEFICIARY: u64 = 30;
    const ERROR_NO_COINS_TO_RELEASE: u64 = 31;
    const ERROR_ALREADY_REVOKED: u64 = 32;

    struct GlobalConfig has key {
        signer_cap: account::SignerCapability,
        max_buffer_time: u64,
        num_pools: u64,
        admin: address
    }

    // Stores the IFO projects' metadata
    struct IFOMetadata<phantom RaisingCoin, phantom OfferingCoin> has key {
        start_time: u64,
        end_time: u64,
        max_buffer_time: u64,
        vesting_start_time: u64,
        vesting_revoked: bool,
        total_coins_offered: u64,
        raising_coin_store: Coin<RaisingCoin>,
        offering_coin_store: Coin<OfferingCoin>,
        start_and_end_time_set: EventHandle<StartAndEndTimeSetEvent>,
        admin_withdral_events: EventHandle<AdminWithdralEvent>,
        revoked_events: EventHandle<RevokedEvent>
    }

    // Stores the metadata required of the vesting schedules
    struct VestingMetadata<phantom RaisingCoin, phantom OfferingCoin> has key {
        vesting_total_amount: u64,
        vesting_schedule_ids: vector<vector<u8>>,
        vesting_schedules: Table<vector<u8>, VestingSchedule>,
        holders_vesting_count: Table<address, u64>
    }

    struct VestingSchedule has store {
        beneficiary: address,
        pid: u64,
        amount_total: u64,
        amount_released: u64
    }

    struct IFOPool<phantom RaisingCoin, phantom OfferingCoin, phantom PoolID> has key {
        raising_amount: u64,
        offering_amount: u64,
        total_coins_offered: u64,
        limit_per_user: u64,
        has_tax: bool,
        sum_taxes_overflow: u64,
        total_amount: u64,
        vesting_percentage: u64,
        vesting_cliff: u64,
        vesting_duration: u64,
        vesting_slice_period_seconds: u64,
        deposit_events: EventHandle<DepositEvent>,
        harvest_events: EventHandle<HarvestEvent>,
        create_vesting_schedule_events: EventHandle<CreateVestingScheduleEvent>,
        pool_parameters_set: EventHandle<PoolParametersSetEvent>,
        released_events: EventHandle<ReleasedEvent>
    }

    struct UserInfo<phantom RaisingCoin, phantom OfferingCoin, phantom PoolID> has key {
        amount: u64,
        claimed: bool
    }

    struct StartAndEndTimeSetEvent has drop,store {
        start_time: u64,
        end_time: u64
    }

    struct DepositEvent has drop, store {
        user: address,
        amount: u64,
        pid: u64
    }

    struct HarvestEvent has drop, store {
        user: address,
        offering_amount: u64,
        excess_amount: u64,
        pid: u64
    }

    struct CreateVestingScheduleEvent has drop, store {
        user: address,
        offering_amount: u64,
        excess_amount: u64,
        pid: u64
    }

    struct AdminWithdralEvent has drop,store {
        raising_amount: u64,
        offering_amount: u64
    }

    struct PoolParametersSetEvent has drop,store {
        raising_amount: u64,
        offering_amount: u64,
        pid: u64
    }

    struct ReleasedEvent has drop,store {
        beneficiary: address,
        amount: u64
    }

    struct RevokedEvent has drop,store {}

    fun init_module(sender: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, IFO_DEV);
        let resource_signer = account::create_signer_with_capability(&signer_cap);
        move_to(
            &resource_signer,
            GlobalConfig{
                signer_cap,
                max_buffer_time: DEFAULT_MAX_BUFFER_TIME,
                num_pools: DEFAULT_NUM_POOLS,
                admin: DEFAULT_ADMIN
            }
        );
    }

    // Initialize a IFO project and set the sender to be the project's owner
    public entry fun initialize_pool<RaisingCoin, OfferingCoin>(
        admin: &signer,
        start_time: u64,
        end_time: u64
    ) acquires GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        assert!(!is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_POOL_ALREADY_INITIALIZED);
        assert!(!is_same_coin<RaisingCoin, OfferingCoin>(), ERROR_SAME_TOKENS);
        assert!(end_time <= start_time + get_max_buffer_time(), ERROR_TOO_LONG_DURATION);
        assert!(start_time < end_time, ERROR_TIME_ORDER);
        assert!(start_time > timestamp::now_seconds(), ERROR_START_TIME);
        let global_config = borrow_global<GlobalConfig>(RESOURCE_ACCOUNT);
        let resource_signer = &account::create_signer_with_capability(&global_config.signer_cap);
        move_to(
            resource_signer,
            IFOMetadata<RaisingCoin, OfferingCoin>{
                start_time,
                end_time,
                max_buffer_time: get_max_buffer_time(),
                vesting_start_time: 0,
                vesting_revoked: false,
                total_coins_offered: 0,
                raising_coin_store: coin::zero<RaisingCoin>(),
                offering_coin_store: coin::zero<OfferingCoin>(),
                start_and_end_time_set: new_event_handle<StartAndEndTimeSetEvent>(resource_signer),
                admin_withdral_events: new_event_handle<AdminWithdralEvent>(resource_signer),
                revoked_events: new_event_handle<RevokedEvent>(resource_signer)
            }
        );
        move_to(
            resource_signer,
            VestingMetadata<RaisingCoin, OfferingCoin>{
                vesting_total_amount: 0,
                vesting_schedule_ids: vector::empty<vector<u8>>(),
                vesting_schedules: table::new<vector<u8>, VestingSchedule>(),
                holders_vesting_count: table::new<address, u64>()
            }
        )
    }

    // It allows the owner to set the pool's metadata
    public entry fun set_pool<RaisingCoin, OfferingCoin, PoolID>(
        admin: &signer,
        raising_amount: u64,
        offering_amount: u64,
        limit_per_user: u64,
        has_tax: bool,
        vesting_percentage: u64,
        vesting_cliff: u64,
        vesting_duration: u64,
        vesting_slice_period_seconds: u64
    ) acquires IFOMetadata, GlobalConfig, IFOPool {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        let pid = uints::get_number<PoolID>();
        assert!(pid < get_num_pools(), ERROR_INVALID_POOL_ID);
        assert!(timestamp::now_seconds() < ifo_metadata.start_time, ERROR_IFO_STARTED);
        assert!(vesting_percentage <= 100, ERROR_INVALID_VESTING_PERCENTAGE);
        if(vesting_percentage > 0){
            assert!(vesting_duration > 0, ERROR_INVALID_VESTING_DURATION);
            assert!(vesting_slice_period_seconds >=1 && vesting_slice_period_seconds <= vesting_duration, ERROR_INVALID_VESTING_SLICE_PERIOD);
        };
        if (!exists<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT)) {
            let global_config = borrow_global<GlobalConfig>(RESOURCE_ACCOUNT);
            let resource_signer = &account::create_signer_with_capability(&global_config.signer_cap);
            let ifo_pool = IFOPool<RaisingCoin, OfferingCoin, PoolID>{
                raising_amount,
                offering_amount,
                limit_per_user,
                has_tax,
                sum_taxes_overflow: 0,
                total_amount: 0,
                vesting_percentage,
                vesting_cliff,
                vesting_duration,
                vesting_slice_period_seconds,
                total_coins_offered: 0,
                deposit_events: new_event_handle<DepositEvent>(resource_signer),
                harvest_events: new_event_handle<HarvestEvent>(resource_signer),
                create_vesting_schedule_events: new_event_handle<CreateVestingScheduleEvent>(resource_signer),
                pool_parameters_set: new_event_handle<PoolParametersSetEvent>(resource_signer),
                released_events: new_event_handle<ReleasedEvent>(resource_signer)
            };
            move_to(resource_signer, ifo_pool);
        } else {
            let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
            ifo_metadata.total_coins_offered = ifo_metadata.total_coins_offered - ifo_pool.offering_amount;

            ifo_pool.raising_amount = raising_amount;
            ifo_pool.offering_amount = offering_amount;
            ifo_pool.limit_per_user = limit_per_user;
            ifo_pool.has_tax = has_tax;
            ifo_pool.vesting_percentage = vesting_percentage;
            ifo_pool.vesting_cliff = vesting_cliff;
            ifo_pool.vesting_duration = vesting_duration;
            ifo_pool.vesting_slice_period_seconds = vesting_slice_period_seconds;
        };
        // update total offered coins
        ifo_metadata.total_coins_offered = ifo_metadata.total_coins_offered + offering_amount;
        let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        emit_event(
            &mut ifo_pool.pool_parameters_set,
            PoolParametersSetEvent{
                raising_amount,
                offering_amount,
                pid
            }
        )
    }

    // It allows the owner to deposit the offering coins to a pool
    public entry fun deposit_offering_coin<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, amount: u64) acquires IFOMetadata, IFOPool {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(exists<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT), ERROR_POOL_NOT_INITIALIZED);
        let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        ifo_pool.total_coins_offered = ifo_pool.total_coins_offered + amount;
        coin::merge(&mut ifo_metadata.offering_coin_store, coin::withdraw<OfferingCoin>(sender, amount));
    }

    //  It allows users to deposit raising coins to a pool
    public entry fun deposit<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, amount: u64) acquires IFOMetadata, UserInfo, IFOPool {
        assert!(is_pool_set<RaisingCoin, OfferingCoin, PoolID>(), ERROR_POOL_NOT_SET);
        assert!(amount > 0, ERROR_DEPOSIT_ZERO);

        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(timestamp::now_seconds() > ifo_metadata.start_time, ERROR_DEPOSIT_TOO_EARLY);
        assert!(timestamp::now_seconds() < ifo_metadata.end_time, ERROR_DEPOSIT_TOO_LATE);
        let sender_address = signer::address_of(sender);
        let coins = coin::withdraw<RaisingCoin>(sender, amount);
        let amount = coin::value(&coins);
        coin::merge(&mut ifo_metadata.raising_coin_store, coins);
        if (!exists<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(sender_address)) {
            move_to(sender, UserInfo<RaisingCoin, OfferingCoin, PoolID>{ amount: 0, claimed: false });
        };
        handle_deposit<RaisingCoin, OfferingCoin, PoolID>(sender_address, amount);
    }

    // It allows users to harvest from pool
    public entry fun harvest_pool<RaisingCoin, OfferingCoin, PoolID>(sender: &signer) acquires IFOMetadata, VestingMetadata, IFOPool, UserInfo {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        assert!(is_pool_set<RaisingCoin, OfferingCoin, PoolID>(), ERROR_POOL_NOT_SET);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(timestamp::now_seconds() >= ifo_metadata.end_time, ERROR_HARVEST_TOO_EARLY);
        let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        let sender_address = signer::address_of(sender);
        assert!(exists<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(sender_address), ERROR_USER_NOT_PARTICIPATE);
        let user_info = borrow_global_mut<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(sender_address);
        assert!(user_info.claimed == false, ERROR_ALREADY_CLAIMED);
        user_info.claimed = true;
        if (ifo_metadata.vesting_start_time == 0) {
            ifo_metadata.vesting_start_time = timestamp::now_seconds();
        };
        let (offering_amount, refund_amount, tax_overflow) = compute_offering_refund_and_tax_amount(user_info.amount, ifo_pool);
        if (offering_amount > 0) {
            if (100 - ifo_pool.vesting_percentage > 0) {
                let amount = ((offering_amount as u128) * ((100 - ifo_pool.vesting_percentage) as u128) / 100u128 as u64);
                IFO_utils::check_or_register_coin_store<OfferingCoin>(sender);
                coin::deposit(sender_address, coin::extract(&mut ifo_metadata.offering_coin_store, amount));
                emit_event(
                    &mut ifo_pool.harvest_events,
                    HarvestEvent{
                        user: sender_address,
                        offering_amount: amount,
                        excess_amount: refund_amount,
                        pid: uints::get_number<PoolID>()
                    }
                )
            };
            if (ifo_pool.vesting_percentage > 0) {
                let amount = offering_amount * ifo_pool.vesting_percentage/100;
                create_vesting_schedule<RaisingCoin, OfferingCoin, PoolID>(sender_address, amount, coin::value(&ifo_metadata.offering_coin_store));
                emit_event(
                    &mut ifo_pool.create_vesting_schedule_events,
                    CreateVestingScheduleEvent{
                        user: sender_address,
                        offering_amount: amount,
                        excess_amount: refund_amount,
                        pid: uints::get_number<PoolID>()
                    }
                )
            }
        };
        if (tax_overflow > 0) {
            ifo_pool.sum_taxes_overflow = ifo_pool.sum_taxes_overflow + tax_overflow;
        };
        if (refund_amount > 0) {
            coin::deposit(sender_address, coin::extract(&mut ifo_metadata.raising_coin_store, refund_amount));
        }
    }

    //  It allows the owner to withdraw funds
    public entry fun final_withdraw<RaisingCoin, OfferingCoin>(admin: &signer, raising_amount: u64, offering_amount: u64) acquires IFOMetadata, GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(coin::value(&ifo_metadata.raising_coin_store) >= raising_amount, ERROR_NOT_ENOUGH_RAISING_COIN);
        assert!(coin::value(&ifo_metadata.offering_coin_store) >= offering_amount, ERROR_NOT_ENOUGH_OFFERING_COIN);
        IFO_utils::check_or_register_coin_store<RaisingCoin>(admin);
        IFO_utils::check_or_register_coin_store<OfferingCoin>(admin);
        coin::deposit<RaisingCoin>(signer::address_of(admin), coin::extract(&mut ifo_metadata.raising_coin_store, raising_amount));
        coin::deposit<OfferingCoin>(signer::address_of(admin), coin::extract(&mut ifo_metadata.offering_coin_store, offering_amount));
        emit_event(
            &mut ifo_metadata.admin_withdral_events,
            AdminWithdralEvent{
                raising_amount,
                offering_amount,
            }
        )
    }

    // Release vested amount of offering tokens
    public entry fun release<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, vesting_schedule_id: vector<u8>) acquires IFOMetadata, VestingMetadata, IFOPool, GlobalConfig {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let vesting_metadata = borrow_global_mut<VestingMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(table::contains(&vesting_metadata.vesting_schedules, vesting_schedule_id), ERROR_VESTING_SCHEDULE_NOT_EXIST);
        let vesting_schedule = table::borrow_mut<vector<u8>, VestingSchedule>(
            &mut vesting_metadata.vesting_schedules,
            vesting_schedule_id
        );
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        let sender_address = signer::address_of(sender);
        let is_beneficiary = { vesting_schedule.beneficiary == sender_address };
        assert!(is_beneficiary || is_admin(sender), ERROR_ONLY_ADMIN_OR_BENEFICIARY);
        let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        let vested_amount = compute_release_amount<RaisingCoin, OfferingCoin, PoolID>(ifo_metadata, ifo_pool, vesting_schedule);
        assert!(vested_amount > 0, ERROR_NO_COINS_TO_RELEASE);
        vesting_schedule.amount_released = vesting_schedule.amount_released + vested_amount;
        vesting_metadata.vesting_total_amount = vesting_metadata.vesting_total_amount - vested_amount;
        coin::deposit(vesting_schedule.beneficiary, coin::extract(&mut ifo_metadata.offering_coin_store, vested_amount));
        emit_event(
            &mut ifo_pool.released_events,
            ReleasedEvent{
                beneficiary: vesting_schedule.beneficiary,
                amount: vested_amount
            }
        )
    }

    // Revokes all the vesting schedules
    public entry fun revoke<RaisingCoin, OfferingCoin>(admin: &signer) acquires IFOMetadata, GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(!ifo_metadata.vesting_revoked, ERROR_ALREADY_REVOKED);
        ifo_metadata.vesting_revoked = true;
        emit_event(
            &mut ifo_metadata.revoked_events,
            RevokedEvent{}
        )
    }

    // ===================== Update Functions =====================
    // It allows the owner to update start and end time of the IFO
    public entry fun update_start_and_end_time<RaisingCoin, OfferingCoin>(admin: &signer, start_time: u64, end_time: u64) acquires IFOMetadata, GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let ifo_metadata = borrow_global_mut<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(timestamp::now_seconds() < ifo_metadata.start_time, ERROR_IFO_STARTED);
        assert!(end_time <= start_time + get_max_buffer_time(), ERROR_TOO_LONG_DURATION);
        assert!(start_time < end_time, ERROR_TIME_ORDER);
        assert!(start_time > timestamp::now_seconds(), ERROR_START_TIME);
        ifo_metadata.start_time = start_time;
        ifo_metadata.end_time = end_time;
        emit_event(
            &mut ifo_metadata.start_and_end_time_set,
            StartAndEndTimeSetEvent{
                start_time,
                end_time
            }
        )
    }

    public entry fun set_admin(admin: &signer, new_admin: address) acquires GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        let global_config = borrow_global_mut<GlobalConfig>(RESOURCE_ACCOUNT);
        global_config.admin = new_admin;
    }

    public entry fun upgrade(admin: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires GlobalConfig {
        assert!(is_admin(admin), ERROR_ONLY_ADMIN);
        let global_config = borrow_global<GlobalConfig>(RESOURCE_ACCOUNT);
        let resource_signer = &account::create_signer_with_capability(&global_config.signer_cap);
        code::publish_package_txn(resource_signer, metadata_serialized, code);
    }

    // ====================== View Functions ======================
    // To see if an IFO exist
    public fun is_ifo_exist<RaisingCoin, OfferingCoin>(): bool {
        exists<IFOMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT)
    }

    // To see if the pool has been set
    public fun is_pool_set<RaisingCoin, OfferingCoin, PoolID>(): bool {
        exists<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT)
    }

    // Get the pool number limit
    public fun get_num_pools(): u64 acquires GlobalConfig {
        borrow_global<GlobalConfig>(RESOURCE_ACCOUNT).num_pools
    }

    // Get the max buffer time
    public fun get_max_buffer_time(): u64 acquires GlobalConfig {
        borrow_global<GlobalConfig>(RESOURCE_ACCOUNT).max_buffer_time
    }

    // To see user information of the pool
    public fun get_user_info_of_pool<RaisingCoin, OfferingCoin, PoolID>(
        user: address
    ): (u64, bool) acquires UserInfo {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        assert!(is_pool_set<RaisingCoin, OfferingCoin, PoolID>(), ERROR_POOL_NOT_SET);
        assert!(exists<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(user), ERROR_USER_NOT_PARTICIPATE);
        
        let user_info = borrow_global<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(user);
        (user_info.amount, user_info.claimed)
    }

    // To see user offering, refunding and tax amount of the pool
    public fun get_user_offering_refund_and_tax_amount<RaisingCoin, OfferingCoin, PoolID>(
        user: address
    ): (u64, u64, u64) acquires IFOPool, UserInfo {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        assert!(is_pool_set<RaisingCoin, OfferingCoin, PoolID>(), ERROR_POOL_NOT_SET);

        let (amount, _) = get_user_info_of_pool<RaisingCoin, OfferingCoin, PoolID>(user);
        let ifo_pool = borrow_global<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        compute_offering_refund_and_tax_amount<RaisingCoin, OfferingCoin, PoolID>(amount, ifo_pool)
    }

    public fun get_vesting_schedule_by_id<RaisingCoin, OfferingCoin>(vesting_schedule_id: vector<u8>): (address, u64, u64, u64) acquires VestingMetadata {
        assert!(is_ifo_exist<RaisingCoin, OfferingCoin>(), ERROR_IFO_NOT_EXIST);
        let schedule = table::borrow(
            &borrow_global<VestingMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT).vesting_schedules,
            vesting_schedule_id
        );
        (
            schedule.beneficiary,
            schedule.pid,
            schedule.amount_total,
            schedule.amount_released
        )
    }

    // ================== Global Config Setting ===================
    public entry fun set_num_pools(sender: &signer, new_num_pools: u64) acquires GlobalConfig {
        assert!(is_admin(sender), ERROR_ONLY_ADMIN);
        let config = borrow_global_mut<GlobalConfig>(RESOURCE_ACCOUNT);
        config.num_pools = new_num_pools;
    }

    public entry fun set_max_buffer_time(sender: &signer, new_max_buffer_time: u64) acquires GlobalConfig {
        assert!(is_admin(sender), ERROR_ONLY_ADMIN);
        let config = borrow_global_mut<GlobalConfig>(RESOURCE_ACCOUNT);
        config.max_buffer_time = new_max_buffer_time;
    }

    // ==================== Internal Functions ====================
    fun is_admin(sender: &signer): bool acquires GlobalConfig {
        let sender_address = signer::address_of(sender);
        let global_config = borrow_global<GlobalConfig>(RESOURCE_ACCOUNT);
        sender_address == global_config.admin
    }

    fun is_same_coin<RaisingCoin, OfferingCoin>(): bool {
        let raising_coin_type_name = type_info::type_name<RaisingCoin>();
        let offering_coin_type_name = type_info::type_name<OfferingCoin>();
        raising_coin_type_name == offering_coin_type_name

    }

    fun handle_deposit<RaisingCoin, OfferingCoin, PoolID>(sender_address: address, amount: u64) acquires IFOPool, UserInfo {
        let ifo_pool = borrow_global_mut<IFOPool<RaisingCoin, OfferingCoin, PoolID>>(RESOURCE_ACCOUNT);
        assert!(ifo_pool.total_coins_offered >= ifo_pool.offering_amount, ERROR_POOL_NOT_SET);

        let user_info = borrow_global_mut<UserInfo<RaisingCoin, OfferingCoin, PoolID>>(sender_address);
        user_info.amount = user_info.amount + amount;

        if (ifo_pool.limit_per_user > 0) {
            assert!(user_info.amount <= ifo_pool.limit_per_user, ERROR_EXCEED_LIMIT);
        };
        ifo_pool.total_amount = ifo_pool.total_amount + amount;

        emit_event<DepositEvent>(
            &mut ifo_pool.deposit_events,
            DepositEvent{
                user: sender_address,
                amount,
                pid: uints::get_number<PoolID>(),
            }
        )
    }

    fun create_vesting_schedule<RaisingCoin, OfferingCoin, PoolID>(
        beneficiary: address,
        amount: u64,
        balance: u64
    ) acquires VestingMetadata {
        let vesting_schedule_id = compute_next_vesting_schedule_id_for_holder<RaisingCoin, OfferingCoin>(beneficiary);
        let vesting_metadata = borrow_global_mut<VestingMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        assert!(balance >= vesting_metadata.vesting_total_amount + amount, ERROR_INSUFFCIENT_OFFERING_COIN);
        assert!(!table::contains(&vesting_metadata.vesting_schedules, vesting_schedule_id), ERROR_EXISTING_VESTING_ID);

        table::add(
            &mut vesting_metadata.vesting_schedules,
            vesting_schedule_id,
            VestingSchedule{
                beneficiary,
                pid: uints::get_number<PoolID>(),
                amount_total: amount,
                amount_released: 0
            },
        );
        vesting_metadata.vesting_total_amount = vesting_metadata.vesting_total_amount + amount;
        vector::push_back(&mut vesting_metadata.vesting_schedule_ids, vesting_schedule_id);

        let vesting_count = table::borrow_mut<address, u64>(&mut vesting_metadata.holders_vesting_count, beneficiary);
        *vesting_count = *vesting_count + 1;
    }

    fun compute_offering_refund_and_tax_amount<RaisingCoin, OfferingCoin, PoolID>(
        amount: u64,
        ifo_pool: &IFOPool<RaisingCoin, OfferingCoin, PoolID>,
    ): (u64, u64, u64) {
        let offering_amount: u64;
        let refunding_amount: u64;
        let tax_amount: u64 = 0;

        if (ifo_pool.total_amount > ifo_pool.raising_amount) {
            let allocation = IFO_utils::get_user_allocation(ifo_pool.total_amount, amount);

            offering_amount = (((ifo_pool.offering_amount as u128) * allocation/1000000000000) as u64);
            let payment = (((ifo_pool.raising_amount as u128) * allocation/1000000000000) as u64);
            refunding_amount = amount - payment;
            if (ifo_pool.has_tax) {
                let tax_overflow = IFO_utils::calculate_tax_overflow(ifo_pool.total_amount, ifo_pool.raising_amount);

                tax_amount = (((refunding_amount as u128) * tax_overflow/1000000000000) as u64);
                refunding_amount = refunding_amount - tax_amount;
            };
        } else {
            refunding_amount = 0;
            offering_amount = ((amount as u128) * (ifo_pool.offering_amount as u128) / (ifo_pool.raising_amount as u128) as u64);
        };

        (offering_amount, refunding_amount, tax_amount)
    }

    fun compute_release_amount<RaisingCoin, OfferingCoin, PoolID>(
        ifo_metadata: &mut IFOMetadata<RaisingCoin, OfferingCoin>,
        ifo_pool: &mut IFOPool<RaisingCoin, OfferingCoin, PoolID>,
        vesting_schedule: &VestingSchedule
    ): u64 {
        let current_time = timestamp::now_seconds();
        if (current_time < ifo_metadata.vesting_start_time + ifo_pool.vesting_cliff) {
            0
        } else if (
            current_time >= ifo_metadata.vesting_start_time + ifo_pool.vesting_duration ||
            ifo_metadata.vesting_revoked
        ) {
            vesting_schedule.amount_total - vesting_schedule.amount_released
        } else {
            let time_since_start = current_time - ifo_metadata.vesting_start_time;
            let seconds_per_slice = ifo_pool.vesting_slice_period_seconds;
            let vested_slice_periods = time_since_start / seconds_per_slice;
            let vested_seconds = vested_slice_periods * seconds_per_slice;
            let vested_amount = ((vesting_schedule.amount_total as u128) * (vested_seconds as u128) / (ifo_pool.vesting_duration as u128) as u64);
            vested_amount = vested_amount - vesting_schedule.amount_released;

            vested_amount
        }
    }

    fun compute_next_vesting_schedule_id_for_holder<RaisingCoin, OfferingCoin>(
        holder: address
    ): vector<u8> acquires VestingMetadata {
        let vesting_metadata = borrow_global_mut<VestingMetadata<RaisingCoin, OfferingCoin>>(RESOURCE_ACCOUNT);
        let vesting_count = {
            if (!table::contains(&vesting_metadata.holders_vesting_count, holder)) {
                table::add(&mut vesting_metadata.holders_vesting_count, holder, 0);
            };
            table::borrow<address, u64>(&vesting_metadata.holders_vesting_count, holder)
        };

        IFO_utils::compute_vesting_schedule_id(holder, *vesting_count)
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}