module overmind::pay_me_a_river_tests {
    #[test_only]
    use std::string;
    #[test_only]
    use aptos_framework::aptos_coin::AptosCoin;
    #[test_only]
    use aptos_framework::coin::BurnCapability;
    #[test_only]
    use aptos_framework::aptos_account;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use overmind::pay_me_a_river::{create_stream, accept_stream, cancel_stream, claim_stream, get_stream};

    #[test_only]
    fun setup(aptos_framework: &signer, sender: &signer): BurnCapability<AptosCoin> {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            aptos_framework,
            string::utf8(b"Aptos"),
            string::utf8(b"APT"),
            8,
            false,
        );
        account::create_account_for_test(signer::address_of(sender));
        coin::register<AptosCoin>(sender);
        let coins = coin::mint<AptosCoin>(2000, &mint_cap);
        coin::deposit(signer::address_of(sender), coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);

        burn_cap
    }

    #[test(aptos_framework = @0x1, sender = @0x123, receiver = @0x234)]
    public entry fun test_create_and_cancel(aptos_framework: &signer, sender: &signer, receiver: &signer) {
        let receiver_address = signer::address_of(receiver);
        aptos_account::create_account(receiver_address);
        let burn_cap = setup(aptos_framework, sender);
        let sender_address = signer::address_of(sender);
        let sender_balance = coin::balance<AptosCoin>(sender_address);
        let receiver_balance = coin::balance<AptosCoin>(receiver_address);
        let test_amount = 10;
        let test_period = 10;
        create_stream(sender, receiver_address, test_amount, test_period);

        let (period_in_seconds, start_time, value) = get_stream(sender_address, receiver_address);
        assert!(period_in_seconds == test_period, 0);
        assert!(start_time == 0, 0);
        assert!(value == test_amount, 0);
        assert!(coin::balance<AptosCoin>(sender_address) + test_amount == sender_balance, 0);
        assert!(coin::balance<AptosCoin>(receiver_address) == receiver_balance, 0);

        cancel_stream(sender, sender_address, receiver_address);

        assert!(coin::balance<AptosCoin>(sender_address) == sender_balance, 0);
        assert!(coin::balance<AptosCoin>(receiver_address) == receiver_balance, 0);

        // Create a new stream for receiver and have the receiver cancel it
        create_stream(sender, receiver_address, test_amount * 2, test_period * 2);
        let (period_in_seconds, start_time, value) = get_stream(sender_address, receiver_address);
        assert!(period_in_seconds == test_period * 2, 0);
        assert!(start_time == 0, 0);
        assert!(value == test_amount * 2, 0);
        cancel_stream(receiver, sender_address, receiver_address);

        coin::destroy_burn_cap(burn_cap);
    }

    #[test(aptos_framework = @0x1, sender = @0x123, receiver = @0x234)]
    public entry fun test_create_accept_and_claim(aptos_framework: &signer, sender: &signer, receiver: &signer) {
        let receiver_address = signer::address_of(receiver);
        aptos_account::create_account(receiver_address);
        let burn_cap = setup(aptos_framework, sender);
        let sender_address = signer::address_of(sender);
        let receiver_balance = coin::balance<AptosCoin>(receiver_address);
        let amount = 10;
        let period_in_seconds = 10;
        create_stream(sender, receiver_address, amount, period_in_seconds);
        let now = 1;
        timestamp::fast_forward_seconds(now);
        accept_stream(receiver, sender_address);
        let (_, start_time, _) = get_stream(sender_address, receiver_address);
        assert!(start_time == now, 0);
        timestamp::fast_forward_seconds(period_in_seconds / 2);
        claim_stream(receiver, sender_address);
        assert!(coin::balance<AptosCoin>(receiver_address) == receiver_balance + amount / 2, 0);

        coin::destroy_burn_cap(burn_cap);
    }

    #[test(aptos_framework = @0x1, sender = @0x123)]
    #[expected_failure(abort_code = 4, location = overmind::pay_me_a_river)]
    public entry fun test_accept_as_sender(aptos_framework: &signer, sender: &signer) {
        let receiver_address = @0x234;
        aptos_account::create_account(receiver_address);
        let burn_cap = setup(aptos_framework, sender);
        let sender_address = signer::address_of(sender);
        let amount = 10;
        let period_in_seconds = 10;
        create_stream(sender, receiver_address, amount, period_in_seconds);
        let now = 1;
        timestamp::fast_forward_seconds(now);
        accept_stream(sender, sender_address);

        coin::destroy_burn_cap(burn_cap);
    }

    #[test(aptos_framework = @0x1, sender = @0x123, receiver = @0x234)]
    #[expected_failure(abort_code = 4, location = overmind::pay_me_a_river)]
    public entry fun test_claim_as_sender(aptos_framework: &signer, sender: &signer, receiver: &signer) {
        let receiver_address = signer::address_of(receiver);
        aptos_account::create_account(receiver_address);
        let burn_cap = setup(aptos_framework, sender);
        let sender_address = signer::address_of(sender);
        let amount = 10;
        let period_in_seconds = 10;
        create_stream(sender, receiver_address, amount, period_in_seconds);
        let now = 1;
        timestamp::fast_forward_seconds(now);
        accept_stream(receiver, sender_address);
        claim_stream(sender, sender_address);

        coin::destroy_burn_cap(burn_cap);
    }
}