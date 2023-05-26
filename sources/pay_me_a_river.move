module overmind::pay_me_a_river {
    use aptos_std::table::Table;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::Coin;
    use aptos_framework::timestamp;
    use std::signer;
    use aptos_std::table;
    use aptos_framework::coin;

    const ESENDER_CAN_NOT_BE_RECEIVER: u64 = 1;
    const ENUMBER_INVALID: u64 = 2;
    const EPAYMENT_DOES_NOT_EXIST: u64 = 3;
    const ESTREAM_DOES_NOT_EXIST: u64 = 4;
    const ESTREAM_IS_ACTIVE: u64 = 5;
    const ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER: u64 = 6;

    struct Stream has store {
        sender: address,
        receiver: address,
        length_in_seconds: u64,
        start_time: u64,
        coins: Coin<AptosCoin>,
    }

    struct Payments has key {
        streams: Table<address, Stream>
    }

    inline fun check_sender_is_not_receiver(sender: address, receiver: address) {
        assert!(sender != receiver, ESENDER_CAN_NOT_BE_RECEIVER)
    }

    inline fun check_number_is_valid(number: u64) {
        assert!(number > 0, ENUMBER_INVALID)
    }

    inline fun check_payment_exists(sender_address: address) {
        assert!(exists<Payments>(sender_address), EPAYMENT_DOES_NOT_EXIST);
    }

    inline fun check_stream_exists(payments: &Payments, stream_address: address) {
        assert!(table::contains(&payments.streams, stream_address), ESTREAM_DOES_NOT_EXIST);
    }

    inline fun check_stream_is_not_active(payments: &Payments, stream_address: address) {
        let paystream = table::borrow(&payments.streams, stream_address);
        assert!(0 == paystream.start_time, ESTREAM_IS_ACTIVE);
    }

    inline fun check_signer_address_is_sender_or_receiver(
        signer_address: address,
        sender_address: address,
        receiver_address: address
    ) {
        assert!(signer_address == sender_address || 
                signer_address == receiver_address, ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER);
    }

    inline fun calculate_stream_claim_amount(total_amount: u64, start_time: u64, length_in_seconds: u64): u64 {
        if (timestamp::now_seconds() > start_time) {(total_amount/length_in_seconds)*(timestamp::now_seconds()-start_time)} 
        else {0}
    }

    public entry fun create_stream(
        signer: &signer,
        receiver_address: address,
        amount: u64,
        length_in_seconds: u64
    ) acquires Payments {
        let signer_addr = signer::address_of(signer);
        check_sender_is_not_receiver(signer_addr, receiver_address);
        check_number_is_valid(amount);
        if (!exists<Payments>(signer_addr)) {
            let streams = table::new();
            move_to<Payments>(signer, Payments{
                streams: streams
            });
        };
        let payments = borrow_global_mut<Payments>(signer_addr);
        let coins = coin::withdraw<AptosCoin>(signer, amount);
        table::add(&mut payments.streams, receiver_address, Stream {
            sender: signer_addr,
            receiver: receiver_address,
            length_in_seconds: length_in_seconds,
            start_time: 0,
            coins: coins,
        });
    }

    public entry fun accept_stream(signer: &signer, sender_address: address) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer::address_of(signer));
        check_stream_is_not_active(payments, signer::address_of(signer));
        let paystream = table::borrow_mut(&mut payments.streams, signer::address_of(signer));
        paystream.start_time = timestamp::now_seconds();
    }

    public entry fun claim_stream(signer: &signer, sender_address: address) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer::address_of(signer));
        let paystream = table::borrow_mut(&mut payments.streams, signer::address_of(signer));
        let claimamount = calculate_stream_claim_amount(coin::value(&paystream.coins), paystream.start_time, paystream.length_in_seconds);
        let new_starttime = timestamp::now_seconds();
        let coin = coin::extract<AptosCoin>(&mut paystream.coins, claimamount); 
        coin::deposit<AptosCoin>(signer::address_of(signer), coin);
        paystream.start_time = new_starttime;
        paystream.length_in_seconds = paystream.length_in_seconds - (new_starttime - paystream.start_time);
    }

    public entry fun cancel_stream(
        signer: &signer,
        sender_address: address,
        receiver_address: address
    ) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, receiver_address);
        check_signer_address_is_sender_or_receiver(signer::address_of(signer), sender_address, receiver_address);
        let Stream{        
            sender: _,
            receiver: _,
            length_in_seconds: _,
            start_time: _,
            coins} = table::remove(&mut payments.streams, receiver_address);
        coin::deposit(sender_address,coins);
    }

    #[view]
    public fun get_stream(sender_address: address, receiver_address: address): (u64, u64, u64) acquires Payments {
        let payments = borrow_global_mut<Payments>(sender_address);
        let paystream = table::borrow(&payments.streams, receiver_address);
        (paystream.length_in_seconds, paystream.start_time, coin::value(&paystream.coins))
    }
}
