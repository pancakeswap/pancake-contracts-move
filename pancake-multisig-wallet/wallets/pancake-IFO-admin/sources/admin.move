// TODO: 1. Change package and module names
module IFO_multisig_wallet::admin {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::coin;

    use pancake_multisig_wallet::multisig_wallet;
    use pancake_IFO::IFO;

    const MULTISIG_WALLET_ADDRESS: address = @IFO_multisig_wallet;

    const GRACE_PERIOD: u64 = 14 * 24 * 60 * 60; // in seconds

    struct Capabilities has key {
        signer_cap: account::SignerCapability,
    }

    struct SetAdminParams has copy, store {
        admin: address,
    }

    struct InitializePoolParams<phantom RaisingCoin, phantom OfferingCoin> has key, copy, store {
        start_time: u64,
        end_time: u64,
    }

    struct SetPoolParams<phantom RaisingCoin, phantom OfferingCoin, phantom PoolID> has key, copy, store {
        raising_amount: u64,
        offering_amount: u64,
        limit_per_user: u64,
        has_tax: bool,
        vesting_percentage: u64,
        vesting_cliff: u64,
        vesting_duration: u64,
        vesting_slice_period_seconds: u64,
    }

    struct FinalWithdrawParams<phantom RaisingCoin, phantom OfferingCoin> has key, copy, store {
        raising_amount: u64,
        offering_amount: u64,
        receiver: address,
    }
    struct RevokeParams<phantom RaisingCoin, phantom OfferingCoin> has key, copy, store {}

    struct UpdateStartAndEndTimeParams<phantom RaisingCoin, phantom OfferingCoin> has key, copy, store {
        start_time: u64,
        end_time: u64,
    }

    struct UpgradeParams has key, copy, store {
        metadata: vector<u8>,
        code: vector<vector<u8>>,
    }

    struct ReleaseParams<phantom RaisingCoin, phantom OfferingCoin, phantom PoolID> has key, copy, store {
        vesting_schedule_id: vector<u8>,
    }

    fun init_module(sender: &signer) {

        let owners = vector[@IFO_multisig_wallet_owner1, @IFO_multisig_wallet_owner2, @IFO_multisig_wallet_owner3];
        let threshold = 2;
        multisig_wallet::initialize(sender, owners, threshold);

        multisig_wallet::register_multisig_txs<SetAdminParams>(sender);
        multisig_wallet::register_multisig_txs<UpgradeParams>(sender);

        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @IFO_multisig_wallet_dev);
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

    public entry fun init_set_admin(sender: &signer, eta: u64, admin: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetAdminParams>(sender, &signer, eta, expiration, SetAdminParams {
            admin,
        });
    }

