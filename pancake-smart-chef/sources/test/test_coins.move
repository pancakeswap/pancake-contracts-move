#[test_only]
module test_coin::test_coins {
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use std::signer;

    struct TestCAKE {}
    struct TestBUSD {}
    struct TestUSDC {}
    struct TestBNB {}
    struct Test30DEC {}

    public entry fun init_coins(): signer {
        let account = account::create_account_for_test(@test_coin);

        // init coins
        managed_coin::initialize<TestCAKE>(
            &account,
            b"Cake",
            b"CAKE",
            8,
            false,
        );
        managed_coin::initialize<TestBUSD>(
            &account,
            b"Busd",
            b"BUSD",
            8,
            false,
        );

        managed_coin::initialize<TestUSDC>(
            &account,
            b"USDC",
            b"USDC",
            8,
            false,
        );

        managed_coin::initialize<TestBNB>(
            &account,
            b"BNB",
            b"BNB",
            8,
            false,
        );

        managed_coin::initialize<Test30DEC>(
            &account,
            b"Test30DEC",
            b"Test30DEC",
            30,
            false,
        );

        account
    }


    public entry fun register_and_mint<CoinType>(account: &signer, to: &signer, amount: u64) {
      managed_coin::register<CoinType>(to);
      managed_coin::mint<CoinType>(account, signer::address_of(to), amount)
    }

    public entry fun mint<CoinType>(account: &signer, to: &signer, amount: u64) {
        managed_coin::mint<CoinType>(account, signer::address_of(to), amount)
    }
}