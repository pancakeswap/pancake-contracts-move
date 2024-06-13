module pancake_smart_chef_multisig_wallet::admin {
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::coin;

    use pancake_multisig_wallet::multisig_wallet;
    use pancake::smart_chef;

    const MULTISIG_WALLET_ADDRESS: address = @pancake_smart_chef_multisig_wallet;

    const GRACE_PERIOD: u64 = 14 * 24 * 60 * 60; // in seconds

    struct Capabilities has key {
        signer_cap: account::SignerCapability,
    }

    struct CreatePoolParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {
        reward_per_second: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        pool_limit_per_user: u64,
        seconds_for_user_limit: u64
    }

    struct AddRewardParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {
        amount: u64
    }

    struct EmergencyRewardWithdrawParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {}

    struct StopRewardParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {}

    struct UpdatePoolLimitPerUserParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {
        seconds_for_user_limit: bool,
        pool_limit_per_user: u64
    }

    struct UpdateRewardPerSecondParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {
        reward_per_second: u64
    }

    struct UpdateStartAndEndTimestampParams<phantom StakeToken, phantom RewardToken, phantom UID> has copy, store {
        start_timestamp: u64,
        end_timestamp: u64
    }

    struct SetAdminParams has copy, store {
        new_admin: address,
    }

    struct UpgradeContractParams has copy, store {
        metadata_serialized: vector<u8>,
        code: vector<vector<u8>>
    }

    fun init_module(sender: &signer) {
        let owners = vector[@pancake_smart_chef_multisig_wallet_owner1, @pancake_smart_chef_multisig_wallet_owner2, @pancake_smart_chef_multisig_wallet_owner3];
        let threshold = 2;
        multisig_wallet::initialize(sender, owners, threshold);

        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @pancake_smart_chef_multisig_wallet_dev);
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

    public entry fun init_create_pool<StakeToken, RewardToken, UID>(sender: &signer,
                                                                    eta: u64,
                                                                    reward_per_second: u64,
                                                                    start_timestamp: u64,
                                                                    end_timestamp: u64,
                                                                    pool_limit_per_user: u64,
                                                                    seconds_for_user_limit: u64
    ) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<CreatePoolParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, CreatePoolParams<StakeToken, RewardToken, UID> {
            reward_per_second,
            start_timestamp,
            end_timestamp,
            pool_limit_per_user,
            seconds_for_user_limit
        });
    }

    public entry fun init_add_reward<StakeToken, RewardToken, UID>(sender: &signer, eta: u64, amount: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<AddRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, AddRewardParams<StakeToken, RewardToken, UID> {
            amount
        });
    }

    public entry fun init_emergency_reward_withdraw<StakeToken, RewardToken, UID>(sender: &signer, eta: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<EmergencyRewardWithdrawParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, EmergencyRewardWithdrawParams<StakeToken, RewardToken, UID> {});
    }

    public entry fun init_stop_reward<StakeToken, RewardToken, UID>(sender: &signer, eta: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<StopRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, StopRewardParams<StakeToken, RewardToken, UID> {});
    }

    public entry fun init_update_pool_limit_per_user<StakeToken, RewardToken, UID>(sender: &signer, eta: u64, seconds_for_user_limit: bool, pool_limit_per_user: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID> {
            seconds_for_user_limit,
            pool_limit_per_user
        });
    }

    public entry fun init_update_reward_per_second<StakeToken, RewardToken, UID>(sender: &signer, eta: u64, reward_per_second: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpdateRewardPerSecondParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, UpdateRewardPerSecondParams<StakeToken, RewardToken, UID> {
            reward_per_second
        });
    }

    public entry fun init_update_start_and_end_timestamp<StakeToken, RewardToken, UID>(sender: &signer, eta: u64, start_timestamp: u64, end_timestamp: u64) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID>>(sender, &signer, eta, expiration, UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID> {
            start_timestamp,
            end_timestamp
        });
    }

    public entry fun init_set_admin(sender: &signer, eta: u64, new_admin: address) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<SetAdminParams>(sender, &signer, eta, expiration, SetAdminParams {
            new_admin,
        });
    }

    public entry fun init_upgrade_contract(sender: &signer, eta: u64, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires Capabilities {
        let expiration = eta + GRACE_PERIOD;
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::init_multisig_tx<UpgradeContractParams>(sender, &signer, eta, expiration, UpgradeContractParams {
            metadata_serialized,
            code,
        });
    }

    public entry fun approve_create_pool<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<CreatePoolParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_add_reward<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<AddRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_emergency_reward_withdraw<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<EmergencyRewardWithdrawParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_stop_reward<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<StopRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_update_pool_limit_per_user<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_update_reward_per_second<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpdateRewardPerSecondParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_update_start_and_end_timestamp<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
    }

    public entry fun approve_set_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<SetAdminParams>(sender, &signer, seq_number);
    }

    public entry fun approve_upgrade_contract(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::approve_multisig_tx<UpgradeContractParams>(sender, &signer, seq_number);
    }

    public entry fun execute_create_pool<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<CreatePoolParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);

        let CreatePoolParams { reward_per_second, start_timestamp, end_timestamp, pool_limit_per_user, seconds_for_user_limit } = multisig_wallet::multisig_tx_params<CreatePoolParams<StakeToken, RewardToken, UID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::create_pool<StakeToken, RewardToken, UID>(&signer, reward_per_second, start_timestamp, end_timestamp, pool_limit_per_user, seconds_for_user_limit);
    }

    public entry fun execute_add_reward<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<AddRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);

        let AddRewardParams<StakeToken, RewardToken, UID> { amount } = multisig_wallet::multisig_tx_params<AddRewardParams<StakeToken, RewardToken, UID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::add_reward<StakeToken, RewardToken, UID>(&signer, amount);
    }

    public entry fun execute_emergency_reward_withdraw<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<EmergencyRewardWithdrawParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
        smart_chef::emergency_reward_withdraw<StakeToken, RewardToken, UID>(&signer);
    }

    public entry fun execute_stop_reward<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<StopRewardParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);
        smart_chef::stop_reward<StakeToken, RewardToken, UID>(&signer);
    }

    public entry fun execute_update_pool_limit_per_user<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);

        let UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID> { seconds_for_user_limit, pool_limit_per_user } = multisig_wallet::multisig_tx_params<UpdatePoolLimitPerUserParams<StakeToken, RewardToken, UID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::update_pool_limit_per_user<StakeToken, RewardToken, UID>(&signer, seconds_for_user_limit, pool_limit_per_user);
    }

    public entry fun execute_update_reward_per_second<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpdateRewardPerSecondParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);

        let UpdateRewardPerSecondParams<StakeToken, RewardToken, UID> { reward_per_second } = multisig_wallet::multisig_tx_params<UpdateRewardPerSecondParams<StakeToken, RewardToken, UID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::update_reward_per_second<StakeToken, RewardToken, UID>(&signer, reward_per_second);
    }

    public entry fun execute_update_start_and_end_timestamp<StakeToken, RewardToken, UID>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID>>(sender, &signer, seq_number);

        let UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID> { start_timestamp, end_timestamp } = multisig_wallet::multisig_tx_params<UpdateStartAndEndTimestampParams<StakeToken, RewardToken, UID>>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::update_start_and_end_timestamp<StakeToken, RewardToken, UID>(&signer, start_timestamp, end_timestamp);
    }

    public entry fun execute_set_admin(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<SetAdminParams>(sender, &signer, seq_number);

        let SetAdminParams { new_admin } = multisig_wallet::multisig_tx_params<SetAdminParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::set_admin(&signer, new_admin);
    }

    public entry fun execute_upgrade_contract(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);

        multisig_wallet::execute_multisig_tx<UpgradeContractParams>(sender, &signer, seq_number);

        let UpgradeContractParams { metadata_serialized, code } = multisig_wallet::multisig_tx_params<UpgradeContractParams>(MULTISIG_WALLET_ADDRESS, seq_number);
        smart_chef::upgrade_contract(&signer, metadata_serialized, code);
    }
}