    public entry fun init_initialize_pool<RaisingCoin, OfferingCoin>(sender: &signer, eta: u64, start_time: u64, end_time: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<InitializePoolParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<InitializePoolParams<RaisingCoin, OfferingCoin>>(&signer);
        };
        multisig_wallet::init_multisig_tx<InitializePoolParams<RaisingCoin, OfferingCoin>>(sender, &signer, eta, expiration, InitializePoolParams<RaisingCoin, OfferingCoin> {
            start_time,
            end_time,
        });
    }

    public entry fun init_set_pool<RaisingCoin, OfferingCoin, PoolID>(
        sender: &signer,
        eta: u64,
        raising_amount: u64,
        offering_amount: u64,
        limit_per_user: u64,
        has_tax: bool,
        vesting_percentage: u64,
        vesting_cliff: u64,
        vesting_duration: u64,
        vesting_slice_period_seconds: u64,
    ) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(&signer);
        };
        multisig_wallet::init_multisig_tx<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, eta, expiration, SetPoolParams<RaisingCoin, OfferingCoin, PoolID> {
            raising_amount,
            offering_amount,
            limit_per_user,
            has_tax,
            vesting_percentage,
            vesting_cliff,
            vesting_duration,
            vesting_slice_period_seconds,
        });
    }

    public entry fun init_final_withdraw<RaisingCoin, OfferingCoin>(sender: &signer, eta: u64, raising_amount: u64, offering_amount: u64, receiver: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(&signer);
        };
        multisig_wallet::init_multisig_tx<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(sender, &signer, eta, expiration, FinalWithdrawParams<RaisingCoin, OfferingCoin> {
            raising_amount,
            offering_amount,
            receiver
        });
    }

    public entry fun init_revoke<RaisingCoin, OfferingCoin>(sender: &signer, eta: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<RevokeParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<RevokeParams<RaisingCoin, OfferingCoin>>(&signer);
        };
        multisig_wallet::init_multisig_tx<RevokeParams<RaisingCoin, OfferingCoin>>(sender, &signer, eta, expiration, RevokeParams<RaisingCoin, OfferingCoin> {});
    }

    public entry fun init_update_start_and_end_time<RaisingCoin, OfferingCoin>(sender: &signer, eta: u64, start_time: u64, end_time: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(&signer);
        };
        multisig_wallet::init_multisig_tx<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(sender, &signer, eta, expiration, UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin> {
            start_time,
            end_time,
        });
    }

    public entry fun init_upgrade(sender: &signer, eta: u64, metadata: vector<u8>, code: vector<vector<u8>>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpgradeParams>(sender, &signer, eta, expiration, UpgradeParams {
            metadata,
            code,
        });
    }

    public entry fun init_release<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, eta: u64, vesting_schedule_id: vector<u8>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        if(!multisig_wallet::is_multisig_txs_registered<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(MULTISIG_WALLET_ADDRESS)){
            multisig_wallet::register_multisig_txs<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(&signer);
        };
        multisig_wallet::init_multisig_tx<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, eta, expiration, ReleaseParams<RaisingCoin, OfferingCoin, PoolID> {
            vesting_schedule_id,
        });
    }

    public entry fun approve_set_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetAdminParams>(sender, &signer, seq_number);
    }

    public entry fun approve_initialize_pool<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<InitializePoolParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);
    }

    public entry fun approve_set_pool<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, seq_number);
    }

    public entry fun approve_revoke<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<RevokeParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);
    }

    public entry fun approve_final_withdraw<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);
    }

    public entry fun approve_update_start_and_end_time<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);
    }

    public entry fun approve_upgrade(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpgradeParams>(sender, &signer, seq_number);
    }

    public entry fun approve_release<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, seq_number);
    }

    public entry fun execute_set_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetAdminParams>(sender, &signer, seq_number);

        let SetAdminParams { admin } = multisig_wallet::multisig_tx_params<SetAdminParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::set_admin(&signer, admin);
    }

    public entry fun execute_initialize_pool<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<InitializePoolParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);

        let InitializePoolParams<RaisingCoin, OfferingCoin> { start_time, end_time} = multisig_wallet::multisig_tx_params<InitializePoolParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::initialize_pool<RaisingCoin, OfferingCoin>(&signer, start_time, end_time);
    }

    public entry fun execute_set_pool<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, seq_number);

        let SetPoolParams<RaisingCoin, OfferingCoin, PoolID> { 
            raising_amount,
            offering_amount,
            limit_per_user,
            has_tax,
            vesting_percentage,
            vesting_cliff,
            vesting_duration,
            vesting_slice_period_seconds
        } = multisig_wallet::multisig_tx_params<SetPoolParams<RaisingCoin, OfferingCoin, PoolID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::set_pool<RaisingCoin, OfferingCoin, PoolID>(
            &signer,
            raising_amount,
            offering_amount,
            limit_per_user,
            has_tax,
            vesting_percentage,
            vesting_cliff,
            vesting_duration,
            vesting_slice_period_seconds
        );
    } 

    public entry fun execute_final_withdraw<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);

        let FinalWithdrawParams<RaisingCoin, OfferingCoin> { raising_amount, offering_amount, receiver} = multisig_wallet::multisig_tx_params<FinalWithdrawParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::final_withdraw<RaisingCoin, OfferingCoin>(&signer, raising_amount, offering_amount);
        // transfer token to receiver account
        if(raising_amount > 0){
            coin::transfer<RaisingCoin>(&signer, receiver, raising_amount);
        };
        if(offering_amount > 0){
            coin::transfer<OfferingCoin>(&signer, receiver, offering_amount);
        };
    }

    public entry fun execute_revoke<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<RevokeParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);

        IFO::revoke<RaisingCoin, OfferingCoin>(&signer);
    }

    public entry fun execute_update_start_and_end_time<RaisingCoin, OfferingCoin>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(sender, &signer, seq_number);

        let UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin> { start_time, end_time} = multisig_wallet::multisig_tx_params<UpdateStartAndEndTimeParams<RaisingCoin, OfferingCoin>>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::update_start_and_end_time<RaisingCoin, OfferingCoin>(&signer, start_time, end_time);
    }

    public entry fun execute_upgrade(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpgradeParams>(sender, &signer, seq_number);

        let UpgradeParams { metadata, code } = multisig_wallet::multisig_tx_params<UpgradeParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::upgrade(&signer, metadata, code);
    }

    public entry fun execute_release<RaisingCoin, OfferingCoin, PoolID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(sender, &signer, seq_number);

        let ReleaseParams<RaisingCoin, OfferingCoin, PoolID> { 
            vesting_schedule_id
        } = multisig_wallet::multisig_tx_params<ReleaseParams<RaisingCoin, OfferingCoin, PoolID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        IFO::release<RaisingCoin, OfferingCoin, PoolID>(&signer, vesting_schedule_id);
    } 

    // This is not admin function, Admin need to use multisign FE to call this IFO function.
    public entry fun execute_deposit_offering_coin<RaisingCoin, OfferingCoin, PoolID>() acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        let amount = coin::balance<OfferingCoin>(MULTISIG_WALLET_ADDRESS);
        IFO::deposit_offering_coin<RaisingCoin, OfferingCoin, PoolID>(&signer, amount);
    } 

    public fun check_or_register_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };
    }
}
