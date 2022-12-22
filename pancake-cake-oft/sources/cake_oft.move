module pancake_oft::oft {
    use std::vector;
    use std::signer;
    use aptos_std::event;
    use aptos_std::from_bcs;
    use aptos_std::type_info::TypeInfo;
    use aptos_std::table::{Self, Table};
    use aptos_framework::code;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;
    use layerzero::lzapp;
    use layerzero::remote;
    use layerzero_apps::oft;
    use layerzero_common::serde;
    use layerzero_common::utils::vector_slice;
    use layerzero::endpoint::{Self, UaCapability};

    const ERROR_NOT_ADMIN: u64 = 0;
    const ERROR_ZERO_ACCOUNT: u64 = 1;

    const DEFAULT_BRIDGE_CAP: u64 = 5000000 * 100000000;

    struct CakeOFT {}

    struct OFT has key {
        admin: address,
        paused: bool,
        signer_cap: account::SignerCapability,
        white_list: Table<address, bool>
    }

    struct Capabilities has key {
        lz_cap: UaCapability<CakeOFT>,
    }

    struct OFTCap has key {
        hard_cap: Table<u64, u64>,
        used: Table<u64, u64>,
        last_timestamp: Table<u64, u64>,
    }

    struct EventStore has key {
        non_blocking_events: event::EventHandle<NonBlockingEvent>
    }

    struct NonBlockingEvent has drop, store {
        src_chain_id: u64,
        src_address: vector<u8>,
        receiver: address,
        amount: u64
    }

    fun init_module(account: &signer) {
        let lz_cap = oft::init_oft<CakeOFT>(account, b"PancakeSwap Token", b"Cake", 8, 8);
        let signer_cap = resource_account::retrieve_resource_account_cap(account, @pancake_oft_origin);

        move_to(account, Capabilities {
            lz_cap,
        });

        move_to(account, OFT {
            admin: @pancake_oft_admin,
            paused: false,
            signer_cap,
            white_list: table::new<address, bool>()
        });

        move_to(account, OFTCap {
            hard_cap: table::new<u64, u64>(),
            used: table::new<u64, u64>(),
            last_timestamp: table::new<u64, u64>()
        });

        move_to(account, EventStore {
            non_blocking_events: account::new_event_handle<NonBlockingEvent>(account)
        });
    }

    public entry fun lz_receive(src_chain_id: u64, src_address: vector<u8>, payload: vector<u8>) acquires OFT, OFTCap, Capabilities, EventStore {
        let (receiver, amount) = decode_send_payload(&payload);
        let oft = borrow_global<OFT>(@pancake_oft);

        if (oft.paused) {
            non_blocking_lz_receive(src_chain_id, src_address, payload, receiver, amount);
            return
        };

        if (!table::contains<address, bool>(&oft.white_list, receiver)) {
            let cap = borrow_global_mut<OFTCap>(@pancake_oft);
            let today = now_days();
            let last_day = table::borrow_mut_with_default(&mut cap.last_timestamp, src_chain_id, 0);
            let used = table::borrow_mut_with_default(&mut cap.used, src_chain_id, 0);

            if (today > *last_day) {
                *used = 0;
                table::upsert(&mut cap.last_timestamp, src_chain_id, today);
            };

            let hard_cap = table::borrow_mut_with_default(&mut cap.hard_cap, src_chain_id, DEFAULT_BRIDGE_CAP);
            if (*used + amount > *hard_cap) {
                non_blocking_lz_receive(src_chain_id, src_address, payload, receiver, amount);
                return
            };
            *used = *used + amount;
        };
        oft::lz_receive<CakeOFT>(src_chain_id, src_address, payload)
    }

    public fun lz_receive_types(_src_chain_id: u64, _src_address: vector<u8>, _payload: vector<u8>): vector<TypeInfo> {
        vector::empty<TypeInfo>()
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Admin functions
    ///////////////////////////////////////////////////////////////////////////

    public entry fun set_hard_cap(sender: &signer, chain_id: u64, cap: u64) acquires OFT, OFTCap {
        assert_admin(signer::address_of(sender));
        table::upsert(&mut borrow_global_mut<OFTCap>(@pancake_oft).hard_cap, chain_id, cap);
    }

    public entry fun whitelist(sender: &signer, addr: address, enable: bool) acquires OFT {
        assert_admin(signer::address_of(sender));
        let white_list = &mut borrow_global_mut<OFT>(@pancake_oft).white_list;
        let exist = table::contains<address, bool>(white_list, addr);

        if (exist && !enable) {
            table::remove<address, bool>(white_list, addr);
        } else if (!exist && enable) {
            table::add<address, bool>(white_list, addr, true);
        } else {
            return
        }
    }

    public entry fun pause(sender: &signer, paused: bool) acquires OFT {
        assert_admin(signer::address_of(sender));
        borrow_global_mut<OFT>(@pancake_oft).paused = paused;
    }

    public entry fun transfer_admin(sender: &signer, new_admin: address) acquires OFT {
        assert!(new_admin != @0x0, ERROR_ZERO_ACCOUNT);
        let oft = borrow_global_mut<OFT>(@pancake_oft);
        assert!(signer::address_of(sender) == oft.admin, ERROR_NOT_ADMIN);
        oft.admin = new_admin;
    }

    // sender: admin account
    // chain_id: trusted remote chain id
    // remote_addr: trusted contract address
    public entry fun set_trust_remote(sender: &signer, chain_id: u64, remote_addr: vector<u8>) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        remote::set(&resource, chain_id, remote_addr);
    }

    public entry fun set_default_fee(sender: &signer, fee_bp: u64) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        oft::set_default_fee<CakeOFT>(&resource, fee_bp)
    }

    public entry fun set_fee(
        sender: &signer,
        dst_chain_id: u64,
        enabled: bool,
        fee_bp: u64
    ) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        oft::set_fee<CakeOFT>(&resource, dst_chain_id, enabled, fee_bp)
    }

    public entry fun set_fee_owner(sender: &signer, new_owner: address) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        oft::set_fee_owner<CakeOFT>(&resource, new_owner)
    }

    public entry fun enable_custom_adapter_params(sender: &signer, enabled: bool) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        oft::enable_custom_adapter_params<CakeOFT>(&resource, enabled);
    }

    public entry fun set_min_dst_gas(sender: &signer, chain_id: u64, pk_type: u64, min_dst_gas: u64) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        lzapp::set_min_dst_gas<CakeOFT>(&resource, chain_id, pk_type, min_dst_gas);
    }

    public entry fun set_config(
        sender: &signer,
        major_version: u64,
        minor_version: u8,
        chain_id: u64,
        config_type: u8,
        config_bytes: vector<u8>,
    ) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        lzapp::set_config<CakeOFT>(&resource, major_version, minor_version, chain_id, config_type, config_bytes)
    }

    public entry fun set_send_msglib(sender: &signer, chain_id: u64, major: u64, minor: u8) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        lzapp::set_send_msglib<CakeOFT>(&resource, chain_id, major, minor)
    }

    public entry fun set_receive_msglib(sender: &signer, chain_id: u64, major: u64, minor: u8) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        lzapp::set_receive_msglib<CakeOFT>(&resource, chain_id, major, minor)
    }

    public entry fun set_executor(sender: &signer, chain_id: u64, version: u64, executor: address) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        lzapp::set_executor<CakeOFT>(&resource, chain_id, version, executor)
    }

    public entry fun upgrade_oft(sender: &signer, metadata_serialized: vector<u8>,code: vector<vector<u8>>) acquires OFT {
        assert_admin(signer::address_of(sender));
        let resource = account::create_signer_with_capability(&borrow_global<OFT>(@pancake_oft).signer_cap);
        code::publish_package_txn(&resource, metadata_serialized, code);
    }

    // non-blocking, drop the payload
    fun non_blocking_lz_receive(src_chain_id: u64, src_address: vector<u8>, payload: vector<u8>, receiver: address, amount: u64) acquires Capabilities, EventStore {
        endpoint::lz_receive(src_chain_id, src_address, payload, &borrow_global<Capabilities>(@pancake_oft).lz_cap);
        let event_store = borrow_global_mut<EventStore>(@pancake_oft);
        event::emit_event<NonBlockingEvent>(&mut event_store.non_blocking_events, NonBlockingEvent {src_chain_id, src_address, receiver, amount});
    }

    fun decode_send_payload(payload: &vector<u8>): (address, u64) {
        let receiver_bytes = vector_slice(payload, 1, 33);
        let receiver = from_bcs::to_address(receiver_bytes);
        let amount_sd = serde::deserialize_u64(&vector_slice(payload, 33, 41));
        (receiver, amount_sd)
    }

    fun now_days(): u64 {
        let day_seconds = 86400; // 60 * 60 * 24;
        timestamp::now_seconds() / day_seconds
    }

    fun assert_admin(account: address) acquires OFT {
        assert!(account == borrow_global_mut<OFT>(@pancake_oft).admin, ERROR_NOT_ADMIN);
    }

    #[test_only]
    use std::signer::address_of;
    #[test_only]
    use layerzero::test_helpers;
    #[test_only]
    use std::bcs;
    #[test_only]
    use layerzero_common::packet;
    #[test_only]
    use aptos_framework::timestamp::fast_forward_seconds;

    #[test(
        aptos = @aptos_framework,
        core_resources = @core_resources,
        layerzero = @layerzero,
        msglib_auth = @msglib_auth,
        oracle = @1234,
        relayer = @5678,
        executor = @1357,
        executor_auth = @executor_auth,
        oft = @pancake_oft,
        oft_origin = @pancake_oft_origin,
        oft_admin = @pancake_oft_admin,
        alice = @0xABCD,
        bob = @0xAABB
    )]
    fun test_send_and_receive_oft(
        aptos: &signer,
        core_resources: &signer,
        layerzero: &signer,
        msglib_auth: &signer,
        oracle: &signer,
        relayer: &signer,
        executor: &signer,
        executor_auth: &signer,
        oft: &signer,
        oft_origin: &signer,
        oft_admin: &signer,
        alice: &signer,
        bob: &signer
    ) acquires OFT, OFTCap, Capabilities, EventStore {
        oft::setup(
            aptos,
            core_resources,
            &vector[
                address_of(layerzero),
                address_of(msglib_auth),
                address_of(oracle),
                address_of(relayer),
                address_of(executor),
                address_of(executor_auth),
                address_of(oft),
                address_of(alice),
                address_of(bob),
            ],
        );

         // prepare the endpoint
        let local_chain_id: u64 = 20030;
        let remote_chain_id: u64 = 20030;
        test_helpers::setup_layerzero_for_test(
            layerzero,
            msglib_auth,
            oracle,
            relayer,
            executor,
            executor_auth,
            local_chain_id,
            remote_chain_id
        );

        // user address
        let (alice_addr, bob_addr) = (address_of(alice), address_of(bob));
        let (_alice_addr_bytes, bob_addr_bytes) = (bcs::to_bytes(&alice_addr), bcs::to_bytes(&bob_addr));

        resource_account::create_resource_account(oft_origin, b"pancake-oft", x"your-authen-key");
        // init oft
        initialize(oft);

        // config oft
        let (local_oft_addr, remote_oft_addr) = (@pancake_oft, @pancake_oft);
        let (local_oft_addr_bytes, remote_oft_addr_bytes) = (bcs::to_bytes(&local_oft_addr), bcs::to_bytes(
            &remote_oft_addr
        ));
        remote::set(oft, remote_chain_id, remote_oft_addr_bytes);

        // set hard_cap
        let hard_cap = 1000;
        set_hard_cap(oft_admin, local_chain_id, hard_cap);

        // tx1: mock packet for send oft to bob: remote chain -> local chain
        let nonce = 1;
        let amount1 = 100;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount1);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);

        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1, 0);

        // tx2: total amount should exceed hard_cap, the tx should be droped
        nonce = 2;
        let amount2 = hard_cap - amount1 + 1;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount2);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);
        // payload should be droped
        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1, 0);

        // tx3: total amount will below hard_cap
        nonce = 3;
        let amount3 = 3;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount3);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);

        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1 + amount3, 0);

        // enable bob to whitelist
        whitelist(oft_admin, bob_addr, true);

        // tx4: bob in whitelist, so the tx4 amount will not be added to total used cap
        nonce = 4;
        let amount4 = 4;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount4);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);

        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1 + amount3, 0);

        // disable bob from whitelist
        whitelist(oft_admin, bob_addr, false);

        // tx5: bob removed from whitelist, so the tx5 amount will be added to total used cap
        nonce = 5;
        let amount5 = 5;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount5);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);

        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1 + amount3 + amount5, 0);

        // pause OFT bridge
        pause(oft_admin, true);

        // tx6: all incoming tx will be droped
        nonce = 6;
        let amount6 = 6;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount6);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);
        // payload should be droped
        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1 + amount3 + amount5, 0);

        // unpause OFT bridge
        pause(oft_admin, false);

        // tx7
        nonce = 7;
        let amount7 = 7;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount7);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);
        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == amount1 + amount3 + amount5 + amount7, 0);

        // move to next day
        fast_forward_seconds(60 * 60 * 24);

        // tx8: used cap reset to 0
        nonce = 8;
        let amount8 = hard_cap;
        let payload = oft::encode_send_payload_for_testing(bob_addr_bytes, amount8);
        let emitted_packet = packet::new_packet(
            remote_chain_id,
            remote_oft_addr_bytes,
            local_chain_id,
            local_oft_addr_bytes,
            nonce,
            payload
        );
        test_helpers::deliver_packet<CakeOFT>(oracle, relayer, emitted_packet, 20);
        lz_receive(local_chain_id, local_oft_addr_bytes, payload);
        assert!(get_used_cap(local_chain_id) == hard_cap, 0);
    }

    #[test_only]
    public fun get_used_cap(src_chain_id: u64): u64 acquires OFTCap {
        let cap = borrow_global_mut<OFTCap>(@pancake_oft);
        *table::borrow_mut_with_default(&mut cap.used, src_chain_id, 0)
    }

    #[test_only]
    public fun initialize(account: &signer) {
       init_module(account);
    }
}
