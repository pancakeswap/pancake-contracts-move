module pancake_cake_oft_admin::admin {
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::coin;

    use pancake_multisig_wallet::multisig_wallet;
    use pancake_oft::oft;

    const MULTISIG_WALLET_ADDRESS: address = @pancake_cake_oft_admin;

    const GRACE_PERIOD: u64 = 14 * 24 * 60 * 60; // in seconds

    struct Capabilities has key {
        signer_cap: account::SignerCapability,
    }

    /// CAKE OFT specific params

    struct SetHardCapParams has copy, store {
        chain_id: u64,
        cap: u64,
    }

    struct WhitelistParams has copy, store {
        addr: address,
        enable: bool,
    }

    struct PauseParams has copy, store {
        paused: bool,
    }

    struct TransferAdminParams has copy, store {
        new_admin: address,
    }

    struct SetTrustRemoteParams has copy, store {
        chain_id: u64,
        remote_addr: vector<u8>,
    }

    struct SetDefaultFeeParams has copy, store {
        fee_bp: u64,
    }

    struct SetFeeParams has copy, store {
        dst_chain_id: u64,
        enabled: bool,
        fee_bp: u64,
    }

    struct SetFeeOwnerParams has copy, store {
        new_owner: address,
    }

    struct EnableCustomAdapterParamsParams has copy, store {
        enabled: bool,
    }

    struct SetMinDstGasParams has copy, store {
        chain_id: u64,
        pk_type: u64,
        min_dst_gas: u64,
    }

    struct SetConfigParams has copy, store {
        major_version: u64,
        minor_version: u8,
        chain_id: u64,
        config_type: u8,
        config_bytes: vector<u8>,
    }

    struct SetSendMsglibParams has copy, store {
        chain_id: u64,
        major: u64,
        minor: u8
    }

    struct SetReceiveMsglibParams has copy, store {
        chain_id: u64,
        major: u64,
        minor: u8
    }

    struct SetExecutorParams has copy, store {
        chain_id: u64,
        version: u64,
        executor: address,
    }

    struct UpgradeOftParams has copy, store {
        metadata_serialized: vector<u8>,
        code: vector<vector<u8>>,
    }

    fun init_module(sender: &signer) {
        let owners = vector[@pancake_cake_oft_admin_owner1, @pancake_cake_oft_admin_owner2, @pancake_cake_oft_admin_owner3];
        let threshold = 2;
        multisig_wallet::initialize(sender, owners, threshold);

        multisig_wallet::register_multisig_txs<SetHardCapParams>(sender);
        multisig_wallet::register_multisig_txs<WhitelistParams>(sender);
        multisig_wallet::register_multisig_txs<PauseParams>(sender);
        multisig_wallet::register_multisig_txs<TransferAdminParams>(sender);
        multisig_wallet::register_multisig_txs<SetTrustRemoteParams>(sender);
        multisig_wallet::register_multisig_txs<SetDefaultFeeParams>(sender);
        multisig_wallet::register_multisig_txs<SetFeeParams>(sender);
        multisig_wallet::register_multisig_txs<SetFeeOwnerParams>(sender);
        multisig_wallet::register_multisig_txs<EnableCustomAdapterParamsParams>(sender);
        multisig_wallet::register_multisig_txs<SetMinDstGasParams>(sender);
        multisig_wallet::register_multisig_txs<SetConfigParams>(sender);
        multisig_wallet::register_multisig_txs<SetSendMsglibParams>(sender);
        multisig_wallet::register_multisig_txs<SetReceiveMsglibParams>(sender);
        multisig_wallet::register_multisig_txs<SetExecutorParams>(sender);
        multisig_wallet::register_multisig_txs<UpgradeOftParams>(sender);

        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @pancake_cake_oft_admin_dev);
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

    /// CAKE OFT specific operations

    public entry fun init_set_hard_cap(sender: &signer, eta: u64, chain_id: u64, cap: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetHardCapParams>(sender, &signer, eta, expiration, SetHardCapParams {
            chain_id,
            cap,
        });
    }

    public entry fun init_whitelist(sender: &signer, eta: u64, addr: address, enable: bool) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<WhitelistParams>(sender, &signer, eta, expiration, WhitelistParams {
            addr,
            enable,
        });
    }

    public entry fun init_pause(sender: &signer, eta: u64, paused: bool) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<PauseParams>(sender, &signer, eta, expiration, PauseParams {
            paused,
        });
    }

    public entry fun init_transfer_admin(sender: &signer, eta: u64, new_admin: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<TransferAdminParams>(sender, &signer, eta, expiration, TransferAdminParams {
            new_admin,
        });
    }

    public entry fun init_set_trust_remote(sender: &signer, eta: u64, chain_id: u64, remote_addr: vector<u8>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetTrustRemoteParams>(sender, &signer, eta, expiration, SetTrustRemoteParams {
            chain_id,
            remote_addr,
        });
    }

    public entry fun init_set_default_fee(sender: &signer, eta: u64, fee_bp: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetDefaultFeeParams>(sender, &signer, eta, expiration, SetDefaultFeeParams {
            fee_bp,
        });
    }

    public entry fun init_set_fee(sender: &signer, eta: u64, dst_chain_id: u64, enabled: bool, fee_bp: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetFeeParams>(sender, &signer, eta, expiration, SetFeeParams {
            dst_chain_id,
            enabled,
            fee_bp,
        });
    }

    public entry fun init_set_fee_owner(sender: &signer, eta: u64, new_owner: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetFeeOwnerParams>(sender, &signer, eta, expiration, SetFeeOwnerParams {
            new_owner,
        });
    }

    public entry fun init_enable_custom_adapter_params(sender: &signer, eta: u64, enabled: bool) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<EnableCustomAdapterParamsParams>(sender, &signer, eta, expiration, EnableCustomAdapterParamsParams {
            enabled,
        });
    }

    public entry fun init_set_min_dst_gas(sender: &signer, eta: u64, chain_id: u64, pk_type: u64, min_dst_gas: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetMinDstGasParams>(sender, &signer, eta, expiration, SetMinDstGasParams {
            chain_id,
            pk_type,
            min_dst_gas,
        });
    }

    public entry fun init_set_config(sender: &signer, eta: u64, major_version: u64, minor_version: u8, chain_id: u64, config_type: u8, config_bytes: vector<u8>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetConfigParams>(sender, &signer, eta, expiration, SetConfigParams {
            major_version,
            minor_version,
            chain_id,
            config_type,
            config_bytes,
        });
    }

    public entry fun init_set_send_msglib(sender: &signer, eta: u64, chain_id: u64, major: u64, minor: u8) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetSendMsglibParams>(sender, &signer, eta, expiration, SetSendMsglibParams {
            chain_id,
            major,
            minor,
        });
    }

    public entry fun init_set_receive_msglib(sender: &signer, eta: u64, chain_id: u64, major: u64, minor: u8) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetReceiveMsglibParams>(sender, &signer, eta, expiration, SetReceiveMsglibParams {
            chain_id,
            major,
            minor,
        });
    }

    public entry fun init_set_executor(sender: &signer, eta: u64, chain_id: u64, version: u64, executor: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetExecutorParams>(sender, &signer, eta, expiration, SetExecutorParams {
            chain_id,
            version,
            executor,
        });
    }

    public entry fun init_upgrade_oft(sender: &signer, eta: u64, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpgradeOftParams>(sender, &signer, eta, expiration, UpgradeOftParams {
            metadata_serialized,
            code,
        });
    }

    public entry fun approve_set_hard_cap(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetHardCapParams>(sender, &signer, seq_number);
    }

    public entry fun approve_whitelist(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<WhitelistParams>(sender, &signer, seq_number);
    }

    public entry fun approve_pause(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<PauseParams>(sender, &signer, seq_number);
    }

    public entry fun approve_transfer_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<TransferAdminParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_trust_remote(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetTrustRemoteParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_default_fee(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetDefaultFeeParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_fee(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetFeeParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_fee_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetFeeOwnerParams>(sender, &signer, seq_number);
    }

    public entry fun approve_enable_custom_adapter_params(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<EnableCustomAdapterParamsParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_min_dst_gas(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetMinDstGasParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_config(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetConfigParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_send_msglib(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetSendMsglibParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_receive_msglib(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetReceiveMsglibParams>(sender, &signer, seq_number);
    }

    public entry fun approve_set_executor(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetExecutorParams>(sender, &signer, seq_number);
    }

    public entry fun approve_upgrade_oft(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpgradeOftParams>(sender, &signer, seq_number);
    }

    public entry fun execute_set_hard_cap(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetHardCapParams>(sender, &signer, seq_number);

        let SetHardCapParams { chain_id, cap } = multisig_wallet::multisig_tx_params<SetHardCapParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_hard_cap(&signer, chain_id, cap);
    }

    public entry fun execute_whitelist(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<WhitelistParams>(sender, &signer, seq_number);

        let WhitelistParams { addr, enable } = multisig_wallet::multisig_tx_params<WhitelistParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::whitelist(&signer, addr, enable);
    }

    public entry fun execute_pause(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<WhitelistParams>(sender, &signer, seq_number);

        let PauseParams { paused } = multisig_wallet::multisig_tx_params<PauseParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::pause(&signer, paused);
    }

    public entry fun execute_transfer_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<TransferAdminParams>(sender, &signer, seq_number);

        let TransferAdminParams { new_admin } = multisig_wallet::multisig_tx_params<TransferAdminParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::transfer_admin(&signer, new_admin);
    }

    public entry fun execute_set_trust_remote(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetTrustRemoteParams>(sender, &signer, seq_number);

        let SetTrustRemoteParams { chain_id, remote_addr } = multisig_wallet::multisig_tx_params<SetTrustRemoteParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_trust_remote(&signer, chain_id, remote_addr);
    }

    public entry fun execute_set_default_fee(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetDefaultFeeParams>(sender, &signer, seq_number);

        let SetDefaultFeeParams { fee_bp } = multisig_wallet::multisig_tx_params<SetDefaultFeeParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_default_fee(&signer, fee_bp);
    }

    public entry fun execute_set_fee(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetFeeParams>(sender, &signer, seq_number);

        let SetFeeParams { dst_chain_id, enabled, fee_bp } = multisig_wallet::multisig_tx_params<SetFeeParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_fee(&signer, dst_chain_id, enabled, fee_bp);
    }

    public entry fun execute_set_fee_owner(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetFeeOwnerParams>(sender, &signer, seq_number);

        let SetFeeOwnerParams { new_owner } = multisig_wallet::multisig_tx_params<SetFeeOwnerParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_fee_owner(&signer, new_owner);
    }

    public entry fun execute_enable_custom_adapter_params(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<EnableCustomAdapterParamsParams>(sender, &signer, seq_number);

        let EnableCustomAdapterParamsParams { enabled } = multisig_wallet::multisig_tx_params<EnableCustomAdapterParamsParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::enable_custom_adapter_params(&signer, enabled);
    }

    public entry fun execute_set_min_dst_gas(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetMinDstGasParams>(sender, &signer, seq_number);

        let SetMinDstGasParams { chain_id, pk_type, min_dst_gas } = multisig_wallet::multisig_tx_params<SetMinDstGasParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_min_dst_gas(&signer, chain_id, pk_type, min_dst_gas);
    }

    public entry fun execute_set_config(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetConfigParams>(sender, &signer, seq_number);

        let SetConfigParams { major_version, minor_version, chain_id, config_type, config_bytes } = multisig_wallet::multisig_tx_params<SetConfigParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_config(&signer, major_version, minor_version, chain_id, config_type, config_bytes);
    }

    public entry fun execute_set_send_msglib(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetSendMsglibParams>(sender, &signer, seq_number);

        let SetSendMsglibParams { chain_id, major, minor } = multisig_wallet::multisig_tx_params<SetSendMsglibParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_send_msglib(&signer, chain_id, major, minor);
    }

    public entry fun execute_set_receive_msglib(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetReceiveMsglibParams>(sender, &signer, seq_number);

        let SetReceiveMsglibParams { chain_id, major, minor } = multisig_wallet::multisig_tx_params<SetReceiveMsglibParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_receive_msglib(&signer, chain_id, major, minor);
    }

    public entry fun execute_set_executor(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetExecutorParams>(sender, &signer, seq_number);

        let SetExecutorParams { chain_id, version, executor } = multisig_wallet::multisig_tx_params<SetExecutorParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::set_executor(&signer, chain_id, version, executor);
    }

    public entry fun execute_upgrade_oft(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpgradeOftParams>(sender, &signer, seq_number);

        let UpgradeOftParams { metadata_serialized, code } = multisig_wallet::multisig_tx_params<UpgradeOftParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        oft::upgrade_oft(&signer, metadata_serialized, code);
    }
}
