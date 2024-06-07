module pancake_cake_token::pancake {
    use aptos_framework::coin;
    use std::string::{utf8};
    use std::signer;
    use aptos_std::event;
    use aptos_framework::account;

    const PANCAKE_CAKE_TOKEN: address = @pancake_cake_token;
    const ZERO_ACCOUNT: address = @cake_token_zero_account;

    // List of errors
    const ERROR_ONLY_OWNER: u64 = 0;

    struct Cake {}

    struct TransferOwnershipEvent has drop, store {
        old_owner: address,
        new_owner: address
    }

    struct TransferEvent has drop, store {
        from: address,
        to: address,
        amount: u64
    }

    struct CakeInfo has key {
        mint: coin::MintCapability<Cake>,
        freeze: coin::FreezeCapability<Cake>,
        burn: coin::BurnCapability<Cake>,
        owner: address,
        transfer_ownership_event: event::EventHandle<TransferOwnershipEvent>,
        transfer_event: event::EventHandle<TransferEvent>,
    }

    fun init_module(sender: &signer) {
        let owner = signer::address_of(sender);
        let (burn, freeze, mint) =
            coin::initialize<Cake>(
                sender,
                utf8(b"PancakeSwap Token"),
                utf8(b"Cake"),
                8,
                true
            );
        move_to(sender, CakeInfo {
            mint,
            freeze,
            burn,
            owner,
            transfer_ownership_event: account::new_event_handle<TransferOwnershipEvent>(sender),
            transfer_event: account::new_event_handle<TransferEvent>(sender)
        });
    }

    fun only_owner(sender: &signer) acquires CakeInfo {
        let sender_addr = signer::address_of(sender);
        let cake_info = borrow_global<CakeInfo>(PANCAKE_CAKE_TOKEN);
        assert!(sender_addr == cake_info.owner , ERROR_ONLY_OWNER);
    }

    public entry fun transfer_ownership(sender: &signer, new_owner: address) acquires CakeInfo {
        only_owner(sender);
        let old_owner = signer::address_of(sender); 
        let cake_info = borrow_global_mut<CakeInfo>(PANCAKE_CAKE_TOKEN);
        cake_info.owner = new_owner;
        event::emit_event<TransferOwnershipEvent>(
            &mut cake_info.transfer_ownership_event,
            TransferOwnershipEvent {
                old_owner,
                new_owner
            }
        );
    }

    public entry fun mint(sender: &signer, amount: u64) acquires CakeInfo {
        only_owner(sender);
        let sender_addr = signer::address_of(sender);
        let cake_info = borrow_global_mut<CakeInfo>(PANCAKE_CAKE_TOKEN);
        if (!coin::is_account_registered<Cake>(sender_addr)) {
            coin::register<Cake>(sender);
        };
        coin::deposit(sender_addr, coin::mint(amount, &cake_info.mint));
        event::emit_event<TransferEvent>(
            &mut cake_info.transfer_event,
            TransferEvent {
                from: ZERO_ACCOUNT,
                to: sender_addr,
                amount
            }
        );
    }

    public entry fun transfer(sender: &signer, to: address, amount: u64) acquires CakeInfo {
        let from = signer::address_of(sender);
        coin::transfer<Cake>(sender, to, amount);
        let cake_info = borrow_global_mut<CakeInfo>(PANCAKE_CAKE_TOKEN);
        event::emit_event<TransferEvent>(
            &mut cake_info.transfer_event,
            TransferEvent {
                from,
                to,
                amount
            }
        );
    }

    public entry fun register(sender: &signer) {
        let sender_addr = signer::address_of(sender);
        if (!coin::is_account_registered<Cake>(sender_addr)) {
            coin::register<Cake>(sender);
        };
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}
