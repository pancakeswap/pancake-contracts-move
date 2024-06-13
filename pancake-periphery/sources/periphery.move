module pancake_periphery::periphery {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::resource_account;
    use pancake::router;
    use pancake::swap;
    use pancake::swap_utils;
    use pancake_masterchef::masterchef;

    const RESOURCE_ORIGIN: address = @periphery_origin;

    fun init_module(sender: &signer) {
        // Retrieve the resource account.
        // We will not store the resource account signer capability.
        // So no one can upgrade this periphery module.
        // If you want to upgrade the periphery module, you need to deploy a new one.
        let _ = resource_account::retrieve_resource_account_cap(sender, RESOURCE_ORIGIN);
    }

    /// Add liquidity and stake the LP token balance delta to the masterchef.
    public entry fun add_liquidity_and_stake<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
        ) {
        let sender_addr = signer::address_of(sender);
        let lp_amount_before;
        let lp_amount_after;
        if(swap_utils::sort_token_type<X, Y>()){
            lp_amount_before = coin::balance<swap::LPToken<X, Y>>(sender_addr);

            router::add_liquidity<X, Y>(
                sender,
                amount_x_desired,
                amount_y_desired,
                amount_x_min,
                amount_y_min,
            );

            lp_amount_after = coin::balance<swap::LPToken<X, Y>>(sender_addr);
            masterchef::deposit<swap::LPToken<X, Y>>(sender, lp_amount_after - lp_amount_before);

        }else{
            lp_amount_before = coin::balance<swap::LPToken<Y, X>>(sender_addr);

            router::add_liquidity<Y, X>(
                sender,
                amount_y_desired,
                amount_x_desired,
                amount_y_min,
                amount_x_min,
            );

            lp_amount_after = coin::balance<swap::LPToken<Y, X>>(sender_addr);
            masterchef::deposit<swap::LPToken<Y, X>>(sender, lp_amount_after - lp_amount_before);
        };
    }

    /// Add liquidity and stake user all the LP token balance to the masterchef.
    public entry fun add_liquidity_and_stake_all<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
        ) {
        router::add_liquidity<X, Y>(
            sender,
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
        );
        let sender_addr = signer::address_of(sender);
        let lp_amount;
        if(swap_utils::sort_token_type<X, Y>()){
            lp_amount = coin::balance<swap::LPToken<X, Y>>(sender_addr);
            masterchef::deposit<swap::LPToken<X, Y>>(sender, lp_amount);
        }else{
            lp_amount = coin::balance<swap::LPToken<Y, X>>(sender_addr);
            masterchef::deposit<swap::LPToken<Y, X>>(sender, lp_amount);
        };
    }

    /// Unstake the LP token from the masterchef and remove liquidity.
    public entry fun unstake_and_remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64,
        ) {
        if(swap_utils::sort_token_type<X, Y>()){
            masterchef::withdraw<swap::LPToken<X, Y>>(sender, liquidity);
        }else{
            masterchef::withdraw<swap::LPToken<Y, X>>(sender, liquidity);
        };
      
        router::remove_liquidity<X, Y>(
            sender,
            liquidity,
            amount_x_min,
            amount_y_min,
        );
    }

    /// Unstake the LP token balance from the masterchef and remove user's total liquidity.
    public entry fun unstake_and_remove_all_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64,
        ) {
        let sender_addr = signer::address_of(sender);
        let total_liquidity;
        if(swap_utils::sort_token_type<X, Y>()){
            masterchef::withdraw<swap::LPToken<X, Y>>(sender, liquidity);
            total_liquidity = coin::balance<swap::LPToken<X, Y>>(sender_addr);
        }else{
            masterchef::withdraw<swap::LPToken<Y, X>>(sender, liquidity);
            total_liquidity = coin::balance<swap::LPToken<Y, X>>(sender_addr);
        };
        
        router::remove_liquidity<X, Y>(
            sender,
            total_liquidity,
            amount_x_min,
            amount_y_min,
        );
    }

    #[test_only]
    public fun initialize_for_test(account: &signer) {
        init_module(account);
    }
}