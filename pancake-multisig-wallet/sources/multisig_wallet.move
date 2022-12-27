module pancake_multisig_wallet::multisig_wallet {
    use std::signer;
    use std::vector;
    use std::string;
    use aptos_std::table_with_length as Table;
    use aptos_std::type_info;
    use aptos_std::event;

    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;

    const ERROR_NOT_RESOURCE_ACCOUNT: u64 = 0;
    const ERROR_NOT_OWNER: u64 = 1;
    const ERROR_LESS_THAN_THRESHOLD: u64 = 2;
    const ERROR_ALREADY_EXECUTED: u64 = 3;
    const ERROR_ALREADY_APPROVED: u64 = 4;
    const ERROR_OWNERS_SEQ_NUMBER_NOT_MATCH: u64 = 6;
    const ERROR_MORE_THAN_NUM_OWNERS: u64 = 7;
    const ERROR_LESS_THAN_MIN_THRESHOLD: u64 = 8;
    const ERROR_OWNER_NOT_EXIST: u64 = 9;
    const ERROR_OWNER_ALREADY_EXIST: u64 = 10;
    const ERROR_TIMELOCK_NOT_SURPASSED: u64 = 11;
    const ERROR_MULTISIG_TX_EXPIRED: u64 = 12;
    const ERROR_MULTISIG_TX_INVALIDATED: u64 = 13;
    const ERROR_INVALID_EXPIRATION: u64 = 14;

    const MAX_U64: u64 = 18446744073709551615;
    const MIN_THRESHOLD: u8 = 2;

    struct MultisigWallet has key {
        // If an address is present in the table, whether its corresponding value is true or false, it has the owner privilege. That is, we are using table as set here.
        owners: Table::TableWithLength<address, bool>,
        // Since there is no way to get all keys from a table, we store all owners' addresses in a
        // separate vector
        owners_keys: vector<address>,
        threshold: u8,
        seq_number_to_params_type_name: Table::TableWithLength<u64, string::String>,
        // Enforce multisig transactions to be executed in order
        last_executed_seq_number: u64,
        // Sequence number for owners, incremented only when there is a change on the owners so
        // that all the multisig transactions can be invalidated after the change
        owners_seq_number: u64,
    }

    struct MultisigTxs<ParamsType: copy> has key {
        // sequence number => multisig tx
        txs: Table::TableWithLength<u64, MultisigTx<ParamsType>>,
    }

    struct MultisigTx<ParamsType: copy> has store {
        params: ParamsType,
        // If an owner address is present in the table, whether its corresponding value is true or false, the tx is approved by the owner. That is, we are using table as set here.
        approvals: Table::TableWithLength<address, bool>,
        // Since there is no way to get all keys from a table, we store all approvers' addresses in
        // a separate vector
        approvals_keys: vector<address>,
        is_executed: bool,
        eta: u64, // timestamp in seconds, the tx can only be executed after this time
        expiration: u64, // timestamp in seconds, the tx will be automatically invalidated after this time
        owners_seq_number: u64,
    }

    struct AddOwnerParams has copy, store {
        owner: address,
    }

    struct RemoveOwnerParams has copy, store {
        owner: address,
    }

    struct SetThresholdParams has copy, store {
        threshold: u8,
    }

    struct WithdrawParams<phantom CoinType> has copy, store {
        amount: u64,
        to: address,
    }

    struct MultisigWalletEvents has key {
        init_multisig_tx_events: event::EventHandle<InitMultisigTxEvent>,
        approve_multisig_tx_events: event::EventHandle<ApproveMultisigTxEvent>,
        execute_multisig_tx_events: event::EventHandle<ExecuteMultisigTxEvent>,
    }

    struct InitMultisigTxEvent has drop, store {
        sender: address,
        seq_number: u64,
    }

    struct ApproveMultisigTxEvent has drop, store {
        sender: address,
        seq_number: u64,
    }

    struct ExecuteMultisigTxEvent has drop, store {
        sender: address,
        seq_number: u64,
    }

    fun init_module(sender: &signer) {
        // Make this module impossible to upgrade
        let _signer_cap = resource_account::retrieve_resource_account_cap(sender, @pancake_multisig_wallet_dev);
    }

    public fun initialize(sender: &signer, owner_addresses: vector<address>, threshold: u8) {
        let num_owners = vector::length(&owner_addresses);
        assert!(threshold >= MIN_THRESHOLD, ERROR_LESS_THAN_MIN_THRESHOLD);
        assert!((threshold as u64) <= num_owners, ERROR_MORE_THAN_NUM_OWNERS);

        let idx = 0;
        let owners_set = Table::new<address, bool>();
        while (idx < num_owners) {
            let owner = *(vector::borrow(&owner_addresses, idx));
            Table::add(&mut owners_set, owner, true);
            idx = idx + 1;
        };
        let seq_number_to_params_type_name = Table::new<u64, string::String>();
        move_to(sender, MultisigWallet {
            owners: owners_set,
            owners_keys: owner_addresses,
            threshold,
            seq_number_to_params_type_name,
            // We could not set this to -1, so we use MAX_U64 here. Therefore, the sequence number
            // cannot be MAX_U64, yet I doubt it will ever be reached.
            last_executed_seq_number: MAX_U64,
            owners_seq_number: 0,
        });

        register_multisig_txs<AddOwnerParams>(sender);
        register_multisig_txs<RemoveOwnerParams>(sender);
        register_multisig_txs<SetThresholdParams>(sender);

        move_to(sender, MultisigWalletEvents {
            init_multisig_tx_events: account::new_event_handle<InitMultisigTxEvent>(sender),
            approve_multisig_tx_events: account::new_event_handle<ApproveMultisigTxEvent>(sender),
            execute_multisig_tx_events: account::new_event_handle<ExecuteMultisigTxEvent>(sender),
        });
    }

    public fun is_owner(multisig_wallet_addr: address, addr: address): bool acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        Table::contains(&multisig_wallet.owners, addr)
    }

    public fun num_owners(multisig_wallet_addr: address): u64 acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        Table::length(&multisig_wallet.owners)
    }

    public fun owner(multisig_wallet_addr: address, idx: u64): address acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        *vector::borrow(&multisig_wallet.owners_keys, idx)
    }

    public fun owners_seq_number(multisig_wallet_addr: address): u64 acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        multisig_wallet.owners_seq_number
    }

    public fun threshold(multisig_wallet_addr: address): u8 acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        multisig_wallet.threshold
    }

    public fun next_seq_number(multisig_wallet_addr: address): u64 acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        Table::length(&multisig_wallet.seq_number_to_params_type_name)
    }

    public fun last_executed_seq_number(multisig_wallet_addr: address): u64 acquires MultisigWallet {
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        multisig_wallet.last_executed_seq_number
    }

    public fun multisig_tx_params<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64): ParamsType acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        tx.params
    }

    public fun is_multisig_tx_approved_by<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64, addr: address): bool acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        Table::contains(&tx.approvals, addr)
    }

    public fun num_multisig_tx_approvals<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64): u64 acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        Table::length(&tx.approvals)
    }

    public fun multisig_tx_approver<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64, idx: u64): address acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        *vector::borrow(&tx.approvals_keys, idx)
    }

    public fun is_multisig_tx_executed<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64): bool acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        tx.is_executed
    }

    public fun multisig_tx_owners_seq_number<ParamsType: copy + store>(multisig_wallet_addr: address, seq_number: u64): u64 acquires MultisigTxs {
        let multisig_txs = borrow_global<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        tx.owners_seq_number
    }

    public fun is_multisig_txs_registered<ParamsType: copy + store>(multisig_wallet_addr: address): bool {
        exists<MultisigTxs<ParamsType>>(multisig_wallet_addr)
    }

    public fun register_multisig_txs<ParamsType: copy + store>(sender: &signer) {
        move_to(sender, MultisigTxs<ParamsType> {
            txs: Table::new<u64, MultisigTx<ParamsType>>(),
        });
    }

    public fun init_add_owner(sender: &signer, multisig_wallet_signer: &signer, eta: u64, expiration: u64, owner: address) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(!Table::contains(&multisig_wallet.owners, owner), ERROR_OWNER_ALREADY_EXIST);
        init_multisig_tx<AddOwnerParams>(sender, multisig_wallet_signer, eta, expiration, AddOwnerParams {
            owner,
        });
    }

    public fun init_remove_owner(sender: &signer, multisig_wallet_signer: &signer, eta: u64, expiration: u64, owner: address) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(Table::contains(&multisig_wallet.owners, owner), ERROR_OWNER_NOT_EXIST);
        assert!(Table::length(&multisig_wallet.owners) - 1 >= (multisig_wallet.threshold as u64), ERROR_LESS_THAN_THRESHOLD);
        init_multisig_tx<RemoveOwnerParams>(sender, multisig_wallet_signer, eta, expiration, RemoveOwnerParams {
            owner,
        });
    }

    public fun init_set_threshold(sender: &signer, multisig_wallet_signer: &signer, eta: u64, expiration: u64, threshold: u8) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!((threshold as u64) <= Table::length(&multisig_wallet.owners), ERROR_MORE_THAN_NUM_OWNERS);
        assert!(threshold >= MIN_THRESHOLD, ERROR_LESS_THAN_MIN_THRESHOLD);
        init_multisig_tx<SetThresholdParams>(sender, multisig_wallet_signer, eta, expiration, SetThresholdParams {
            threshold,
        });
    }

    public fun init_withdraw<CoinType>(sender: &signer, multisig_wallet_signer: &signer, eta: u64, expiration: u64, to: address, amount: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        init_multisig_tx<WithdrawParams<CoinType>>(sender, multisig_wallet_signer, eta, expiration, WithdrawParams<CoinType> {
            amount,
            to,
        });
    }

    public fun init_multisig_tx<ParamsType: copy + store>(sender: &signer, multisig_wallet_signer: &signer, eta: u64, expiration: u64, params: ParamsType) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        assert!(eta < expiration , ERROR_INVALID_EXPIRATION);

        let sender_addr = signer::address_of(sender);
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global_mut<MultisigWallet>(multisig_wallet_addr);
        assert!(Table::contains(&multisig_wallet.owners, sender_addr) , ERROR_NOT_OWNER);

        let multisig_txs = borrow_global_mut<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let approvals = Table::new<address, bool>();
        Table::add(&mut approvals, sender_addr, true);
        let tx = MultisigTx<ParamsType> {
            params,
            approvals,
            approvals_keys: vector[sender_addr],
            is_executed: false,
            eta,
            expiration,
            owners_seq_number: multisig_wallet.owners_seq_number,
        };
        let seq_number = Table::length(&multisig_wallet.seq_number_to_params_type_name);
        Table::add(&mut multisig_txs.txs, seq_number, tx);
        Table::add(&mut multisig_wallet.seq_number_to_params_type_name, seq_number, type_info::type_name<ParamsType>());

        let events = borrow_global_mut<MultisigWalletEvents>(multisig_wallet_addr);
        event::emit_event<InitMultisigTxEvent>(
            &mut events.init_multisig_tx_events,
            InitMultisigTxEvent {
                sender: sender_addr,
                seq_number,
            }
        );
    }

    public fun approve_add_owner(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        approve_multisig_tx<AddOwnerParams>(sender, multisig_wallet_signer, seq_number);
    }

    public fun approve_remove_owner(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        approve_multisig_tx<RemoveOwnerParams>(sender, multisig_wallet_signer, seq_number);
    }

    public fun approve_set_threshold(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        approve_multisig_tx<SetThresholdParams>(sender, multisig_wallet_signer, seq_number);
    }

    public fun approve_withdraw<CoinType>(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        approve_multisig_tx<WithdrawParams<CoinType>>(sender, multisig_wallet_signer, seq_number);
    }

    public fun approve_multisig_tx<ParamsType: copy + store>(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        let sender_addr = signer::address_of(sender);
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(Table::contains(&multisig_wallet.owners, sender_addr) , ERROR_NOT_OWNER);

        let multisig_txs = borrow_global_mut<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow_mut(&mut multisig_txs.txs, seq_number);
        assert!(!tx.is_executed, ERROR_ALREADY_EXECUTED);
        assert!(!Table::contains(&tx.approvals, sender_addr), ERROR_ALREADY_APPROVED);
        Table::add(&mut tx.approvals, sender_addr, true);
        vector::push_back(&mut tx.approvals_keys, sender_addr);

        let events = borrow_global_mut<MultisigWalletEvents>(multisig_wallet_addr);
        event::emit_event<ApproveMultisigTxEvent>(
            &mut events.approve_multisig_tx_events,
            ApproveMultisigTxEvent {
                sender: sender_addr,
                seq_number,
            }
        );
    }

    public fun execute_add_owner(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        execute_multisig_tx<AddOwnerParams>(sender, multisig_wallet_signer, seq_number);

        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_txs = borrow_global<MultisigTxs<AddOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        let multisig_wallet = borrow_global_mut<MultisigWallet>(multisig_wallet_addr);
        Table::add(&mut multisig_wallet.owners, tx.params.owner, true);
        vector::push_back(&mut multisig_wallet.owners_keys, tx.params.owner);
    }

    public fun execute_remove_owner(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        execute_multisig_tx<RemoveOwnerParams>(sender, multisig_wallet_signer, seq_number);

        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_txs = borrow_global<MultisigTxs<RemoveOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        let multisig_wallet = borrow_global_mut<MultisigWallet>(multisig_wallet_addr);
        Table::remove(&mut multisig_wallet.owners, tx.params.owner);
        let (is_found, idx_to_remove) = vector::index_of(&multisig_wallet.owners_keys, &tx.params.owner);
        assert!(is_found, ERROR_OWNER_NOT_EXIST);
        vector::swap_remove(&mut multisig_wallet.owners_keys, idx_to_remove);
    }

    public fun execute_set_threshold(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        execute_multisig_tx<SetThresholdParams>(sender, multisig_wallet_signer, seq_number);

        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_txs = borrow_global<MultisigTxs<SetThresholdParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        let multisig_wallet = borrow_global_mut<MultisigWallet>(multisig_wallet_addr);
        multisig_wallet.threshold = tx.params.threshold;
    }

    public fun execute_withdraw<CoinType>(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        execute_multisig_tx<WithdrawParams<CoinType>>(sender, multisig_wallet_signer, seq_number);

        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_txs = borrow_global<MultisigTxs<WithdrawParams<CoinType>>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        coin::transfer<CoinType>(multisig_wallet_signer, tx.params.to, tx.params.amount);
    }

    public fun execute_multisig_tx<ParamsType: copy + store>(sender: &signer, multisig_wallet_signer: &signer, seq_number: u64) acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        let sender_addr = signer::address_of(sender);
        let multisig_wallet_addr = signer::address_of(multisig_wallet_signer);
        let multisig_wallet = borrow_global_mut<MultisigWallet>(multisig_wallet_addr);
        assert!(Table::contains(&multisig_wallet.owners, sender_addr), ERROR_NOT_OWNER);
        assert!(multisig_wallet.last_executed_seq_number == MAX_U64 || seq_number > multisig_wallet.last_executed_seq_number, ERROR_MULTISIG_TX_INVALIDATED);

        let multisig_txs = borrow_global_mut<MultisigTxs<ParamsType>>(multisig_wallet_addr);
        let tx = Table::borrow_mut(&mut multisig_txs.txs, seq_number);
        assert!(Table::length(&tx.approvals) >= (multisig_wallet.threshold as u64), ERROR_LESS_THAN_THRESHOLD);
        assert!(tx.owners_seq_number == multisig_wallet.owners_seq_number, ERROR_OWNERS_SEQ_NUMBER_NOT_MATCH);
        tx.is_executed = true;
        multisig_wallet.last_executed_seq_number = seq_number;

        assert!(timestamp::now_seconds() >= tx.eta, ERROR_TIMELOCK_NOT_SURPASSED);
        assert!(timestamp::now_seconds() < tx.expiration, ERROR_MULTISIG_TX_EXPIRED);

        if (
            type_info::type_name<ParamsType>() == type_info::type_name<RemoveOwnerParams>()
            || type_info::type_name<ParamsType>() == type_info::type_name<AddOwnerParams>()
            || type_info::type_name<ParamsType>() == type_info::type_name<SetThresholdParams>()
        ) {
            multisig_wallet.owners_seq_number = multisig_wallet.owners_seq_number + 1;
        };

        let events = borrow_global_mut<MultisigWalletEvents>(multisig_wallet_addr);
        event::emit_event<ExecuteMultisigTxEvent>(
            &mut events.execute_multisig_tx_events,
            ExecuteMultisigTxEvent {
                sender: sender_addr,
                seq_number,
            }
        );
    }

    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::managed_coin;

    #[test_only]
    const MINUTE_IN_SECONDS: u64 = 60;
    #[test_only]
    const HOUR_IN_SECONDS: u64 = 60 * 60;
    #[test_only]
    const DAY_IN_SECONDS: u64 = 24 * 60 * 60;

    #[test_only]
    struct TestCAKE {
    }

    #[test_only]
    public fun init_module_for_test(sender: &signer) {
        init_module(sender);
    }

    #[test(
        sender = @0x12345,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun init_add_owner_not_owner(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        init_add_owner(&sender, &multisig_wallet, eta, expiration, new_owner_addr);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 10)]
    fun init_add_owner_already_exist(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @multisig_wallet_owner1;

        init_add_owner(&sender, &multisig_wallet, eta, expiration, new_owner_addr);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun init_add_owner_successfully(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&sender, &multisig_wallet, eta, expiration, new_owner_addr);

        let multisig_txs = borrow_global<MultisigTxs<AddOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.params.owner == new_owner_addr, 0);
        assert!(Table::contains(&tx.approvals, sender_addr), 0);
        assert!(Table::length(&tx.approvals) == 1, 0);
        assert!(!tx.is_executed, 0);
    }

    #[test(
        sender = @0x12345,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun init_remove_owner_not_owner(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;

        init_remove_owner(&sender, &multisig_wallet, eta, expiration, owner_addr_to_remove);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 9)]
    fun init_remove_owner_not_exist(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @0x12345;

        init_remove_owner(&sender, &multisig_wallet, eta, expiration, owner_addr_to_remove);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        executor = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 2)]
    fun init_remove_owner_less_than_threshold(
        sender: signer,
        executor: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&initiator, &multisig_wallet, eta, expiration, owner_addr_to_remove);
        approve_remove_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_remove_owner(&executor, &multisig_wallet, seq_number);
        init_remove_owner(&sender, &multisig_wallet, eta, expiration, @multisig_wallet_owner2);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun init_remove_owner_successfully(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&sender, &multisig_wallet, eta, expiration, owner_addr_to_remove);

        let multisig_txs = borrow_global<MultisigTxs<RemoveOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.params.owner == owner_addr_to_remove, 0);
        assert!(Table::contains(&tx.approvals, sender_addr), 0);
        assert!(Table::length(&tx.approvals) == 1, 0);
        assert!(!tx.is_executed, 0);
    }

    #[test(
        sender = @0x12345,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun init_set_threshold_not_owner(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_threshold = 3;

        init_set_threshold(&sender, &multisig_wallet, eta, expiration, new_threshold);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 7)]
    fun init_set_threshold_more_than_num_owners(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_threshold = 4;

        init_set_threshold(&sender, &multisig_wallet, eta, expiration, new_threshold);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 8)]
    fun init_set_threshold_less_than_min_threshold(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_threshold = 0;

        init_set_threshold(&sender, &multisig_wallet, eta, expiration, new_threshold);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun init_set_threshold_successfully(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_threshold = 3;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_set_threshold(&sender, &multisig_wallet, eta, expiration, new_threshold);

        let multisig_txs = borrow_global<MultisigTxs<SetThresholdParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.params.threshold == new_threshold, 0);
        assert!(Table::contains(&tx.approvals, sender_addr), 0);
        assert!(Table::length(&tx.approvals) == 1, 0);
        assert!(!tx.is_executed, 0);
    }

    #[test(
        sender = @0x12345,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun init_withdraw_not_owner(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let amount = 100 * 100000000;

        register_multisig_txs<WithdrawParams<TestCAKE>>(&multisig_wallet);
        init_withdraw<TestCAKE>(&sender, &multisig_wallet, eta, expiration, sender_addr, amount);
    }

    #[test(
        sender = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun init_withdraw_successfully(
        sender: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let amount = 100 * 100000000;

        let seq_number = next_seq_number(multisig_wallet_addr);
        register_multisig_txs<WithdrawParams<TestCAKE>>(&multisig_wallet);
        init_withdraw<TestCAKE>(&sender, &multisig_wallet, eta, expiration, sender_addr, amount);

        let multisig_txs = borrow_global<MultisigTxs<WithdrawParams<TestCAKE>>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.params.amount == amount, 0);
        assert!(tx.params.to == sender_addr, 0);
        assert!(Table::contains(&tx.approvals, sender_addr), 0);
        assert!(Table::length(&tx.approvals) == 1, 0);
        assert!(!tx.is_executed, 0);
    }

    #[test(
        sender = @0x12345,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun approve_add_owner_not_owner(
        sender: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        executor = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 3)]
    fun approve_add_owner_already_executed(
        sender: signer,
        executor: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_add_owner(&executor, &multisig_wallet, seq_number);
        approve_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 4)]
    fun approve_add_owner_already_approved(
        sender: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&sender, &multisig_wallet, seq_number);
        approve_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun approve_add_owner_successfully(
        sender: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        let num_approvals = num_multisig_tx_approvals<AddOwnerParams>(multisig_wallet_addr, seq_number);
        approve_add_owner(&sender, &multisig_wallet, seq_number);

        let multisig_txs = borrow_global<MultisigTxs<AddOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(Table::contains(&tx.approvals, sender_addr), 0);
        assert!(Table::length(&tx.approvals) == num_approvals + 1, 0);
        assert!(vector::contains(&tx.approvals_keys, &sender_addr), 0);
        assert!(vector::length(&tx.approvals_keys) == num_approvals + 1, 0);
        assert!(!tx.is_executed, 0);
    }

    #[test(
        sender = @0x12345,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 1)]
    fun execute_add_owner_not_owner(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 13)]
    fun execute_add_owner_already_executed(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 2)]
    fun execute_add_owner_less_than_threshold(
        sender: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 11)]
    fun execute_add_owner_timelock_not_surpassed(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 12)]
    fun execute_add_owner_expired(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS + DAY_IN_SECONDS);
        execute_add_owner(&sender, &multisig_wallet, seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun execute_add_owner_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_owner_addr = @0x12345;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_add_owner(&initiator, &multisig_wallet, eta, expiration, new_owner_addr);
        approve_add_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        let num_owners = num_owners(multisig_wallet_addr);
        execute_add_owner(&sender, &multisig_wallet, seq_number);

        let multisig_txs = borrow_global<MultisigTxs<AddOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.is_executed, 0);

        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(Table::contains(&multisig_wallet.owners, new_owner_addr), 0);
        assert!(Table::length(&multisig_wallet.owners) == num_owners + 1, 0);
        assert!(vector::contains(&multisig_wallet.owners_keys, &new_owner_addr), 0);
        assert!(vector::length(&multisig_wallet.owners_keys) == num_owners + 1, 0);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun execute_remove_owner_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&initiator, &multisig_wallet, eta, expiration, owner_addr_to_remove);
        approve_remove_owner(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        let num_owners = num_owners(multisig_wallet_addr);
        execute_remove_owner(&sender, &multisig_wallet, seq_number);

        let multisig_txs = borrow_global<MultisigTxs<RemoveOwnerParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.is_executed, 0);

        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(!Table::contains(&multisig_wallet.owners, owner_addr_to_remove), 0);
        assert!(Table::length(&multisig_wallet.owners) == num_owners - 1, 0);
        assert!(!vector::contains(&multisig_wallet.owners_keys, &owner_addr_to_remove), 0);
        assert!(vector::length(&multisig_wallet.owners_keys) == num_owners - 1, 0);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun execute_set_threshold_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let new_threshold = 3;

        let seq_number = next_seq_number(multisig_wallet_addr);
        init_set_threshold(&initiator, &multisig_wallet, eta, expiration, new_threshold);
        approve_set_threshold(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_set_threshold(&sender, &multisig_wallet, seq_number);

        let multisig_txs = borrow_global<MultisigTxs<SetThresholdParams>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.is_executed, 0);

        let multisig_wallet = borrow_global<MultisigWallet>(multisig_wallet_addr);
        assert!(multisig_wallet.threshold == new_threshold, 0);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    fun execute_withdraw_successfully(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        account::create_account_for_test(signer::address_of(&initiator));
        account::create_account_for_test(signer::address_of(&approver));

        managed_coin::initialize<TestCAKE>(
            &pancake_multisig_wallet,
            b"Test Cake",
            b"TCAKE",
            8,
            true,
        );
        coin::register<TestCAKE>(&multisig_wallet);
        managed_coin::mint<TestCAKE>(&pancake_multisig_wallet, signer::address_of(&multisig_wallet), 1000 * 100000000);

        let sender_addr = signer::address_of(&sender);
        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let amount = 100 * 100000000;

        let seq_number = next_seq_number(multisig_wallet_addr);
        register_multisig_txs<WithdrawParams<TestCAKE>>(&multisig_wallet);
        init_withdraw<TestCAKE>(&initiator, &multisig_wallet, eta, expiration, sender_addr, amount);
        approve_withdraw<TestCAKE>(&approver, &multisig_wallet, seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        coin::register<TestCAKE>(&sender);
        execute_withdraw<TestCAKE>(&sender, &multisig_wallet, seq_number);

        let multisig_txs = borrow_global<MultisigTxs<WithdrawParams<TestCAKE>>>(multisig_wallet_addr);
        let tx = Table::borrow(&multisig_txs.txs, seq_number);
        assert!(tx.is_executed, 0);

        assert!(coin::balance<TestCAKE>(sender_addr) == amount, 0);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 13)]
    fun execute_multisig_tx_invalidated(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;
        let new_threshold = 3;

        let remove_owner_seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&initiator, &multisig_wallet, eta, expiration, owner_addr_to_remove);
        approve_remove_owner(&approver, &multisig_wallet, remove_owner_seq_number);
        let set_threshold_seq_number = next_seq_number(multisig_wallet_addr);
        init_set_threshold(&initiator, &multisig_wallet, eta, expiration, new_threshold);
        approve_set_threshold(&approver, &multisig_wallet, set_threshold_seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_set_threshold(&sender, &multisig_wallet, set_threshold_seq_number);
        execute_remove_owner(&sender, &multisig_wallet, remove_owner_seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 6)]
    fun execute_multisig_tx_owners_seq_number_not_match_2(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;
        let new_threshold = 3;

        let set_threshold_seq_number = next_seq_number(multisig_wallet_addr);
        init_set_threshold(&initiator, &multisig_wallet, eta, expiration, new_threshold);
        approve_set_threshold(&approver, &multisig_wallet, set_threshold_seq_number);
        let remove_owner_seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&initiator, &multisig_wallet, eta, expiration, owner_addr_to_remove);
        approve_remove_owner(&approver, &multisig_wallet, remove_owner_seq_number);
        approve_remove_owner(&sender, &multisig_wallet, remove_owner_seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_set_threshold(&sender, &multisig_wallet, set_threshold_seq_number);
        execute_remove_owner(&sender, &multisig_wallet, remove_owner_seq_number);
    }

    #[test(
        sender = @multisig_wallet_owner3,
        approver = @multisig_wallet_owner2,
        initiator = @multisig_wallet_owner1,
        pancake_multisig_wallet_dev = @pancake_multisig_wallet_dev,
        pancake_multisig_wallet = @pancake_multisig_wallet,
        multisig_wallet = @multisig_wallet
    )]
    #[expected_failure(abort_code = 6)]
    fun execute_multisig_tx_owners_seq_number_not_match(
        sender: signer,
        approver: signer,
        initiator: signer,
        pancake_multisig_wallet_dev: signer,
        pancake_multisig_wallet: signer,
        multisig_wallet: signer
    )
    acquires MultisigWallet, MultisigTxs, MultisigWalletEvents {
        before_each_test(
            &sender,
            &pancake_multisig_wallet_dev,
            &pancake_multisig_wallet,
            &multisig_wallet
        );

        let multisig_wallet_addr = signer::address_of(&multisig_wallet);
        let eta = timestamp::now_seconds() + HOUR_IN_SECONDS;
        let expiration = eta + DAY_IN_SECONDS;
        let owner_addr_to_remove = @multisig_wallet_owner1;
        let new_threshold = 3;

        let remove_owner_seq_number = next_seq_number(multisig_wallet_addr);
        init_remove_owner(&initiator, &multisig_wallet, eta, expiration, owner_addr_to_remove);
        approve_remove_owner(&approver, &multisig_wallet, remove_owner_seq_number);
        let set_threshold_seq_number = next_seq_number(multisig_wallet_addr);
        init_set_threshold(&initiator, &multisig_wallet, eta, expiration, new_threshold);
        approve_set_threshold(&approver, &multisig_wallet, set_threshold_seq_number);
        timestamp::fast_forward_seconds(HOUR_IN_SECONDS);
        execute_remove_owner(&sender, &multisig_wallet, remove_owner_seq_number);
        execute_set_threshold(&sender, &multisig_wallet, set_threshold_seq_number);
    }

    #[test_only]
    fun before_each_test(
        sender: &signer,
        pancake_multisig_wallet_dev: &signer,
        pancake_multisig_wallet: &signer,
        multisig_wallet: &signer
    ) {
        genesis::setup();

        account::create_account_for_test(signer::address_of(sender));
        account::create_account_for_test(signer::address_of(pancake_multisig_wallet_dev));

        resource_account::create_resource_account(pancake_multisig_wallet_dev, b"pancake_multisig_wallet", x"");
        init_module(pancake_multisig_wallet);

        resource_account::create_resource_account(pancake_multisig_wallet_dev, b"multisig_wallet", x"");
        initialize(multisig_wallet, vector[@multisig_wallet_owner1, @multisig_wallet_owner2, @multisig_wallet_owner3], 2);
    }
}
