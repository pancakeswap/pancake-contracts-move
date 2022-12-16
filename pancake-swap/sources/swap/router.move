module pancake::router {
    use pancake::swap;
    use std::signer;
    use aptos_framework::coin;
    use pancake::swap_utils;

    //
    // Errors.
    //

    /// Output amount is less than required
    const E_OUTPUT_LESS_THAN_MIN: u64 = 0;
    /// Require Input amount is more than max limit
    const E_INPUT_MORE_THAN_MAX: u64 = 1;
    /// Insufficient X
    const E_INSUFFICIENT_X_AMOUNT: u64 = 2;
    /// Insufficient Y
    const E_INSUFFICIENT_Y_AMOUNT: u64 = 3;
    /// Pair is not created
    const E_PAIR_NOT_CREATED: u64 = 4;

    /// Create a Pair from 2 Coins
    /// Should revert if the pair is already created
    public entry fun create_pair<X, Y>(
        sender: &signer,
    ) {
        if (swap_utils::sort_token_type<X, Y>()) {
            swap::create_pair<X, Y>(sender);
        } else {
            swap::create_pair<Y, X>(sender);
        }
    }


    /// Add Liquidity, create pair if it's needed
    public entry fun add_liquidity<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) {
        if (!(swap::is_pair_created<X, Y>() || swap::is_pair_created<Y, X>())) {
            create_pair<X, Y>(sender);
        };

        let amount_x;
        let amount_y;
        let _lp_amount;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y, _lp_amount) = swap::add_liquidity<X, Y>(sender, amount_x_desired, amount_y_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x, _lp_amount) = swap::add_liquidity<Y, X>(sender, amount_y_desired, amount_x_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        };
    }

    fun is_pair_created_internal<X, Y>(){
        assert!(swap::is_pair_created<X, Y>() || swap::is_pair_created<Y, X>(), E_PAIR_NOT_CREATED);
    }

    /// Remove Liquidity
    public entry fun remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64
    ) {
        is_pair_created_internal<X, Y>();
        let amount_x;
        let amount_y;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y) = swap::remove_liquidity<X, Y>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x) = swap::remove_liquidity<Y, X>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        }
    }

    fun add_swap_event_with_address_internal<X, Y>(
        sender_addr: address,
        amount_x_in: u64,
        amount_y_in: u64,
        amount_x_out: u64,
        amount_y_out: u64
    ) {
        if (swap_utils::sort_token_type<X, Y>()){
            swap::add_swap_event_with_address<X, Y>(sender_addr, amount_x_in, amount_y_in, amount_x_out, amount_y_out);
        } else {
            swap::add_swap_event_with_address<Y, X>(sender_addr, amount_y_in, amount_x_in, amount_y_out, amount_x_out);
        }
    }

    fun add_swap_event_internal<X, Y>(
        sender: &signer,
        amount_x_in: u64,
        amount_y_in: u64,
        amount_x_out: u64,
        amount_y_out: u64
    ) {
        let sender_addr = signer::address_of(sender);
        add_swap_event_with_address_internal<X, Y>(sender_addr, amount_x_in, amount_y_in, amount_x_out, amount_y_out);
    }

    /// Swap exact input amount of X to maxiumin possible amount of Y
    public entry fun swap_exact_input<X, Y>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64,
    ) {
        is_pair_created_internal<X, Y>();
        let y_out = if (swap_utils::sort_token_type<X, Y>()) {
            swap::swap_exact_x_to_y<X, Y>(sender, x_in, signer::address_of(sender))
        } else {
            swap::swap_exact_y_to_x<Y, X>(sender, x_in, signer::address_of(sender))
        };
        assert!(y_out >= y_min_out, E_OUTPUT_LESS_THAN_MIN);
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
    }

    /// Swap miniumn possible amount of X to exact output amount of Y
    public entry fun swap_exact_output<X, Y>(
        sender: &signer,
        y_out: u64,
        x_max_in: u64,
    ) {
        is_pair_created_internal<X, Y>();
        let x_in = if (swap_utils::sort_token_type<X, Y>()) {
            let (rin, rout, _) = swap::token_reserves<X, Y>();
            let amount_in = swap_utils::get_amount_in(y_out, rin, rout);
            swap::swap_x_to_exact_y<X, Y>(sender, amount_in, y_out, signer::address_of(sender))
        } else {
            let (rout, rin, _) = swap::token_reserves<Y, X>();
            let amount_in = swap_utils::get_amount_in(y_out, rin, rout);
            swap::swap_y_to_exact_x<Y, X>(sender, amount_in, y_out, signer::address_of(sender))
        };
        assert!(x_in <= x_max_in, E_INPUT_MORE_THAN_MAX);
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
    }

    fun get_intermediate_output<X, Y>(is_x_to_y: bool, x_in: coin::Coin<X>): coin::Coin<Y> {
        if (is_x_to_y) {
            let (x_out, y_out) = swap::swap_exact_x_to_y_direct<X, Y>(x_in);
            coin::destroy_zero(x_out);
            y_out
        }
        else {
            let (y_out, x_out) = swap::swap_exact_y_to_x_direct<Y, X>(x_in);
            coin::destroy_zero(x_out);
            y_out
        }
    }

    public fun swap_exact_x_to_y_direct_external<X, Y>(x_in: coin::Coin<X>): coin::Coin<Y> {
        is_pair_created_internal<X, Y>();
        let x_in_amount = coin::value(&x_in);
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        let y_out = get_intermediate_output<X, Y>(is_x_to_y, x_in);
        let y_out_amount = coin::value(&y_out);
        add_swap_event_with_address_internal<X, Y>(@zero, x_in_amount, 0, 0, y_out_amount);
        y_out
    }

    fun get_intermediate_output_x_to_exact_y<X, Y>(is_x_to_y: bool, x_in: coin::Coin<X>, amount_out: u64): coin::Coin<Y> {
        if (is_x_to_y) {
            let (x_out, y_out) = swap::swap_x_to_exact_y_direct<X, Y>(x_in, amount_out);
            coin::destroy_zero(x_out);
            y_out
        }
        else {
            let (y_out, x_out) = swap::swap_y_to_exact_x_direct<Y, X>(x_in, amount_out);
            coin::destroy_zero(x_out);
            y_out
        }
    }

    fun get_amount_in_internal<X, Y>(is_x_to_y:bool, y_out_amount: u64): u64 {
        if (is_x_to_y) {
            let (rin, rout, _) = swap::token_reserves<X, Y>();
            swap_utils::get_amount_in(y_out_amount, rin, rout)
        } else {
            let (rout, rin, _) = swap::token_reserves<Y, X>();
            swap_utils::get_amount_in(y_out_amount, rin, rout)
        }
    } 

    public fun get_amount_in<X, Y>(y_out_amount: u64): u64 {
        is_pair_created_internal<X, Y>();
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        get_amount_in_internal<X, Y>(is_x_to_y, y_out_amount)
    }

    public fun swap_x_to_exact_y_direct_external<X, Y>(x_in: coin::Coin<X>, y_out_amount:u64): (coin::Coin<X>, coin::Coin<Y>) {
        is_pair_created_internal<X, Y>();
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        let x_in_withdraw_amount = get_amount_in_internal<X, Y>(is_x_to_y, y_out_amount);
        let x_in_amount = coin::value(&x_in);
        assert!(x_in_amount >= x_in_withdraw_amount, E_INSUFFICIENT_X_AMOUNT);
        let x_in_left = coin::extract(&mut x_in, x_in_amount - x_in_withdraw_amount);
        let y_out = get_intermediate_output_x_to_exact_y<X, Y>(is_x_to_y, x_in, y_out_amount);
        add_swap_event_with_address_internal<X, Y>(@zero, x_in_withdraw_amount, 0, 0, y_out_amount);
        (x_in_left, y_out)
    }

    fun swap_exact_input_double_internal<X, Y, Z>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        x_in: u64,
        z_min_out: u64,
    ): u64 {
        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output<X, Y>(first_is_x_to_y, coin_x);
        let coins_y_out = coin::value(&coin_y);
        let coin_z = get_intermediate_output<Y, Z>(second_is_y_to_z, coin_y);

        let coin_z_amt = coin::value(&coin_z);

        assert!(coin_z_amt >= z_min_out, E_OUTPUT_LESS_THAN_MIN);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<Z>(sender);
        coin::deposit(sender_addr, coin_z);
        
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, coins_y_out);
        add_swap_event_internal<Y, Z>(sender, coins_y_out, 0, 0, coin_z_amt);
        coin_z_amt
    }

    /// Same as `swap_exact_input` with specify path: X -> Y -> Z
    public entry fun swap_exact_input_doublehop<X, Y, Z>(
        sender: &signer,
        x_in: u64,
        z_min_out: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        swap_exact_input_double_internal<X, Y, Z>(sender, first_is_x_to_y, second_is_y_to_z, x_in, z_min_out);
    }

    fun swap_exact_output_double_internal<X, Y, Z>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        x_max_in: u64,
        z_out: u64,
    ): u64 {
        let rin;
        let rout;
        let y_out = if (second_is_y_to_z) {
            (rin, rout, _) = swap::token_reserves<Y, Z>();
            swap_utils::get_amount_in(z_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Z, Y>();
            swap_utils::get_amount_in(z_out, rin, rout)
        };
        let x_in = if (first_is_x_to_y) {
            (rin, rout, _) = swap::token_reserves<X, Y>();
            swap_utils::get_amount_in(y_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Y, X>();
            swap_utils::get_amount_in(y_out, rin, rout)
        };

        assert!(x_in <= x_max_in, E_INPUT_MORE_THAN_MAX);

        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output_x_to_exact_y<X, Y>(first_is_x_to_y, coin_x, y_out);
        let coin_z = get_intermediate_output_x_to_exact_y<Y, Z>(second_is_y_to_z, coin_y, z_out);

        let coin_z_amt = coin::value(&coin_z);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<Z>(sender);
        coin::deposit(sender_addr, coin_z);

        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
        add_swap_event_internal<Y, Z>(sender, y_out, 0, 0, coin_z_amt);
        coin_z_amt
    }

    /// Same as `swap_exact_output` with specify path: X -> Y -> Z
    public entry fun swap_exact_output_doublehop<X, Y, Z>(
        sender: &signer,
        z_out: u64,
        x_max_in: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        swap_exact_output_double_internal<X, Y, Z>(sender, first_is_x_to_y, second_is_y_to_z, x_max_in, z_out);
    }

    fun swap_exact_input_triple_internal<X, Y, Z, A>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        third_is_z_to_a: bool,
        x_in: u64,
        a_min_out: u64,
    ): u64 {
        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output<X, Y>(first_is_x_to_y, coin_x);
        let coins_y_out = coin::value(&coin_y);

        let coin_z = get_intermediate_output<Y, Z>(second_is_y_to_z, coin_y);
        let coins_z_out = coin::value(&coin_z);

        let coin_a = get_intermediate_output<Z, A>(third_is_z_to_a, coin_z);

        let coin_a_amt = coin::value(&coin_a);

        assert!(coin_a_amt >= a_min_out, E_OUTPUT_LESS_THAN_MIN);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<A>(sender);
        coin::deposit(sender_addr, coin_a);

        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, coins_y_out);
        add_swap_event_internal<Y, Z>(sender, coins_y_out, 0, 0, coins_z_out);
        add_swap_event_internal<Z, A>(sender, coins_z_out, 0, 0, coin_a_amt);
        coin_a_amt
    }

    /// Same as `swap_exact_input` with specify path: X -> Y -> Z -> A
    public entry fun swap_exact_input_triplehop<X, Y, Z, A>(
        sender: &signer,
        x_in: u64,
        a_min_out: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        is_pair_created_internal<Z, A>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        let third_is_z_to_a: bool = swap_utils::sort_token_type<Z, A>();

        swap_exact_input_triple_internal<X, Y, Z, A>(sender, first_is_x_to_y, second_is_y_to_z, third_is_z_to_a, x_in, a_min_out);
    }

    fun swap_exact_output_triple_internal<X, Y, Z, A>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        third_is_z_to_a: bool,
        x_max_in: u64,
        a_out: u64,
    ): u64 {
        let rin;
        let rout;
        let z_out = if (third_is_z_to_a) {
            (rin, rout, _) = swap::token_reserves<Z, A>();
            swap_utils::get_amount_in(a_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<A, Z>();
            swap_utils::get_amount_in(a_out, rin, rout)
        };

        let y_out = if (second_is_y_to_z) {
            (rin, rout, _) = swap::token_reserves<Y, Z>();
            swap_utils::get_amount_in(z_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Z, Y>();
            swap_utils::get_amount_in(z_out, rin, rout)
        };
        let x_in = if (first_is_x_to_y) {
            (rin, rout, _) = swap::token_reserves<X, Y>();
            swap_utils::get_amount_in(y_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Y, X>();
            swap_utils::get_amount_in(y_out, rin, rout)
        };

        assert!(x_in <= x_max_in, E_INPUT_MORE_THAN_MAX);

        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output_x_to_exact_y<X, Y>(first_is_x_to_y, coin_x, y_out);
        let coin_z = get_intermediate_output_x_to_exact_y<Y, Z>(second_is_y_to_z, coin_y, z_out);
        let coin_a = get_intermediate_output_x_to_exact_y<Z, A>(third_is_z_to_a, coin_z, a_out);

        let coin_a_amt = coin::value(&coin_a);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<A>(sender);
        coin::deposit(sender_addr, coin_a);

        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
        add_swap_event_internal<Y, Z>(sender, y_out, 0, 0, z_out);
        add_swap_event_internal<Z, A>(sender, z_out, 0, 0, coin_a_amt);
        coin_a_amt
    }

    /// Same as `swap_exact_output` with specify path: X -> Y -> Z -> A
    public entry fun swap_exact_output_triplehop<X, Y, Z, A>(
        sender: &signer,
        a_out: u64,
        x_max_in: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        is_pair_created_internal<Z, A>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        let third_is_z_to_a: bool = swap_utils::sort_token_type<Z, A>();

        swap_exact_output_triple_internal<X, Y, Z, A>(sender, first_is_x_to_y, second_is_y_to_z, third_is_z_to_a, x_max_in, a_out);
    }


    fun swap_exact_input_quadruple_internal<X, Y, Z, A, B>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        third_is_z_to_a: bool,
        fourth_is_a_to_b: bool,
        x_in: u64,
        b_min_out: u64,
    ): u64 {
        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output<X, Y>(first_is_x_to_y, coin_x);
        let coins_y_out = coin::value(&coin_y);

        let coin_z = get_intermediate_output<Y, Z>(second_is_y_to_z, coin_y);
        let coins_z_out = coin::value(&coin_z);

        let coin_a = get_intermediate_output<Z, A>(third_is_z_to_a, coin_z);
        let coin_a_out = coin::value(&coin_a);

        let coin_b = get_intermediate_output<A, B>(fourth_is_a_to_b, coin_a);
        let coin_b_amt = coin::value(&coin_b);

        assert!(coin_b_amt >= b_min_out, E_OUTPUT_LESS_THAN_MIN);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<B>(sender);
        coin::deposit(sender_addr, coin_b);

        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, coins_y_out);
        add_swap_event_internal<Y, Z>(sender, coins_y_out, 0, 0, coins_z_out);
        add_swap_event_internal<Z, A>(sender, coins_z_out, 0, 0, coin_a_out);
        add_swap_event_internal<A, B>(sender, coin_a_out, 0, 0, coin_b_amt);
        coin_b_amt
    }

    /// Same as `swap_exact_input` with specify path: X -> Y -> Z -> A -> B
    public entry fun swap_exact_input_quadruplehop<X, Y, Z, A, B>(
        sender: &signer,
        x_in: u64,
        b_min_out: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        is_pair_created_internal<Z, A>();
        is_pair_created_internal<A, B>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        let third_is_z_to_a: bool = swap_utils::sort_token_type<Z, A>();

        let fourth_is_a_to_b: bool = swap_utils::sort_token_type<A, B>();

        swap_exact_input_quadruple_internal<X, Y, Z, A, B>(sender, first_is_x_to_y, second_is_y_to_z, third_is_z_to_a, fourth_is_a_to_b, x_in, b_min_out);
    }

    fun swap_exact_output_quadruple_internal<X, Y, Z, A, B>(
        sender: &signer,
        first_is_x_to_y: bool,
        second_is_y_to_z: bool,
        third_is_z_to_a: bool,
        fourth_is_a_to_b: bool,
        x_max_in: u64,
        b_out: u64,
    ): u64 {
        let rin;
        let rout;

        let a_out = if (fourth_is_a_to_b) {
            (rin, rout, _) = swap::token_reserves<A, B>();
            swap_utils::get_amount_in(b_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<B, A>();
            swap_utils::get_amount_in(b_out, rin, rout)
        };

        let z_out = if (third_is_z_to_a) {
            (rin, rout, _) = swap::token_reserves<Z, A>();
            swap_utils::get_amount_in(a_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<A, Z>();
            swap_utils::get_amount_in(a_out, rin, rout)
        };

        let y_out = if (second_is_y_to_z) {
            (rin, rout, _) = swap::token_reserves<Y, Z>();
            swap_utils::get_amount_in(z_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Z, Y>();
            swap_utils::get_amount_in(z_out, rin, rout)
        };
        let x_in = if (first_is_x_to_y) {
            (rin, rout, _) = swap::token_reserves<X, Y>();
            swap_utils::get_amount_in(y_out, rin, rout)
        }else {
            (rout, rin, _) = swap::token_reserves<Y, X>();
            swap_utils::get_amount_in(y_out, rin, rout)
        };

        assert!(x_in <= x_max_in, E_INPUT_MORE_THAN_MAX);

        let coin_x = coin::withdraw<X>(sender, x_in);
        let coin_y = get_intermediate_output_x_to_exact_y<X, Y>(first_is_x_to_y, coin_x, y_out);
        let coin_z = get_intermediate_output_x_to_exact_y<Y, Z>(second_is_y_to_z, coin_y, z_out);
        let coin_a = get_intermediate_output_x_to_exact_y<Z, A>(third_is_z_to_a, coin_z, a_out);
        let coin_b = get_intermediate_output_x_to_exact_y<A, B>(fourth_is_a_to_b, coin_a, b_out);

        let coin_b_amt = coin::value(&coin_b);
        let sender_addr = signer::address_of(sender);
        swap::check_or_register_coin_store<B>(sender);
        coin::deposit(sender_addr, coin_b);

        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
        add_swap_event_internal<Y, Z>(sender, y_out, 0, 0, z_out);
        add_swap_event_internal<Z, A>(sender, z_out, 0, 0, a_out);
        add_swap_event_internal<A, B>(sender, a_out, 0, 0, coin_b_amt);
        coin_b_amt
    }

    /// Same as `swap_exact_output` with specify path: X -> Y -> Z -> A -> B
    public entry fun swap_exact_output_quadruplehop<X, Y, Z, A, B>(
        sender: &signer,
        b_out: u64,
        x_max_in: u64,
    ) {
        is_pair_created_internal<X, Y>();
        is_pair_created_internal<Y, Z>();
        is_pair_created_internal<Z, A>();
        is_pair_created_internal<A, B>();
        let first_is_x_to_y: bool = swap_utils::sort_token_type<X, Y>();

        let second_is_y_to_z: bool = swap_utils::sort_token_type<Y, Z>();

        let third_is_z_to_a: bool = swap_utils::sort_token_type<Z, A>();

        let fourth_is_a_to_b = swap_utils::sort_token_type<A, B>();

        swap_exact_output_quadruple_internal<X, Y, Z, A, B>(sender, first_is_x_to_y, second_is_y_to_z, third_is_z_to_a, fourth_is_a_to_b, x_max_in, b_out);
    }

    public entry fun register_lp<X, Y>(sender: &signer) {
        swap::register_lp<X, Y>(sender);
    }

    public entry fun register_token<X>(sender: &signer) {
        coin::register<X>(sender);
    }
}
