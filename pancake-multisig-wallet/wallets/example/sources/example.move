// TODO: 1. Change package and module names
module example_multisig_wallet::example {
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_framework::coin;

    use pancake_multisig_wallet::multisig_wallet;

    // TODO: 2. Update this
    const MULTISIG_WALLET_ADDRESS: address = @example_multisig_wallet;

    const GRACE_PERIOD: u64 = 14 * 24 * 60 * 60; // in seconds

    struct Capabilities has key {
        signer_cap: account::SignerCapability,
    }

    // TODO: 4. Define your own structs for customized multisig transactions

    fun init_module(sender: &signer) {
        // TODO: 3. Set owners and threshold
        let owners = vector[@example_multisig_wallet_owner1, @example_multisig_wallet_owner2, @example_multisig_wallet_owner3];
        let threshold = 2;
        multisig_wallet::initialize(sender, owners, threshold);

        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @example_multisig_wallet_dev);
        move_to(sender, Capabilities {
            signer_cap,
        });
    }

    public entry fun init_add_owner(sender: &signer, eta: u64, owner: address) {
        let expiration = eta + GRACE_PERIOD;
        multisig_wallet::init_add_owner(sender, MULTISIG_WALLET_ADDRESS, eta, expiration, owner);
    }

    public entry fun init_remove_owner(sender: &signer, eta: u64, owner: address) {
        let expiration = eta + GRACE_PERIOD;
        multisig_wallet::init_remove_owner(sender, MULTISIG_WALLET_ADDRESS, eta, expiration, owner);
    }

    public entry fun init_set_threshold(sender: &signer, eta: u64, threshold: u8) {
        let expiration = eta + GRACE_PERIOD;
        multisig_wallet::init_set_threshold(sender, MULTISIG_WALLET_ADDRESS, eta, expiration, threshold);
    }

    public entry fun register_coin<CoinType>() acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        coin::register<CoinType>(&signer);
    }

    public entry fun init_withdraw<CoinType>(sender: &signer, amount: u64) acquires Capabilities {
        if (!multisig_wallet::is_withdraw_multisig_txs_registered<CoinType>(MULTISIG_WALLET_ADDRESS)) {
            let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
            let signer = account::create_signer_with_capability(&capabilities.signer_cap);
            multisig_wallet::register_withdraw_multisig_txs<CoinType>(&signer);
        };
        let eta = timestamp::now_seconds();
        let expiration = eta + GRACE_PERIOD;
        multisig_wallet::init_withdraw<CoinType>(sender, MULTISIG_WALLET_ADDRESS, eta, expiration, amount);
    }

    public entry fun approve_add_owner(sender: &signer, seq_number: u64) {
        multisig_wallet::approve_add_owner(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun approve_remove_owner(sender: &signer, seq_number: u64) {
        multisig_wallet::approve_remove_owner(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun approve_set_threshold(sender: &signer, seq_number: u64) {
        multisig_wallet::approve_set_threshold(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun approve_withdraw<CoinType>(sender: &signer, seq_number: u64) {
        multisig_wallet::approve_withdraw<CoinType>(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun execute_add_owner(sender: &signer, seq_number: u64) {
        multisig_wallet::execute_add_owner(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun execute_remove_owner(sender: &signer, seq_number: u64) {
        multisig_wallet::execute_remove_owner(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun execute_set_threshold(sender: &signer, seq_number: u64) {
        multisig_wallet::execute_set_threshold(sender, MULTISIG_WALLET_ADDRESS, seq_number);
    }

    public entry fun execute_withdraw<CoinType>(sender: &signer, seq_number: u64) acquires Capabilities {
        let capabilities = borrow_global<Capabilities>(MULTISIG_WALLET_ADDRESS);
        let signer = account::create_signer_with_capability(&capabilities.signer_cap);
        multisig_wallet::execute_withdraw<CoinType>(sender, &signer, seq_number);
    }

    // TODO: 5. Define your own init, approve and execute functions for customized multisig transactions
}
